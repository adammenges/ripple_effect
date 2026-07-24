---
name: diagnose-macos-toolchain
description: Diagnose local setup, development, compile, linker, architecture, Tauri CLI, Xcode Command Line Tools, Cargo lockfile, or macOS packaging failures in this repository. Use when `setup.sh`, `doctor.sh`, `dev.sh`, Cargo, Tauri, ARM64 builds, codesigning, or generated app bundles fail or behave differently across machines.
---

# Diagnose macOS Toolchain

Find the failing layer and report the smallest evidence-backed cause. Do not install tools or change configuration unless the user also asks for a fix.

## Triage Order

1. Capture the exact command, complete error, macOS version, and host architecture when relevant.
2. Run `./scripts/doctor.sh` for required commands, Tauri CLI availability, Xcode tools, and locked Cargo metadata.
3. Inspect pinned versions in `rust-toolchain.toml`, `Cargo.lock`, and the setup script before comparing installed versions.
4. Isolate the layer:
   - Browser-only UI: open `ui/index.html` and check JavaScript syntax.
   - Rust code: run the focused test or `cargo check --workspace --all-targets --all-features --locked`.
   - Full validation: run `./scripts/check.sh`.
   - Development runtime: run `./scripts/dev.sh` and preserve the first meaningful error.
   - Packaging, signing, or icon embedding: use `$package-macos-app`.
5. Check whether the failure is caused by missing tools, version drift, stale lock data, wrong architecture target, an invalid configuration, or application code.
6. State the root cause, supporting output, and the minimal next action. Separate confirmed facts from hypotheses.

## Guardrails

- Do not run `scripts/setup.sh` during diagnosis unless installation is authorized; it changes the toolchain and may use the network.
- Do not delete caches, `Cargo.lock`, build outputs, certificates, or user configuration as a first response.
- Do not hide the original error behind repeated broad builds.
- Preserve environment variables and architecture flags from the failing command when reproducing it.
