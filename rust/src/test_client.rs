use anyhow::Result;
use reqwest::{Client, Version};
use std::time::Instant;

#[tokio::main]
async fn main() -> Result<()> {
    let url = "https://api.github.com/search/repositories?q=flutter&sort=stars";
    let client = Client::builder()
        .user_agent("flutter-rust-http-test")
        .build()?;

    let start = Instant::now();
    let res = client
        .get(url)
        .header("Accept", "application/vnd.github.v3+json")
        .version(Version::HTTP_11)
        .send()
        .await?;

    let status = res.status();
    let body = res.text().await?;
    let elapsed = start.elapsed().as_millis();

    println!("Status: {}", status);
    println!("Elapsed: {} ms", elapsed);
    println!("Body length: {}", body.len());
    println!("Body snippet: {}", &body[..body.len().min(200)]);

    Ok(())
}
