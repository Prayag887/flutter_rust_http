use anyhow::Result;
use simd_json::{BorrowedValue, OwnedValue};
use simd_json::prelude::*;


pub fn parse_request(json: &str) -> Result<crate::models::EnhancedHttpRequest> {
    // Parse JSON using simd_json
    let mut bytes = json.as_bytes().to_vec();
    let value = simd_json::to_borrowed_value(&mut bytes)?;
    parse_enhanced_http_request(&value).map_err(Into::into)
}

pub fn serialize_response(response: &crate::models::EnhancedHttpResponse) -> Result<String> {
    // Serialize JSON using simd_json
    let owned_value = serialize_enhanced_http_response(response)?;
    Ok(owned_value.to_string())
}

pub fn parse_json_with_schema(json: &str, schema: Option<&str>) -> Result<OwnedValue> {
    if let Some(_schema_str) = schema {
        // Validate against schema if provided
        // For now, just parse normally
        validate_and_parse(json)
    } else {
        // Generic parsing
        let mut bytes = json.as_bytes().to_vec();
        simd_json::to_owned_value(&mut bytes).map_err(Into::into)
    }
}

pub fn parse_batch_requests(
    json: &str,
) -> Result<Vec<crate::models::EnhancedHttpRequest>> {
    let mut bytes = json.as_bytes().to_vec();
    let value = simd_json::to_borrowed_value(&mut bytes)?;

    if let Some(array) = value.as_array() {
        let mut requests = Vec::new();
        for item in array {
            requests.push(parse_enhanced_http_request(item)?);
        }
        Ok(requests)
    } else {
        Err(anyhow::anyhow!("Expected JSON array"))
    }
}

fn validate_and_parse(json: &str) -> Result<OwnedValue> {
    // In production, you could validate with jsonschema crate
    // For now, just parse normally
    let mut bytes = json.as_bytes().to_vec();
    simd_json::to_owned_value(&mut bytes).map_err(Into::into)
}

// Helper functions for parsing
fn parse_enhanced_http_request(value: &BorrowedValue) -> Result<crate::models::EnhancedHttpRequest> {
    let base = parse_http_request(value)?;

    let priority_str = value
        .get("priority")
        .and_then(|v| v.as_str())
        .unwrap_or("Normal");
    let priority = match priority_str {
        "High" => crate::models::RequestPriority::High,
        "Low" => crate::models::RequestPriority::Low,
        _ => crate::models::RequestPriority::Normal,
    };

    Ok(crate::models::EnhancedHttpRequest {
        base,
        response_type_schema: value.get("response_type_schema").and_then(|v| v.as_str()).map(|s| s.to_string()),
        parse_response: value.get("parse_response").and_then(|v| v.as_bool()).unwrap_or(false),
        cache_key: value.get("cache_key").and_then(|v| v.as_str()).map(|s| s.to_string()),
        priority,
    })
}

fn parse_http_request(value: &BorrowedValue) -> Result<crate::models::HttpRequest> {
    let url = value.get("url")
        .and_then(|v| v.as_str())
        .ok_or_else(|| anyhow::anyhow!("Missing url field"))?
        .to_string();

    let method = value.get("method")
        .and_then(|v| v.as_str())
        .ok_or_else(|| anyhow::anyhow!("Missing method field"))?
        .to_string();

    let headers = parse_string_map(value, "headers")?;
    let query_params = parse_string_map(value, "query_params")?;

    Ok(crate::models::HttpRequest {
        url,
        method,
        headers,
        body: value.get("body").and_then(|v| v.as_str()).map(|s| s.to_string()),
        query_params,
        timeout_ms: value.get("timeout_ms").and_then(|v| v.as_u64()).unwrap_or(30000),
        follow_redirects: value.get("follow_redirects").and_then(|v| v.as_bool()).unwrap_or(true),
        max_redirects: value.get("max_redirects").and_then(|v| v.as_u64()).map(|v| v as usize).unwrap_or(10),
        connect_timeout_ms: value.get("connect_timeout_ms").and_then(|v| v.as_u64()).unwrap_or(10000),
        read_timeout_ms: value.get("read_timeout_ms").and_then(|v| v.as_u64()).unwrap_or(30000),
        write_timeout_ms: value.get("write_timeout_ms").and_then(|v| v.as_u64()).unwrap_or(30000),
        auto_referer: value.get("auto_referer").and_then(|v| v.as_bool()).unwrap_or(true),
        decompress: value.get("decompress").and_then(|v| v.as_bool()).unwrap_or(true),
        http3_only: value.get("http3_only").and_then(|v| v.as_bool()).unwrap_or(false),
    })
}

fn parse_string_map(value: &BorrowedValue, field: &str) -> Result<std::collections::HashMap<String, String>> {
    let mut map = std::collections::HashMap::new();

    if let Some(obj) = value.get(field).and_then(|v| v.as_object()) {
        for (key, val) in obj.iter() {
            if let Some(str_val) = val.as_str() {
                map.insert(key.to_string(), str_val.to_string());
            }
        }
    }

    Ok(map)
}

fn serialize_enhanced_http_response(response: &crate::models::EnhancedHttpResponse) -> Result<OwnedValue> {
    let mut map = simd_json::owned::Object::default();

    // Serialize base response fields
    map.insert("status_code".to_string(), OwnedValue::from(response.base.status_code as u64));
    map.insert("body".to_string(), OwnedValue::String(response.base.body.clone()));
    map.insert("version".to_string(), OwnedValue::String(response.base.version.clone()));
    map.insert("url".to_string(), OwnedValue::String(response.base.url.clone()));
    map.insert("elapsed_ms".to_string(), OwnedValue::from(response.base.elapsed_ms as u64));

    // Serialize headers
    let headers_obj: simd_json::owned::Object = response.base.headers
        .iter()
        .map(|(k, v)| (k.clone(), OwnedValue::String(v.clone())))
        .collect();
    map.insert("headers".to_string(), OwnedValue::Object(Box::new(headers_obj)));

    // Serialize enhanced fields
    if let Some(ref parsed_data) = response.parsed_data {
        map.insert("parsed_data".to_string(), parsed_data.clone());
    }

    map.insert("cache_hit".to_string(), OwnedValue::from(response.cache_hit));

    if let Some(compression_saved) = response.compression_saved {
        map.insert("compression_saved".to_string(), OwnedValue::from(compression_saved as u64));
    }

    Ok(OwnedValue::Object(Box::new(map)))
}