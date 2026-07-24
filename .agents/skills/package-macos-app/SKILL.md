---
name: package-macos-app
description: Build, inspect, and verify an Apple Silicon-only macOS `.app` bundle for this Rust/Tauri v2 repository, including metadata overrides, icon regeneration, the fixed `aarch64-apple-darwin` target, ad-hoc signing, bundle contents, and release handoff. Use for `cargo tauri build`, `scripts/build_macos_app.sh`, `.app` packaging, ARM64 verification, codesigning, embedded icons, or build artifacts in `dist/`.
---

# Package macOS App

Use the repository wrapper so metadata, icons, copying, signing, and verification follow one repeatable path.

## Build Workflow

1. Run `./scripts/doctor.sh`, then `$verify-tauri-change` for the changed code.
2. Confirm product name, bundle ID, and version in `src-tauri/tauri.conf.json` and `src-tauri/Cargo.toml`.
3. Validate `assets/icons/AppIcon-1024.png` with `$create-macos-app-icon` when branding changed.
4. Confirm `aarch64-apple-darwin` is installed, then build with `./scripts/build_macos_app.sh`. Do not add Intel, host-native, or universal target fallbacks.
5. Use documented one-off overrides only when requested:

   ```bash
   APP_NAME="My App" APP_BUNDLE_ID="com.example.my-app" APP_VERSION="1.2.3" ./scripts/build_macos_app.sh
   ```

6. Confirm the script's verified result in `dist/<App Name>.app`. Inspect `Contents/Info.plist`, the executable, `Contents/Resources/icon.icns`, `lipo -archs` output, and `codesign --verify --deep --strict` if diagnosing a packaging discrepancy. Accept only the single `arm64` architecture.

## Release Boundaries

- Treat the wrapper's ad-hoc signature as local-development signing, not distribution signing.
- Do not claim App Store, Developer ID, hardened-runtime, entitlements, or notarization readiness unless those exact workflows were configured and verified.
- Do not commit certificates, profiles, private keys, notarization credentials, or secret environment files.
- Note that the build script replaces the destination app with the same name under `dist/`.
- Preserve `--locked` dependency behavior and pinned Tauri/Rust versions.
- Keep distribution messaging explicit that Intel Macs are unsupported.

## Handoff

Report the absolute bundle path, architecture, metadata values, signature type, commands run, and any distribution steps that remain.
