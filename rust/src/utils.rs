use serde::Serialize;
use serde::de::DeserializeOwned;
use anyhow::Result;
use simd_json::{self, prelude::*};

pub fn serialize<T: Serialize>(value: &T) -> Result<String> {
    Ok(simd_json::to_string(value)?)
}

pub fn deserialize<T: DeserializeOwned>(json: &str) -> Result<T> {
    let mut json_string = json.to_string(); // simd-json requires a mutable buffer
    Ok(simd_json::from_str(&mut json_string)?)
}

pub fn validate_url(url: &str) -> Result<()> {
    if url.is_empty() {
        return Err(anyhow::anyhow!("URL cannot be empty"));
    }

    if !url.starts_with("http://") && !url.starts_with("https://") {
        return Err(anyhow::anyhow!("URL must start with http:// or https://"));
    }

    Ok(())
}
