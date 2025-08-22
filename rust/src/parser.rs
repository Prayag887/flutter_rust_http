use anyhow::Result;
use serde_json::Value;
use simd_json::{self, BorrowedValue};

pub fn parse_request(json: &str) -> Result<crate::models::EnhancedHttpRequest> {
    // Use SIMD JSON when available, fallback to serde
    #[cfg(any(target_arch = "x86", target_arch = "x86_64", target_arch = "aarch64"))]
    {
        let mut json_bytes = json.as_bytes().to_vec();
        match simd_json::to_borrowed_value(&mut json_bytes) {
            Ok(value) => {
                match serde_json::from_value(value.into()) {
                    Ok(req) => return Ok(req),
                    Err(_) => {} // Fall through to serde
                }
            }
            Err(_) => {} // Fall through to serde
        }
    }

    // Fallback to serde_json
    serde_json::from_str(json).map_err(Into::into)
}

pub fn serialize_response(response: &crate::models::EnhancedHttpResponse) -> Result<String> {
    // Use SIMD JSON for serialization when available
    #[cfg(any(target_arch = "x86", target_arch = "x86_64", target_arch = "aarch64"))]
    {
        let value = serde_json::to_value(response)?;
        match simd_json::to_string(&value) {
            Ok(json) => return Ok(json),
            Err(_) => {} // Fall through to serde
        }
    }

    // Fallback to serde_json
    serde_json::to_string(response).map_err(Into::into)
}

pub fn parse_json_with_schema(json: &str, schema: Option<&str>) -> Result<Value> {
    // Use SIMD JSON parsing when available
    #[cfg(any(target_arch = "x86", target_arch = "x86_64", target_arch = "aarch64"))]
    {
        let mut json_bytes = json.as_bytes().to_vec();
        match simd_json::to_borrowed_value(&mut json_bytes) {
            Ok(value) => {
                if let Some(schema_str) = schema {
                    if let Err(e) = validate_with_schema(&value, schema_str) {
                        warn!("Schema validation warning: {}", e);
                    }
                }
                return Ok(value.into());
            }
            Err(_) => {} // Fall through to serde
        }
    }

    // Fallback to serde_json
    let value: Value = serde_json::from_str(json)?;

    if let Some(schema_str) = schema {
        if let Err(e) = validate_with_schema(&value, schema_str) {
            warn!("Schema validation warning: {}", e);
        }
    }

    Ok(value)
}

pub fn parse_batch_requests(json: &str) -> Result<Vec<crate::models::EnhancedHttpRequest>> {
    // Use SIMD JSON when available
    #[cfg(any(target_arch = "x86", target_arch = "x86_64", target_arch = "aarch64"))]
    {
        let mut json_bytes = json.as_bytes().to_vec();
        match simd_json::to_borrowed_value(&mut json_bytes) {
            Ok(value) => {
                match serde_json::from_value(value.into()) {
                    Ok(requests) => return Ok(requests),
                    Err(_) => {} // Fall through to serde
                }
            }
            Err(_) => {} // Fall through to serde
        }
    }

    // Fallback to serde_json
    serde_json::from_str(json).map_err(Into::into)
}

fn validate_with_schema(_value: &Value, _schema: &str) -> Result<()> {
    // In production, implement proper JSON schema validation
    // For now, just a placeholder that always succeeds
    Ok(())
}