# Ripple

Ripple is a small macOS app that turns a before image and an after image into a polished ripple-transition MP4. Rendering stays on the Mac: a native Metal compute shader generates the frames and AVFoundation writes H.264 directly, with no upload, web service, or external video tool.

## Use the app

1. Choose the **before** image.
2. Choose the **after** image.
3. Select **Render MP4**, choose a save location, and wait for the completion message.

The native image picker accepts PNG, JPEG, HEIC, HEIF, and TIFF files up to 100 MB each. The save panel creates an `.mp4` file.

## Video output

Every render uses a deliberately simple fixed recipe:

- 3 seconds at 60 fps (180 frames)
- H.264 in an MP4 container
- Centered ripple origin
- The before image defines the frame aspect ratio
- The longest edge is capped at 1920 pixels; smaller images keep their native size
- Both images are aspect-filled into the output frame
- A smooth before/after crossfade runs underneath the ripple layer effect

The Metal kernel in `src-tauri/native/RippleRenderer.swift` preserves the supplied shader's effect math:

```text
distance → travel delay → adjusted time
         → sine wave × exponential decay
         → radial sample displacement
         → ripple-based light/dark modulation
```

Its fixed parameters are amplitude `18`, frequency `16`, decay `5`, and speed `1500`. The renderer compiles the shader with the system Metal device, writes each frame into a Metal-compatible pixel buffer, and sends those frames directly to AVFoundation.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| <kbd>⌘1</kbd> | Choose the before image |
| <kbd>⌘2</kbd> | Choose the after image |
| <kbd>⌘↵</kbd> | Render the MP4 |
| <kbd>⌘K</kbd> | Clear both images |
| <kbd>⌘/</kbd> | Toggle the in-app keymap |

The shortcuts are app-scoped and do not register global hotkeys.

## Requirements

- Apple Silicon Mac
- macOS 13 or newer
- [rustup](https://rustup.rs)
- Xcode Command Line Tools (`xcode-select --install`)

The repository pins Rust 1.95.0, Tauri CLI 2.11.4, and Tauri 2.11.5. The scripts explicitly put the pinned rustup toolchain first, even when a Homebrew Rust installation appears earlier in the shell path.

## Develop

```bash
./scripts/setup.sh
./scripts/doctor.sh
./scripts/dev.sh
```

The frontend is static HTML, CSS, and JavaScript with no Node.js build step. `./scripts/dev.sh` launches the Tauri app with hot reload. You can also open `ui/index.html` for a visual-only browser preview; native image selection and Metal rendering require Tauri.

## Check and package

```bash
./scripts/check.sh
./scripts/build_macos_app.sh
open "dist/Ripple.app"
```

`check.sh` validates shell and JavaScript syntax, checks Rust formatting, runs Clippy with warnings denied, and runs the test suite. The build wrapper produces and verifies an ARM64-only `.app`, checks its metadata and icon, and applies an ad-hoc signature when needed for local use.

The local bundle uses:

| Field | Value |
| --- | --- |
| Product name | `Ripple` |
| Bundle ID | `com.adammenges.ripple` |
| Version | `0.1.0` |
| Minimum macOS | `13.0` |

Intel and universal builds are intentionally unsupported. Distributing the app to other Macs still requires Developer ID signing and notarization.

## Architecture

```text
ui/
  index.html                 Two-image workflow and accessible status UI
  style.css                  Responsive terminal-inspired macOS styling
  main.js                    App state, shortcuts, and narrow Tauri IPC calls

src-tauri/
  src/lib.rs                 Validation, native dialogs, render orchestration
  native/RippleRenderer.swift
                             Metal + Core Image + AVFoundation renderer
  build.rs                   Compiles and embeds the native renderer
  tauri.conf.json            Window, CSP, bundle, and macOS configuration
  capabilities/default.json  Main-window permissions
```

The webview cannot read or write arbitrary files. Rust opens native system sheets, retains the selected paths in backend state, validates them again before rendering, and invokes the embedded renderer with fixed positional arguments rather than a shell. The dialog plugin's JavaScript permissions are not granted.

## Common commands

```bash
make             # Show targets
make setup
make doctor
make dev
make check
make icons
make build-app
```

## License

[MIT](LICENSE)
