---
name: implement-tauri-feature
description: Implement complete features in this repository across the static HTML/CSS/JavaScript frontend and Rust Tauri v2 backend, including IPC contracts, validation, command registration, tests, keyboard interaction, and documentation. Use when adding or changing user-visible behavior that crosses `ui/` and `src-tauri/`, or when introducing a new Tauri command.
---

# Implement Tauri Feature

Build a narrow, testable path from the interface to Rust and back.

## Workflow

1. Define the user action, success state, error state, and data contract before editing.
2. Implement backend behavior in `src-tauri/src/`:
   - Keep `#[tauri::command]` functions narrow.
   - Deserialize owned command arguments, validate them again in Rust, and return typed serializable values or `Result<T, String>`.
   - Put reusable logic in ordinary Rust helpers and unit-test edge cases without launching Tauri.
   - Register every new command in `tauri::generate_handler!`.
3. Implement frontend behavior in `ui/` with plain HTML, CSS, and JavaScript:
   - Invoke commands through `window.__TAURI__.core.invoke()` and preserve browser-preview behavior when Tauri is unavailable.
   - Pass JavaScript argument keys in camel case for Rust snake-case parameters.
   - Show busy, success, and actionable error states; always restore controls in `finally`.
   - Prefer `textContent` and DOM APIs over HTML-string injection.
4. Add a discoverable keyboard shortcut for each primary action and prevent the browser default only when the shortcut is handled.
5. Use `$secure-tauri-capabilities` if the feature adds a plugin, OS API, remote connection, file access, or a new security boundary.
6. Update README behavior and shortcut documentation when the user-facing contract changes.
7. Run `$verify-tauri-change` at the depth appropriate to the feature.

## Contract Checklist

- Keep frontend and backend validation behavior aligned, with Rust authoritative.
- Serialize Rust response structs with `#[serde(rename_all = "camelCase")]` when JavaScript consumes them.
- Return user-safe errors; do not expose secrets, internal paths, or debug dumps.
- Avoid long-running work on the UI thread and disable duplicate submissions while a request is active.
- Preserve the no-Node, no-bundler frontend architecture.
