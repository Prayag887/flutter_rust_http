use reqwest::Method;
use anyhow::Result;

pub struct MethodUtils;

impl MethodUtils {
    /// Efficiently converts a string method to reqwest Method
    /// Uses pattern matching for common methods to avoid parsing overhead
    pub fn parse_method(method_str: &str) -> Result<Method> {
        let method = match method_str {
            "GET" => Method::GET,
            "POST" => Method::POST,
            "PUT" => Method::PUT,
            "DELETE" => Method::DELETE,
            "HEAD" => Method::HEAD,
            "PATCH" => Method::PATCH,
            "OPTIONS" => Method::OPTIONS,
            "TRACE" => Method::TRACE,
            "CONNECT" => Method::CONNECT,

            // Handle case-insensitive common methods
            "get" => Method::GET,
            "post" => Method::POST,
            "put" => Method::PUT,
            "delete" => Method::DELETE,
            "head" => Method::HEAD,
            "patch" => Method::PATCH,
            "options" => Method::OPTIONS,

            // Fallback to parsing for uncommon methods
            _ => Method::from_bytes(method_str.as_bytes())?,
        };

        Ok(method)
    }

    /// Returns whether a method typically includes a request body
    pub fn method_has_body(method: &Method) -> bool {
        matches!(method, &Method::POST | &Method::PUT | &Method::PATCH)
    }

    /// Returns whether a method is considered safe (read-only)
    pub fn is_safe_method(method: &Method) -> bool {
        matches!(method, &Method::GET | &Method::HEAD | &Method::OPTIONS | &Method::TRACE)
    }

    /// Returns whether a method is idempotent
    pub fn is_idempotent_method(method: &Method) -> bool {
        matches!(
            method,
            &Method::GET | &Method::HEAD | &Method::PUT | &Method::DELETE | &Method::OPTIONS | &Method::TRACE
        )
    }
}