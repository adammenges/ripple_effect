---
name: secure-tauri-capabilities
description: Review and implement security-sensitive Tauri v2 changes involving custom IPC commands, capability permissions, plugins, content security policy, external URLs, filesystem or shell access, secrets, or window scope. Use when editing `src-tauri/capabilities/`, Tauri security configuration, command exposure, or any feature that expands what webview code can access.
---

# Secure Tauri Capabilities

Treat the webview as an untrusted caller and grant only the access required for the requested user flow.

## Review the Boundary

1. Trace data from HTML/JavaScript through `invoke()` to the Rust command and any OS resource it touches.
2. Enumerate untrusted inputs, affected files or services, returned data, and possible side effects.
3. Keep custom commands explicit in `tauri::generate_handler!`; do not expose generic file, shell, or process primitives when a narrow operation will do.
4. Validate paths, identifiers, lengths, formats, and authorization in Rust even when JavaScript already validates them.
5. Return only the minimum data the interface needs.

## Capabilities and CSP

- Inspect `src-tauri/capabilities/default.json` and the generated schema before adding a permission.
- Scope permissions to the relevant window and choose the narrowest plugin permission available.
- Avoid wildcard path, URL, command, and window scopes. Document why any broad grant is unavoidable.
- Keep `app.security.csp` restrictive. Add a source only for a concrete feature and limit it by directive and origin.
- Preserve `freezePrototype` and `removeUnusedCommands` unless a verified compatibility requirement demands otherwise.
- Keep secrets out of frontend files, command output, logs, committed configuration, and error strings.

## Dangerous Inputs

- Do not concatenate user input into shell commands. Prefer direct Rust APIs or fixed executables with separately passed arguments.
- Canonicalize and constrain filesystem paths to an intended root before access; account for symlinks and missing paths.
- Parse URLs and allow only required schemes and hosts before opening or requesting them.
- Require an explicit user action before high-impact OS behavior.

## Verify

Run focused Rust tests for validation and denial cases, validate JSON against the Tauri schema through the normal build/check path, and then use `$verify-tauri-change`. Explain any newly granted authority in the handoff.
