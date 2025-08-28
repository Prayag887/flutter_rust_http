use reqwest::header::{HeaderMap, HeaderName, HeaderValue};
use std::collections::HashMap;
use std::str::FromStr;
use anyhow::Result;

pub struct HeaderUtils;

impl HeaderUtils {
    /// Efficiently converts a HashMap of headers to reqwest HeaderMap
    /// Uses static header names for common headers to avoid allocations
    pub fn build_header_map(headers: &HashMap<&str, &str>) -> Result<HeaderMap> {
        let mut header_map = HeaderMap::with_capacity(headers.len());

        for (k, v) in headers {
            let header_name = Self::get_optimized_header_name(k)?;
            let header_value = HeaderValue::from_str(v)?;
            header_map.insert(header_name, header_value);
        }

        Ok(header_map)
    }

    /// Efficiently converts a HashMap of String headers to reqwest HeaderMap
    /// Uses static header names for common headers to avoid allocations
    pub fn build_header_map_from_strings(headers: &HashMap<String, String>) -> Result<HeaderMap> {
        let mut header_map = HeaderMap::with_capacity(headers.len());

        for (k, v) in headers {
            let header_name = Self::get_optimized_header_name(k)?;
            let header_value = HeaderValue::from_str(v)?;
            header_map.insert(header_name, header_value);
        }

        Ok(header_map)
    }

    /// Returns optimized header names using static references for common headers
    /// This avoids string allocations for frequently used headers
    fn get_optimized_header_name(key: &str) -> Result<HeaderName> {
        let header_name = match key.to_ascii_lowercase().as_str() {
            "content-type" => reqwest::header::CONTENT_TYPE,
            "authorization" => reqwest::header::AUTHORIZATION,
            "user-agent" => reqwest::header::USER_AGENT,
            "accept" => reqwest::header::ACCEPT,
            "accept-encoding" => reqwest::header::ACCEPT_ENCODING,
            "cache-control" => reqwest::header::CACHE_CONTROL,
            "content-length" => reqwest::header::CONTENT_LENGTH,
            "host" => reqwest::header::HOST,
            "referer" => reqwest::header::REFERER,
            "cookie" => reqwest::header::COOKIE,
            "set-cookie" => reqwest::header::SET_COOKIE,
            "location" => reqwest::header::LOCATION,
            "etag" => reqwest::header::ETAG,
            "last-modified" => reqwest::header::LAST_MODIFIED,
            "if-none-match" => reqwest::header::IF_NONE_MATCH,
            "if-modified-since" => reqwest::header::IF_MODIFIED_SINCE,

            // Common mobile API headers
            "x-api-key" => HeaderName::from_static("x-api-key"),
            "x-auth-token" => HeaderName::from_static("x-auth-token"),
            "x-request-id" => HeaderName::from_static("x-request-id"),
            "x-correlation-id" => HeaderName::from_static("x-correlation-id"),
            "x-device-id" => HeaderName::from_static("x-device-id"),
            "x-app-version" => HeaderName::from_static("x-app-version"),
            "x-platform" => HeaderName::from_static("x-platform"),

            // Fallback to dynamic allocation for uncommon headers
            _ => HeaderName::from_str(key)?,
        };

        Ok(header_name)
    }

    /// Converts response headers to a HashMap efficiently
    /// Skips invalid UTF-8 headers to avoid crashes on mobile
    pub fn extract_response_headers(response_headers: &HeaderMap) -> HashMap<String, String> {
        let mut headers = HashMap::with_capacity(response_headers.len());

        for (k, v) in response_headers.iter() {
            if let Ok(value_str) = v.to_str() {
                headers.insert(k.as_str().to_owned(), value_str.to_owned());
            }
            // Skip invalid headers instead of failing
        }

        headers
    }
}