use simd_json::OwnedValue;
use anyhow::Result;


/// Parse raw bytes into simd-json OwnedValue
pub fn parse_json_with_schema_bytes(json: &[u8], _schema: Option<&str>) -> Result<OwnedValue> {
    let mut bytes = json.to_vec();
    let value: OwnedValue = simd_json::to_owned_value(&mut bytes)?; // parse in place
    Ok(value)
}
