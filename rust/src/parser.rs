use anyhow::Result;
use serde_json::Value;

pub fn parse_request(json: &str) -> Result<crate::models::EnhancedHttpRequest> {
    serde_json::from_str(json).map_err(Into::into)
}

pub fn serialize_response(response: &crate::models::EnhancedHttpResponse) -> Result<String> {
    serde_json::to_string(response).map_err(Into::into)
}

pub fn parse_json_with_schema(json: &str, schema: Option<&str>) -> Result<Value> {
    if let Some(_schema_str) = schema {
        validate_and_parse(json)
    } else {
        serde_json::from_str(json).map_err(Into::into)
    }
}

pub fn parse_batch_requests(
    json: &str,
) -> Result<Vec<crate::models::EnhancedHttpRequest>> {
    serde_json::from_str(json).map_err(Into::into)
}

fn validate_and_parse(json: &str) -> Result<Value> {
    // In production, you could validate with jsonschema crate
    // For now, just parse normally
    serde_json::from_str(json).map_err(Into::into)
}
