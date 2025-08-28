use reqwest::Client;
use std::sync::OnceLock;

/// Global shared client for mobile apps
/// This allows connection pooling across the entire application
/// while minimizing memory usage
pub static MOBILE_CLIENT: OnceLock<Client> = OnceLock::new();