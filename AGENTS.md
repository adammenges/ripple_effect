# AGENTS.md

These instructions are for coding agents working in this repository (Codex, Claude Code, Qodo, Cursor, etc.).

## Feedback Loop

If I ever correct you, add the correction to `FEEDBACK.md` so it never happens again.

## Mission

Build clean, modern macOS desktop apps in Rust with Tauri, while keeping behavior and visuals aligned with the Apple ecosystem.

## Non-negotiables

- Prefer simple, legible UI and obvious interaction flows.

## UI direction

- Very CLI like a terminal, but in a hacky kind of cool way.
- Keyboard shortcuts for every primary action.
- ASCII art is welcome when it remains accessible and responsive.
- Aim for beautiful, easy to use, and hacker-oriented.
- Center the UI and make it adapt cleanly at every supported window width.

## Architecture

- Backend: Rust via Tauri v2 (`src-tauri/`)
- Frontend: static HTML/CSS/JS (`ui/`) — no Node.js or bundler required
- IPC: Tauri commands (`#[tauri::command]`) invoked from JS via `window.__TAURI__.core.invoke()`
- Configuration: `src-tauri/tauri.conf.json`

## Iconography

- Prefer SF Symbols for in-app iconography.
- Store symbol exports in `assets/symbols/` (typically SVG).
- Keep icon weights and sizes consistent within a screen.

## Build and packaging expectations

- `.app` bundles are created with `cargo tauri build` (wrapped by `scripts/build_macos_app.sh`).
- macOS bundles target Apple Silicon only (`aarch64-apple-darwin`); do not add Intel or universal build paths.
- Icon generation pipeline:
  - `assets/icons/AppIcon-1024.png`
  - `cargo tauri icon` generates the platform icon set in `src-tauri/icons/`
  - the bundle embeds `Contents/Resources/icon.icns`
- If icon source is missing, fallback chain is:
  - `scripts/generate_default_icon.swift`
  - existing `src-tauri/icons/icon.png`

## Commands agents should run

```bash
./scripts/dev.sh
./scripts/check.sh
./scripts/build_macos_app.sh
./scripts/doctor.sh
```

## Repository skills

Use the focused skills in `.agents/skills/` when their descriptions match the task:

- `customize-tauri-app`
- `implement-tauri-feature`
- `design-terminal-ui`
- `secure-tauri-capabilities`
- `create-macos-app-icon`
- `diagnose-macos-toolchain`
- `verify-tauri-change`
- `package-macos-app`
- `tauri-local-data`
- `macos-native-integration`

## Change checklist

- Keep README/docs in sync with behavior.
- Keep scripts executable and cross-shell safe (`bash`, `set -euo pipefail`).
- Validate macOS packaging still works after refactors.
- Frontend changes go in `ui/`, backend changes go in `src-tauri/src/`.
