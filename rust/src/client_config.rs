use reqwest::Client;
use std::time::Duration;

pub struct ClientConfig;

impl ClientConfig {
    /// Mobile client for isolated use
    pub fn build_mobile_client() -> Client {
        Client::builder()
            .pool_idle_timeout(Duration::from_secs(300))    // Keep connections alive 5 min
            .pool_max_idle_per_host(50)                     // High reuse
            .tcp_keepalive(Duration::from_secs(15))         // Fast dead detection
            .tcp_nodelay(true)                              // Disable Nagle
            .http2_initial_stream_window_size(Some(8 * 1024 * 1024))
            .http2_initial_connection_window_size(Some(32 * 1024 * 1024))
            .http2_adaptive_window(true)
            .http2_max_frame_size(Some(65535))
            .http2_keep_alive_interval(Duration::from_secs(10))
            .http2_keep_alive_timeout(Duration::from_secs(20))
            .http2_keep_alive_while_idle(true)
            .connect_timeout(Duration::from_secs(8))
            .timeout(Duration::from_secs(20))
            .use_rustls_tls()
            .min_tls_version(reqwest::tls::Version::TLS_1_2)
            .no_proxy()
            .redirect(reqwest::redirect::Policy::limited(3))
            .referer(false)
            .build()
            .expect("Failed to build mobile client")
    }

    /// Shared mobile client for app-wide use
    pub fn build_shared_mobile_client() -> Client {
        Client::builder()
            .pool_idle_timeout(Duration::from_secs(600))    // Keep alive 10 min
            .pool_max_idle_per_host(100)                    // Max reuse
            .tcp_keepalive(Duration::from_secs(15))
            .tcp_nodelay(true)
            .http2_initial_stream_window_size(Some(16 * 1024 * 1024))
            .http2_initial_connection_window_size(Some(64 * 1024 * 1024))
            .http2_adaptive_window(true)
            .http2_max_frame_size(Some(65535))
            .http2_keep_alive_interval(Duration::from_secs(10))
            .http2_keep_alive_timeout(Duration::from_secs(20))
            .http2_keep_alive_while_idle(true)
            .connect_timeout(Duration::from_secs(5))
            .timeout(Duration::from_secs(15))
            .use_rustls_tls()
            .min_tls_version(reqwest::tls::Version::TLS_1_2)
            .no_proxy()
            .redirect(reqwest::redirect::Policy::limited(5))
            .referer(false)
            .build()
            .expect("Failed to build shared mobile client")
    }
}
