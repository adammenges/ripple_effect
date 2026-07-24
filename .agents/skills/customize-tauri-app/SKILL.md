---
name: customize-tauri-app
description: Rename, rebrand, and configure this Rust/Tauri macOS template consistently across Cargo metadata, Tauri configuration, Rust crate references, static UI copy, documentation, and app icons. Use for starting a new app from the template or changing its product name, bundle identifier, version, description, window title, defaults, or branding.
---

# Customize Tauri App

Keep every identity-bearing file aligned so development and packaged builds describe the same app.

## Workflow

1. Inspect current values before editing:
   - `src-tauri/Cargo.toml`: package name, version, and description.
   - `src-tauri/src/main.rs`: generated Rust crate path.
   - `src-tauri/tauri.conf.json`: `productName`, `version`, `identifier`, and window title.
   - `ui/`: defaults, headings, help text, and example commands.
   - `README.md`: setup, examples, and project description.
2. Choose a human-readable product name, reverse-DNS bundle ID, semantic version, and Rust package name. Convert hyphens in the package name to underscores when referencing the crate from Rust.
3. Change all related values together. Preserve the static `ui/` architecture and existing security settings unless the request explicitly changes them.
4. Search for stale branding with `rg` using each old name, identifier, and example value.
5. Use `$create-macos-app-icon` when branding includes a new icon.
6. Run `$verify-tauri-change`; package with `$package-macos-app` when bundle metadata or release behavior changed.

## Guardrails

- Keep bundle IDs reverse-DNS formatted and stable after release.
- Keep the Tauri version and Cargo package version synchronized.
- Do not hand-edit generated files under `src-tauri/gen/`.
- Do not rename the Rust crate without updating every Rust reference and the lockfile through Cargo.
- Keep README commands directly runnable from the repository root.
