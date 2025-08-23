use crate::models::{EnhancedHttpRequest, EnhancedHttpResponse, HttpResponse};
use crate::parser;
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
use lru::LruCache;
use parking_lot::RwLock;
use std::fmt;
use std::num::NonZeroUsize;

static COMMON_HEADERS: Lazy<HashMap<&'static str, HeaderName>> = Lazy::new(|| {
    let mut m = HashMap::with_capacity(16);
    for &key in &[
        "content-type", "user-agent", "authorization", "accept", "accept-language",
        "accept-encoding", "cache-control", "connection", "cookie", "host",
        "referer", "origin", "x-requested-with",
    ] {
        m.insert(key, HeaderName::from_static(key));
    }
    m
});

pub struct HttpClient {
    client: reqwest::Client,
    cache: Arc<RwLock<LruCache<String, Arc<EnhancedHttpResponse>>>>,
    request_dedup: DashMap<String, Arc<tokio::sync::watch::Receiver<Option<Arc<EnhancedHttpResponse>>>>>,
}

impl fmt::Debug for HttpClient {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("HttpClient")
            .field("client", &"<reqwest::Client>")
            .field("cache", &"<LruCache>")
            .finish()
    }
}

impl HttpClient {
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .pool_max_idle_per_host(10)
            .pool_idle_timeout(Duration::from_secs(30))
            .tcp_keepalive(Duration::from_secs(30))
            .tcp_nodelay(true)
            .http2_keep_alive_interval(Duration::from_secs(15))
            .http2_keep_alive_timeout(Duration::from_secs(30))
            .http2_keep_alive_while_idle(true)
            .http2_adaptive_window(true)
            .timeout(Duration::from_secs(15))
            .connect_timeout(Duration::from_secs(5))
            .build()
            .unwrap();

        let cache = Arc::new(RwLock::new(LruCache::new(
            NonZeroUsize::new(500).unwrap()
        )));

        Self {
            client,
            cache,
            request_dedup: DashMap::new(),
        }
    }

    pub async fn execute_enhanced_request(&self, request: EnhancedHttpRequest) -> Result<EnhancedHttpResponse> {
        let cache_key = request.cache_key.clone()
            .unwrap_or_else(|| self.generate_cache_key(&request.base));

        if request.base.method.eq_ignore_ascii_case("GET") {
            if let Some(cached) = self.get_cached(&cache_key) {
                return Ok((*cached).clone());
            }

            if let Some(receiver) = self.request_dedup.get(&cache_key) {
                let rx = receiver.clone().borrow().clone();
                if let Some(resp) = rx {
                    return Ok((*resp).clone());
                }
            }
        }

        let (tx, rx) = tokio::sync::watch::channel(None);
        self.request_dedup.insert(cache_key.clone(), Arc::new(rx));

        let result = self.execute_request_internal(request).await;

        if let Ok(ref response) = result {
            let _ = tx.send(Some(Arc::new(response.clone())));
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
            req_builder = req_builder.query(&request.base.query_params.iter().collect::<Vec<_>>());
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
        let body_str = String::from_utf8_lossy(&body_bytes).to_string();
        let compression_saved = orig_body_len.map(|orig| orig.saturating_sub(body_bytes.len()));

        let parsed_data = if request.parse_response {
            request.response_type_schema.as_deref()
                .and_then(|schema| parser::parse_json_with_schema_bytes(&body_bytes, Some(schema)).ok())
        } else { None };

        let elapsed_ms = start_time.elapsed().as_millis();

        let http_response = Arc::new(EnhancedHttpResponse {
            base: HttpResponse {
                status_code,
                headers,
                body: body_str.clone(),
                version,
                url: request.base.url.clone(),
                elapsed_ms,
            },
            parsed_data,
            cache_hit: false,
            compression_saved,
        });

        if request.base.method.eq_ignore_ascii_case("GET") && status_code == 200 {
            let cache_key = request.cache_key.unwrap_or_else(|| self.generate_cache_key(&request.base));
            self.cache_response(cache_key, Arc::clone(&http_response));
        }

        Ok(Arc::try_unwrap(http_response).unwrap_or_else(|arc| (*arc).clone()))
    }

    fn get_cached(&self, key: &str) -> Option<Arc<EnhancedHttpResponse>> {
        self.cache.write().get(key).cloned()
    }

    fn cache_response(&self, key: String, response: Arc<EnhancedHttpResponse>) {
        self.cache.write().put(key, response);
    }

    fn generate_cache_key(&self, request: &crate::models::HttpRequest) -> String {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};

        let mut hasher = DefaultHasher::new();
        request.method.hash(&mut hasher);
        request.url.hash(&mut hasher);
        for (k, v) in &request.query_params {
            k.hash(&mut hasher);
            v.hash(&mut hasher);
        }

        format!("req_{:x}", hasher.finish())
    }

    fn build_headers(&self, headers_map: &HashMap<String, String>) -> Result<HeaderMap> {
        let mut headers = HeaderMap::with_capacity(headers_map.len());
        for (key, value) in headers_map {
            let header_name = COMMON_HEADERS
                .get(&key.to_lowercase().as_str())
                .cloned()
                .unwrap_or_else(|| HeaderName::from_str(key).unwrap());

            let header_value = HeaderValue::from_str(value)?;
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