use crate::models::{HttpRequest, HttpResponse};
use anyhow::{anyhow, Result};
use reqwest::{
    header::{HeaderMap, HeaderName, HeaderValue},
    Method, Version,
};
use std::collections::HashMap;
use std::str::FromStr;
use std::time::Instant;

pub struct HttpClient {
    client: reqwest::Client,
}

impl HttpClient {
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .pool_idle_timeout(std::time::Duration::from_secs(30))
            .tcp_keepalive(std::time::Duration::from_secs(60))
            .http2_keep_alive_interval(std::time::Duration::from_secs(30))
            .http2_keep_alive_timeout(std::time::Duration::from_secs(60))
            .http2_keep_alive_while_idle(true)
            .build()
            .unwrap();

        Self { client }
    }

    pub fn execute_request(&self, request: HttpRequest) -> Result<HttpResponse> {
        let start_time = Instant::now();

        let method = Method::from_bytes(request.method.as_bytes())?;
        let mut req_builder = self.client.request(method, &request.url);

        let headers = self.build_headers(request.headers)?;
        req_builder = req_builder.headers(headers);

        for (key, value) in request.query_params {
            req_builder = req_builder.query(&[(key, value)]);
        }

        if let Some(body) = request.body {
            req_builder = req_builder.body(body);
        }

        if request.http3_only {
            req_builder = req_builder.version(reqwest::Version::HTTP_3);
        }

        let mut runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()?;

        let response = runtime.block_on(async {
            req_builder.send().await
        })?;

        let status_code = response.status().as_u16();
        let version = match response.version() {
            Version::HTTP_09 => "HTTP/0.9".to_string(),
            Version::HTTP_10 => "HTTP/1.0".to_string(),
            Version::HTTP_11 => "HTTP/1.1".to_string(),
            Version::HTTP_2 => "HTTP/2".to_string(),
            Version::HTTP_3 => "HTTP/3".to_string(),
            _ => "Unknown".to_string(),
        };

        let headers = self.extract_headers(response.headers())?;

        let body = runtime.block_on(async {
            response.text().await
        })?;

        let elapsed_ms = start_time.elapsed().as_millis();

        Ok(HttpResponse {
            status_code,
            headers,
            body,
            version,
            url: request.url,
            elapsed_ms,
        })
    }

    fn build_headers(&self, headers_map: HashMap<String, String>) -> Result<HeaderMap> {
        let mut headers = HeaderMap::new();

        for (key, value) in headers_map {
            let header_name = HeaderName::from_str(&key)?;
            let header_value = HeaderValue::from_str(&value)?;
            headers.insert(header_name, header_value);
        }

        Ok(headers)
    }

    fn extract_headers(&self, header_map: &HeaderMap) -> Result<HashMap<String, String>> {
        let mut headers = HashMap::new();

        for (key, value) in header_map.iter() {
            let key_str = key.as_str().to_string();
            let value_str = value.to_str()?.to_string();
            headers.insert(key_str, value_str);
        }

        Ok(headers)
    }
}