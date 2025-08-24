use crate::models::{EnhancedHttpRequest, EnhancedHttpResponse, HttpResponse};
use crate::parser;
use anyhow::Result;
use once_cell::sync::Lazy;
use reqwest::{
    header::{HeaderMap, HeaderName, HeaderValue},
    Method, Version,
};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Instant, Duration};
use dashmap::DashMap;
use std::fmt;
use fxhash::FxHasher;
use std::hash::{Hash, Hasher};

// Use a faster hasher
type FastHasher = FxHasher;

static COMMON_HEADERS: Lazy<HashMap<&'static str, HeaderName>> = Lazy::new(|| {
    let mut m = HashMap::with_capacity(32);
    for &key in &[
        "content-type", "user-agent", "authorization", "accept", "accept-language",
        "accept-encoding", "cache-control", "connection", "cookie", "host",
        "referer", "origin", "x-requested-with", "content-length", "date",
        "etag", "last-modified", "location", "server", "vary",
        "x-powered-by", "x-frame-options", "x-content-type-options",
        "x-xss-protection", "strict-transport-security", "expires",
        "pragma", "age", "x-cache", "via", "x-amz-cf-pop", "x-amz-cf-id"
    ] {
        m.insert(key, HeaderName::from_static(key));
    }
    m
});

// Pre-allocate common header values
static COMMON_HEADER_VALUES: Lazy<HashMap<&'static str, HeaderValue>> = Lazy::new(|| {
    let mut m = HashMap::new();
    m.insert("application/json", HeaderValue::from_static("application/json"));
    m.insert("gzip", HeaderValue::from_static("gzip"));
    m.insert("deflate", HeaderValue::from_static("deflate"));
    m.insert("br", HeaderValue::from_static("br"));
    m.insert("keep-alive", HeaderValue::from_static("keep-alive"));
    m.insert("no-cache", HeaderValue::from_static("no-cache"));
    m.insert("max-age=0", HeaderValue::from_static("max-age=0"));
    m
});

pub struct HttpClient {
    client: reqwest::Client,
    cache: DashMap<String, Arc<EnhancedHttpResponse>>,
    request_dedup: DashMap<String, Arc<tokio::sync::watch::Receiver<Option<Arc<EnhancedHttpResponse>>>>>,
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
           .pool_max_idle_per_host(1)              // Mobile apps rarely need >1 connection per host
           .pool_idle_timeout(Duration::from_secs(20))
           .tcp_nodelay(true)
           .timeout(Duration::from_secs(10))       // Mobile users expect fast responses
           .connect_timeout(Duration::from_secs(3))
           .http2_keep_alive_interval(Duration::from_secs(20))
           .http2_keep_alive_timeout(Duration::from_secs(8))
           .http2_keep_alive_while_idle(true)
           .use_rustls_tls()
           .build()
           .unwrap();

        let cache = DashMap::with_capacity(1000);
        let request_dedup = DashMap::with_capacity(100);

        Self {
            client,
            cache,
            request_dedup,
        }
    }

    pub async fn execute_enhanced_request(&self, request: EnhancedHttpRequest) -> Result<EnhancedHttpResponse> {
        let cache_key = request.cache_key.clone()
            .unwrap_or_else(|| self.generate_cache_key(&request.base));

        // Clone cache_key for use in multiple places
        let cache_key_clone = cache_key.clone();

        // Check cache first (lock-free)
        if request.base.method.eq_ignore_ascii_case("GET") {
            if let Some(cached) = self.cache.get(&cache_key) {
                let mut response = (**cached).clone();
                response.cache_hit = true;
                return Ok(response);
            }

            // Check for in-flight requests
            if let Some(receiver) = self.request_dedup.get(&cache_key) {
                // Just check if there's already a value without waiting
                if let Some(resp) = receiver.value().borrow().as_ref() {
                    return Ok((**resp).clone());
                }
            }
        }

        let (tx, rx) = tokio::sync::watch::channel(None);
        self.request_dedup.insert(cache_key.clone(), Arc::new(rx));

        let result = self.execute_request_internal(request).await;

        if let Ok(ref response) = result {
            let response_arc = Arc::new(response.clone());
            let _ = tx.send(Some(Arc::clone(&response_arc)));

            // Cache the response if it's a GET request and status code is 200
            if response.base.status_code == 200 {
                self.cache.insert(cache_key_clone, response_arc);
            }
        }

        self.request_dedup.remove(&cache_key);
        result
    }

    async fn execute_request_internal(&self, request: EnhancedHttpRequest) -> Result<EnhancedHttpResponse> {
        let start_time = Instant::now();
        let orig_body_len = request.base.body.as_ref().map(|b| b.len());

        let method = Method::from_bytes(request.base.method.as_bytes())?;
        let mut req_builder = self.client.request(method, &request.base.url);

        let headers = self.build_headers(&request.base.headers)?;
        req_builder = req_builder.headers(headers);

        if !request.base.query_params.is_empty() {
            req_builder = req_builder.query(&request.base.query_params);
        }

        if let Some(ref body) = request.base.body {
            req_builder = req_builder.body(body.clone());
        }

        if request.base.http3_only {
            req_builder = req_builder.version(Version::HTTP_3);
        }

        let response = req_builder.send().await?;
        let status_code = response.status().as_u16();
        let version = match response.version() {
            Version::HTTP_09 => "HTTP/0.9",
            Version::HTTP_10 => "HTTP/1.0",
            Version::HTTP_11 => "HTTP/1.1",
            Version::HTTP_2 => "HTTP/2",
            Version::HTTP_3 => "HTTP/3",
            _ => "Unknown",
        }.to_string();

        let headers = self.extract_headers(response.headers())?;
        let body_bytes = response.bytes().await?;

        // Only convert to string if needed for parsing or if the response is text-based
        let content_type = headers.get("content-type").map(|s| s.as_str()).unwrap_or("");
        let is_text_content = content_type.starts_with("text/") ||
                             content_type.contains("json") ||
                             content_type.contains("xml");

        let body_str = if request.parse_response || is_text_content {
            String::from_utf8_lossy(&body_bytes).into_owned()
        } else {
            String::new() // Don't waste time converting binary data
        };

        let compression_saved = orig_body_len.map(|orig| orig.saturating_sub(body_bytes.len()));

        let parsed_data = if request.parse_response {
            request.response_type_schema.as_deref()
                .and_then(|schema| parser::parse_json_with_schema_bytes(&body_bytes, Some(schema)).ok())
        } else {
            None
        };

        let elapsed_ms = start_time.elapsed().as_millis();

        Ok(EnhancedHttpResponse {
            base: HttpResponse {
                status_code,
                headers,
                body: body_str,
                version,
                url: request.base.url,
                elapsed_ms,
            },
            parsed_data,
            cache_hit: false,
            compression_saved,
        })
    }

    fn generate_cache_key(&self, request: &crate::models::HttpRequest) -> String {
        let mut hasher = FastHasher::default();
        request.method.hash(&mut hasher);
        request.url.hash(&mut hasher);

        // Sort query params for consistent caching
        let mut params: Vec<_> = request.query_params.iter().collect();
        params.sort_by(|a, b| a.0.cmp(b.0));
        for (k, v) in params {
            k.hash(&mut hasher);
            v.hash(&mut hasher);
        }

        format!("req_{:x}", hasher.finish())
    }

    fn build_headers(&self, headers_map: &HashMap<String, String>) -> Result<HeaderMap> {
        let mut headers = HeaderMap::with_capacity(headers_map.len());
        for (key, value) in headers_map {
            let key_lower = key.to_lowercase();

            // Fast path for common headers
            let header_name = if let Some(header) = COMMON_HEADERS.get(key_lower.as_str()) {
                header.clone()
            } else {
                HeaderName::from_bytes(key.as_bytes())?
            };

            // Fast path for common header values
            let header_value = if let Some(value) = COMMON_HEADER_VALUES.get(value.as_str()) {
                value.clone()
            } else {
                HeaderValue::from_str(value)?
            };

            headers.insert(header_name, header_value);
        }
        Ok(headers)
    }

    fn extract_headers(&self, header_map: &HeaderMap) -> Result<HashMap<String, String>> {
        let mut headers = HashMap::with_capacity(header_map.len());
        for (k, v) in header_map {
            headers.insert(k.as_str().to_string(), v.to_str()?.to_string());
        }
        Ok(headers)
    }
}