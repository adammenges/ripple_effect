# Rust + Tauri macOS Template

A small, production-minded starting point for native-feeling macOS apps built with Rust and [Tauri 2](https://v2.tauri.app). The frontend is plain HTML, CSS, and JavaScript: no Node.js, package manager, bundler, or frontend build step.

## What is included

- Rust 2024 backend with typed, validated Tauri IPC and unit tests
- Responsive terminal-inspired UI that remains usable down to a 420 px window
- Native macOS title bar overlay with a matching app background
- Keyboard access for every primary action
- Capability-based permissions, a restrictive content security policy, and frozen JavaScript prototypes
- Reproducible Rust, Tauri CLI, and Cargo dependency versions
- Icon generation and verified Apple Silicon `.app` packaging
- Dependabot update configuration
- Agent instructions and a durable feedback loop

## Requirements

- macOS 13 or newer
- [rustup](https://rustup.rs)
- Xcode Command Line Tools (`xcode-select --install`)

The repository pins Rust 1.95.0 and Tauri CLI 2.11.4. Packaged apps explicitly target Apple Silicon (`aarch64-apple-darwin`) to keep artifacts smaller; Intel Macs are not supported.

## Start here

```bash
./scripts/setup.sh
./scripts/doctor.sh
./scripts/dev.sh
```

The Tauri dev server watches both `ui/` and the Rust crate. You can also open `ui/index.html` directly for a visual-only browser preview; IPC actions are disabled in that mode.

## Check and package

```bash
./scripts/check.sh
./scripts/build_macos_app.sh
open "dist/Rust Tauri Template.app"
```

`check.sh` validates shell and JavaScript syntax, checks Rust formatting, runs Clippy with warnings denied, and executes all tests.

The build script generates icons when needed, runs a locked ARM64 release build, copies the `.app` to `dist/`, applies an ad-hoc signature when no valid signing identity was used, and verifies its metadata, executable architecture, icon, and signature.

### Customize a build

```bash
APP_NAME="My App" \
APP_BUNDLE_ID="com.example.my-app" \
APP_VERSION="1.2.3" \
./scripts/build_macos_app.sh
```

Additional build variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `APP_NAME` | `productName` in Tauri config | Bundle and display name |
| `APP_BUNDLE_ID` | `identifier` in Tauri config | macOS bundle identifier |
| `APP_VERSION` | crate version | Bundle version |
| `ICON_SOURCE` | `assets/icons/AppIcon-1024.png` | Square PNG or SVG icon source |
| `DIST_DIR` | `dist` | Final bundle directory |
| `FORCE_ICONS` | `0` | Regenerate every platform icon when set to `1` |

## Keyboard map

| Shortcut | Action |
| --- | --- |
| <kbd>⌘1</kbd> / <kbd>⌘2</kbd> | Focus app name / bundle ID |
| <kbd>⌘R</kbd> | Preview the repository check command |
| <kbd>⌘B</kbd> | Validate config and preview the build command |
| <kbd>⌘K</kbd> | Reset the demo configuration |
| <kbd>⌘/</kbd> | Toggle the shortcut panel |

These shortcuts are window-scoped and do not register system-wide hotkeys.

## Project map

```text
ui/                          Static frontend
src-tauri/src/               Rust commands and app entry point
src-tauri/tauri.conf.json    Window, security, and bundle configuration
src-tauri/capabilities/      Tauri permission grants
assets/icons/                Source app icon
assets/symbols/              Exported SF Symbols for future screens
scripts/                     Setup, checks, development, icons, packaging
.agents/skills/              Reusable repository-specific agent workflows
AGENTS.md                    Coding-agent guidance
FEEDBACK.md                  Persistent project-specific corrections
```

Frontend calls use `window.__TAURI__.core.invoke()`, enabled by `withGlobalTauri` in `tauri.conf.json`. Keep backend commands narrow, validate all frontend input again in Rust, and grant only the capabilities a feature requires.

## Common commands

```bash
make             # Show targets
make setup
make doctor
make dev
make check
make icons
make build-app
make clean
```

## Rename the template permanently

For a new app, update these together:

1. Package `name`, `version`, and `description` in `src-tauri/Cargo.toml`.
2. The crate path in `src-tauri/src/main.rs` if the package name changes.
3. `productName`, `version`, `identifier`, and window title in `src-tauri/tauri.conf.json`.
4. Default values and copy in `ui/`.
5. `assets/icons/AppIcon-1024.png`, then run `make icons`.

Run `make check` and `make build-app` after renaming.

## Signing and distribution

Local builds receive an ad-hoc signature suitable for development. Distribution outside your Mac additionally requires an Apple Developer certificate and notarization. Configure Tauri's macOS signing environment in your release workflow; do not commit certificates or credentials.

## Use as a GitHub template

Enable **Settings → General → Template repository**, then choose **Use this template**. Remove any project-specific history or defaults you do not want downstream before publishing.

## License

[MIT](LICENSE)
