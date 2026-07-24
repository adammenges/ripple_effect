use std::{
    env,
    path::{Path, PathBuf},
    process::Command,
};

const MINIMUM_MACOS_VERSION: &str = "13.0";

fn main() {
    build_metal_renderer();
    tauri_build::build();
}

fn build_metal_renderer() {
    assert!(
        env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("macos"),
        "Ripple is a macOS-only application."
    );

    let source = Path::new("native/RippleRenderer.swift");
    let output_directory = PathBuf::from(env::var_os("OUT_DIR").expect("OUT_DIR is required"));
    let output = output_directory.join("ripple-renderer");
    let module_cache = output_directory.join("swift-module-cache");
    let target =
        swift_target(&env::var("TARGET").expect("Cargo TARGET is required for the renderer build"));
    let sdk = command_output(&["--sdk", "macosx", "--show-sdk-path"]);
    let optimization = if env::var("PROFILE").as_deref() == Ok("release") {
        "-O"
    } else {
        "-Onone"
    };

    println!("cargo:rerun-if-changed={}", source.display());

    let status = Command::new("xcrun")
        .args(["--sdk", "macosx", "swiftc"])
        .arg(source)
        .args(["-parse-as-library", optimization, "-sdk"])
        .arg(sdk.trim())
        .args(["-target", &target, "-o"])
        .arg(&output)
        .env("CLANG_MODULE_CACHE_PATH", module_cache)
        .status()
        .expect("failed to start the Swift compiler");

    assert!(
        status.success(),
        "failed to compile the bundled Metal renderer"
    );
}

fn swift_target(rust_target: &str) -> String {
    let architecture = if rust_target.starts_with("aarch64-") {
        "arm64"
    } else if rust_target.starts_with("x86_64-") {
        "x86_64"
    } else {
        panic!("unsupported macOS architecture: {rust_target}");
    };

    format!("{architecture}-apple-macosx{MINIMUM_MACOS_VERSION}")
}

fn command_output(arguments: &[&str]) -> String {
    let output = Command::new("xcrun")
        .args(arguments)
        .output()
        .expect("failed to start xcrun");

    assert!(output.status.success(), "xcrun failed");
    String::from_utf8(output.stdout).expect("xcrun returned non-UTF-8 output")
}
