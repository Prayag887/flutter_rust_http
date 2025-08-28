use serde::{Serialize, Deserialize};
use simd_json::OwnedValue;
use std::collections::HashMap;

#[derive(Debug, Serialize, Deserialize)]
pub struct HttpRequest<'a> {
    pub url: &'a str,
    pub method: &'a str,
    pub headers: HashMap<&'a str, &'a str>,
    pub body: Option<&'a str>,
    pub query_params: HashMap<&'a str, &'a str>,
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

#[derive(Debug, Serialize, Deserialize)]
pub struct HttpResponse {
    pub status_code: u16,
    pub headers: HashMap<String, String>,
    pub body: String,
    pub version: String,
    pub url: String,
    pub elapsed_ms: u128,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct HttpError {
    pub code: String,
    pub message: String,
    pub details: Option<OwnedValue>, // <- now owns its data, no lifetime required
}
