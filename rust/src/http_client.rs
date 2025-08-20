use crate::models::{HttpRequest, HttpResponse};
use anyhow::Result;
use once_cell::sync::Lazy;
use reqwest::{
    header::{HeaderMap, HeaderName, HeaderValue},
    Method, Version,
};
use std::collections::HashMap;
use std::str::FromStr;
use std::sync::Arc;
use std::time::{Instant, Duration};
use dashmap::DashMap;
use std::fmt;

/// Common headers cache to avoid repeated parsing
static COMMON_HEADERS: Lazy<HashMap<&'static str, HeaderName>> = Lazy::new(|| {
    let mut m = HashMap::new();
    m.insert("content-type", HeaderName::from_static("content-type"));
    m.insert("user-agent", HeaderName::from_static("user-agent"));
    m.insert("authorization", HeaderName::from_static("authorization"));
    m.insert("accept", HeaderName::from_static("accept"));
    m.insert("accept-language", HeaderName::from_static("accept-language"));
    m.insert("accept-encoding", HeaderName::from_static("accept-encoding"));
    m.insert("cache-control", HeaderName::from_static("cache-control"));
    m.insert("connection", HeaderName::from_static("connection"));
    m.insert("cookie", HeaderName::from_static("cookie"));
    m.insert("host", HeaderName::from_static("host"));
    m.insert("referer", HeaderName::from_static("referer"));
    m
});

pub struct HttpClient {
    client: reqwest::Client,
    cache: DashMap<String, Arc<HttpResponse>>,
}

impl fmt::Debug for HttpClient {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("HttpClient")
            .field("client", &"<reqwest::Client>")
            .field("cache", &"<DashMap>")
            .finish()
    }
}

impl HttpClient {
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .pool_max_idle_per_host(20)
            .pool_idle_timeout(Duration::from_secs(30))
            .tcp_keepalive(Duration::from_secs(60))
            .http2_keep_alive_interval(Duration::from_secs(30))
            .http2_keep_alive_timeout(Duration::from_secs(60))
            .http2_keep_alive_while_idle(true)
            .timeout(Duration::from_secs(30))
            .connect_timeout(Duration::from_secs(10))
            .build()
            .unwrap();

        let cache = DashMap::new();

        Self { client, cache }
    }

    pub async fn execute_request(&self, request: HttpRequest) -> Result<HttpResponse> {
        // Check cache for GET requests
        if request.method.to_uppercase() == "GET" {
            let cache_key = self.generate_cache_key(&request);
            if let Some(cached) = self.cache.get(&cache_key) {
                return Ok((**cached).clone()); // cheap Arc clone
            }
        }

        let start_time = Instant::now();

        let method = Method::from_bytes(request.method.as_bytes())?;
        let mut req_builder = self.client.request(method, &request.url);

        let headers = self.build_headers(&request.headers)?;
        req_builder = req_builder.headers(headers);

        for (key, value) in &request.query_params {
            req_builder = req_builder.query(&[(key.clone(), value.clone())]);
        }

       if let Some(ref body) = request.body {
           req_builder = req_builder.body(body.clone());
       }

        if request.http3_only {
            req_builder = req_builder.version(reqwest::Version::HTTP_3);
        }

        let response = req_builder.send().await?;

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
        let body = response.text().await?;

        let elapsed_ms = start_time.elapsed().as_millis();

        let http_response = Arc::new(HttpResponse {
            status_code,
            headers,
            body,
            version,
            url: request.url.clone(),
            elapsed_ms,
        });

        // Cache GET responses
        if request.method.to_uppercase() == "GET" && status_code == 200 {
            let cache_key = self.generate_cache_key(&request);
            self.cache.insert(cache_key, Arc::clone(&http_response));
        }

        Ok(Arc::try_unwrap(http_response).unwrap_or_else(|arc| (*arc).clone()))
    }

    fn generate_cache_key(&self, request: &HttpRequest) -> String {
        format!("{}|{}|{:?}", request.method, request.url, request.query_params)
    }

    fn build_headers(&self, headers_map: &HashMap<String, String>) -> Result<HeaderMap> {
        let mut headers = HeaderMap::new();

        for (key, value) in headers_map {
            let header_name = if let Some(cached) = COMMON_HEADERS.get(key.to_lowercase().as_str()) {
                cached.clone()
            } else {
                HeaderName::from_str(&key)?
            };

            let header_value = HeaderValue::from_str(&value)?;
            headers.insert(header_name, header_value);
        }

        Ok(headers)
    }

    fn extract_headers(&self, header_map: &HeaderMap) -> Result<HashMap<String, String>> {
        let mut headers = HashMap::new();
        for (key, value) in header_map.iter() {
            headers.insert(key.as_str().to_string(), value.to_str()?.to_string());
        }
        Ok(headers)
    }
}
