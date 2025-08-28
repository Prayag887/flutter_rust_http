use std::collections::HashMap;
use std::time::{Instant, Duration};
use std::sync::Arc;
use tokio::sync::Semaphore;
use rand::Rng;

// Import your library components
use flutter_rust_http::HttpClient;
use flutter_rust_http::HttpRequest;

#[tokio::main]
async fn main() {
    println!("Starting HTTP client benchmark...");

    // Wrap HttpClient in Arc to allow sharing across async tasks
    let client = Arc::new(HttpClient::new());

    let test_urls = vec![
        "https://httpbin.org/get",
        "https://httpbin.org/ip",
        "https://httpbin.org/user-agent",
        "https://httpbin.org/headers",
        "https://jsonplaceholder.typicode.com/posts/1",
    ];

    println!("\n=== Single Request Latency Test ===");
    test_single_request_latency(&client, test_urls[0]).await;

    println!("\n=== Sequential Requests Test ===");
    test_sequential_requests(&client, &test_urls).await;

    println!("\n=== Concurrent Requests Test ===");
    test_concurrent_requests(&client, &test_urls, 10).await;

    println!("\n=== Throughput Test ===");
    test_throughput(&client, test_urls[0], 20).await;

    println!("\n=== Payload Size Test ===");
    test_different_payload_sizes(&client).await;

    println!("\nBenchmark completed!");
}

async fn test_single_request_latency(client: &Arc<HttpClient>, url: &str) {
    let mut latencies = Vec::new();
    let warmup_runs = 3;
    let test_runs = 10;

    for _ in 0..warmup_runs {
        let _ = make_request(client, url, rand::thread_rng().gen::<u32>()).await;
    }

    for i in 0..test_runs {
        let start = Instant::now();
        match make_request(client, url, rand::thread_rng().gen::<u32>()).await {
            Ok(response) => {
                let duration = start.elapsed();
                latencies.push(duration);
                println!("Run {}: {}ms, Status: {}, Size: {} bytes",
                    i+1, duration.as_millis(), response.status_code, response.body.len());
            }
            Err(err) => {
                println!("Run {}: Error - {:?}", i+1, err);
            }
        }
    }

    if !latencies.is_empty() {
        let total_time: Duration = latencies.iter().sum();
        let avg_latency = total_time / latencies.len() as u32;
        let min_latency = latencies.iter().min().unwrap();
        let max_latency = latencies.iter().max().unwrap();

        println!("Latency Statistics:");
        println!("  Average: {}ms", avg_latency.as_millis());
        println!("  Min: {}ms", min_latency.as_millis());
        println!("  Max: {}ms", max_latency.as_millis());
    }
}

async fn test_sequential_requests(client: &Arc<HttpClient>, urls: &[&str]) {
    let start = Instant::now();

    for (i, url) in urls.iter().enumerate() {
        let request_start = Instant::now();
        match make_request(client, url, rand::thread_rng().gen::<u32>()).await {
            Ok(response) => {
                let duration = request_start.elapsed();
                println!("Request {}: {}ms, Status: {}, Size: {} bytes",
                    i+1, duration.as_millis(), response.status_code, response.body.len());
            }
            Err(err) => {
                println!("Request {}: Error - {:?}", i+1, err);
            }
        }
    }

    println!("Total time for {} sequential requests: {}ms",
        urls.len(), start.elapsed().as_millis());
}

async fn test_concurrent_requests(client: &Arc<HttpClient>, urls: &[&str], concurrency: usize) {
    let start = Instant::now();
    let semaphore = Arc::new(Semaphore::new(concurrency));
    let mut tasks = Vec::new();

    for (i, url) in urls.iter().enumerate() {
        let client = Arc::clone(client); // clone Arc
        let url = url.to_string();
        let permit = semaphore.clone().acquire_owned().await.unwrap();
        let random_val = rand::thread_rng().gen::<u32>();

        tasks.push(tokio::spawn(async move {
            let request_start = Instant::now();
            let result = make_request(&client, &url, random_val).await;
            drop(permit);
            (i, request_start.elapsed(), result)
        }));
    }

    let mut results = Vec::new();
    for task in tasks {
        match task.await {
            Ok((i, duration, result)) => results.push((i, duration, result)),
            Err(e) => eprintln!("Task failed: {:?}", e),
        }
    }

    results.sort_by_key(|(i, _, _)| *i);
    for (i, duration, result) in results {
        match result {
            Ok(response) => {
                println!("Request {}: {}ms, Status: {}, Size: {} bytes",
                    i+1, duration.as_millis(), response.status_code, response.body.len());
            }
            Err(err) => {
                println!("Request {}: Error - {:?}", i+1, err);
            }
        }
    }

    println!("Total time for {} concurrent requests: {}ms",
        urls.len(), start.elapsed().as_millis());
}

async fn test_throughput(client: &Arc<HttpClient>, url: &str, count: usize) {
    let start = Instant::now();
    let mut successful = 0;
    let mut total_bytes = 0;

    for i in 0..count {
        match make_request(client, url, rand::thread_rng().gen::<u32>()).await {
            Ok(response) => {
                successful += 1;
                total_bytes += response.body.len();
                if i % 5 == 0 {
                    println!("Completed {} requests...", i+1);
                }
            }
            Err(err) => eprintln!("Request {} failed: {:?}", i+1, err),
        }
    }

    let total_duration = start.elapsed();
    let requests_per_second = successful as f64 / total_duration.as_secs_f64();
    let mbps = (total_bytes as f64 * 8.0) / (total_duration.as_secs_f64() * 1_000_000.0);

    println!("Throughput Results:");
    println!("  Successful requests: {}/{}", successful, count);
    println!("  Total time: {}ms", total_duration.as_millis());
    println!("  Requests per second: {:.2}", requests_per_second);
    println!("  Throughput: {:.2} Mbps", mbps);
    println!("  Total data: {:.2} KB", total_bytes as f64 / 1024.0);
}

async fn test_different_payload_sizes(client: &Arc<HttpClient>) {
    let endpoints = vec![
        ("Small payload", "https://httpbin.org/bytes/100"),
        ("Medium payload", "https://httpbin.org/bytes/1024"),
        ("Large payload", "https://httpbin.org/bytes/10240"),
    ];

    for (name, url) in endpoints {
        let start = Instant::now();
        match make_request(client, url, rand::thread_rng().gen::<u32>()).await {
            Ok(response) => {
                println!("{}: {}ms, Size: {} bytes",
                    name, start.elapsed().as_millis(), response.body.len());
            }
            Err(err) => println!("{}: Error - {:?}", name, err),
        }
    }
}

async fn make_request(client: &Arc<HttpClient>, url: &str, random_val: u32) -> Result<flutter_rust_http::models::HttpResponse, anyhow::Error> {
    let mut params: HashMap<&str, String> = HashMap::new();
    params.insert("r", random_val.to_string());

    let request = HttpRequest {
        url,
        method: "GET",
        headers: Default::default(),
        body: None,
        query_params: params.iter().map(|(k,v)| (*k, v.as_str())).collect(),
        timeout_ms: 10000,
        follow_redirects: true,
        max_redirects: 5,
        connect_timeout_ms: 5000,
        read_timeout_ms: 10000,
        write_timeout_ms: 10000,
        auto_referer: true,
        decompress: true,
        http3_only: false,
    };

    client.execute_request(request).await
}
