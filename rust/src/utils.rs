use anyhow::Result;
use serde::de::DeserializeOwned;
use serde::Serialize;

pub fn serialize<T: Serialize>(value: &T) -> Result<String> {
    serde_json::to_string(value).map_err(Into::into)
}

pub fn deserialize<T: DeserializeOwned>(json: &str) -> Result<T> {
    serde_json::from_str(json).map_err(Into::into)
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