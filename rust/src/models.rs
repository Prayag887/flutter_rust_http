use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct HttpRequest {
    pub url: String,
    pub method: String,
    pub headers: HashMap<String, String>,
    pub body: Option<String>,
    pub query_params: HashMap<String, String>,
    pub timeout_ms: u64,
    pub follow_redirects: bool,
    pub max_redirects: usize,
    pub connect_timeout_ms: u64,
    pub read_timeout_ms: u64,
    pub write_timeout_ms: u64,
    pub auto_referer: bool,
    pub decompress: bool,
    pub http3_only: bool,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct EnhancedHttpRequest {
    #[serde(flatten)]
    pub base: HttpRequest,
    pub response_type_schema: Option<String>,
    pub parse_response: bool,
    pub cache_key: Option<String>,
    pub priority: RequestPriority,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub enum RequestPriority {
    High,
    Normal,
    Low,
}

impl Default for RequestPriority {
    fn default() -> Self {
        RequestPriority::Normal
    }
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct HttpResponse {
    pub status_code: u16,
    pub headers: HashMap<String, String>,
    pub body: String,
    pub version: String,
    pub url: String,
    pub elapsed_ms: u128,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct EnhancedHttpResponse {
    #[serde(flatten)]
    pub base: HttpResponse,
    pub parsed_data: Option<serde_json::Value>,
    pub cache_hit: bool,
    pub compression_saved: Option<usize>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct HttpError {
    pub code: String,
    pub message: String,
    pub details: Option<serde_json::Value>,
}