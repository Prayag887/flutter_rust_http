use crate::models::{HttpRequest, HttpResponse};
use crate::client_config::ClientConfig;
use crate::header_utils::HeaderUtils;
use crate::method_utils::MethodUtils;
use crate::shared_client::MOBILE_CLIENT;

use reqwest::{Client, Version};
use std::sync::Arc;
use std::time::Instant;
use anyhow::Result;

pub struct HttpClient {
    client: Arc<Client>,
}

impl HttpClient {
    /// Creates a new isolated HTTP client
    pub fn new() -> Self {
        Self {
            client: Arc::new(ClientConfig::build_mobile_client()),
        }
    }

    /// Returns a shared global client for max connection reuse
    pub fn shared() -> Self {
        Self {
            client: Arc::new(
                MOBILE_CLIENT.get_or_init(|| ClientConfig::build_shared_mobile_client()).clone()
            ),
        }
    }

    /// Executes an HTTP request with optimized latency for mobile
    pub async fn execute_request(&self, request: HttpRequest<'_>) -> Result<HttpResponse> {
        let start_time = Instant::now();

        let method = MethodUtils::parse_method(request.method)?;
        let mut req_builder = self.client.request(method, request.url.to_string());

        if !request.headers.is_empty() {
            let headers = HeaderUtils::build_header_map(&request.headers)?;
            req_builder = req_builder.headers(headers);
        }

        if !request.query_params.is_empty() {
            req_builder = req_builder.query(&request.query_params);
        }

        if let Some(body) = request.body {
            req_builder = req_builder.body(body.to_string());
        }

        if request.http3_only {
            req_builder = req_builder.version(Version::HTTP_3);
        }

        let response = req_builder.send().await?;
        let status_code = response.status().as_u16();
        let version = Self::version_to_string(response.version());
        let headers = HeaderUtils::extract_response_headers(response.headers());
        let body_bytes = response.bytes().await?;
        let body = String::from_utf8_lossy(&body_bytes).into_owned();
        let elapsed_ms = start_time.elapsed().as_millis();

        Ok(HttpResponse {
            status_code,
            headers,
            body,
            version: version.to_string(),
            url: request.url.to_string(),
            elapsed_ms,
        })
    }

    fn version_to_string(version: Version) -> &'static str {
        match version {
            Version::HTTP_09 => "HTTP/0.9",
            Version::HTTP_10 => "HTTP/1.0",
            Version::HTTP_11 => "HTTP/1.1",
            Version::HTTP_2 => "HTTP/2",
            Version::HTTP_3 => "HTTP/3",
            _ => "Unknown",
        }
    }

    /// Prewarm connections to a list of URLs
    pub async fn prewarm(&self, urls: &[&str]) {
        for &url in urls {
            let _ = self.client.get(url).send().await;
        }
    }
}

impl Default for HttpClient {
    fn default() -> Self {
        Self::new()
    }
}