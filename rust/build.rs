use std::env;
use std::path::PathBuf;

fn main() {
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();

    let output_path = PathBuf::from(&crate_dir)
        .join("flutter")
        .join("lib")
        .join("src");

    cbindgen::Builder::new()
        .with_crate(crate_dir)
        .with_language(cbindgen::Language::C)
        .generate()
        .expect("Unable to generate bindings")
        .write_to_file(output_path.join("bindings.h"));

    // Only link to external libraries if needed
    if env::var("TARGET").unwrap().contains("android") {
        println!("cargo:rustc-link-lib=dylib=log");
    }
}
