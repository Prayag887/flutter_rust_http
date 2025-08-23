use simd_json::OwnedValue;
use simd_json::serde::from_owned_value;
use anyhow::Result;
use serde::Serialize;
use crate::models::{EnhancedHttpRequest, EnhancedHttpResponse};

/// Parse a single request from JSON string using simd-json
pub fn parse_request(json: &str) -> Result<EnhancedHttpRequest> {
    let mut json_owned = json.to_string(); // make mutable copy
    let value: OwnedValue = unsafe { simd_json::from_str(&mut json_owned)? }; // unsafe parse
    let request: EnhancedHttpRequest = from_owned_value(value)?;             // deserialize
    Ok(request)
}

/// Parse a batch of requests from JSON string
pub fn parse_batch_requests(json: &str) -> Result<Vec<EnhancedHttpRequest>> {
    let mut json_owned = json.to_string();
    let value: OwnedValue = unsafe { simd_json::from_str(&mut json_owned)? };
    let requests: Vec<EnhancedHttpRequest> = from_owned_value(value)?; // SIMD deserialization
    Ok(requests)
}

/// Parse raw bytes into simd-json OwnedValue
pub fn parse_json_with_schema_bytes(json: &[u8], _schema: Option<&str>) -> Result<OwnedValue> {
    let mut bytes = json.to_vec();
    let value: OwnedValue = simd_json::to_owned_value(&mut bytes)?; // parse in place
    Ok(value)
}

/// Serialize response to bytes (serde_json still used for convenience)
pub fn serialize_response_to_bytes(response: &EnhancedHttpResponse) -> Result<Vec<u8>> {
    let mut writer = Vec::with_capacity(1024);
    let mut ser = serde_json::Serializer::new(&mut writer);
    response.serialize(&mut ser)?; // requires `use serde::Serialize`
    Ok(writer)
}

/// Serialize response to string
pub fn serialize_response(response: &EnhancedHttpResponse) -> Result<String> {
    Ok(serde_json::to_string(response)?)
}
