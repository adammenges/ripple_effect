---
name: macos-native-integration
description: Design and implement native macOS behavior in this Tauri v2 repository, including application menus, app-scoped or global shortcuts, Dock and menu-bar behavior, notifications, file associations, open-file events, deep links, launch-at-login, native dialogs, and protected system permissions. Use when a feature must integrate with macOS outside the static webview or behave correctly across app launch, activation, window, and permission lifecycles.
---

# macOS Native Integration

Make the app feel native by using macOS conventions and narrow Rust/Tauri APIs while preserving the template's static frontend and least-authority boundary.

## Define the Native Contract

1. Describe the user action, macOS surface, cold-start behavior, already-running behavior, denied-permission behavior, and visible recovery path before editing.
2. Distinguish app-scoped shortcuts from system-wide shortcuts. Prefer app-scoped shortcuts unless the feature must work while another app is active.
3. Decide whether the app is a regular Dock app, a menu-bar utility, or intentionally supports both. Keep activation policy, window reopening, and quit behavior consistent with that choice.
4. Check the minimum supported macOS version in `tauri.conf.json` before selecting an API.
5. Prefer Tauri core APIs, a maintained official plugin, or a narrow Rust/macOS binding. Do not use shell commands or AppleScript when a direct supported API exists.

## Implement the Boundary

- Keep OS authority in Rust. Send typed domain events and command results to JavaScript rather than raw native handles, unrestricted URLs, or arbitrary paths.
- Initialize plugins and native event handlers deliberately in the Tauri builder lifecycle. Register listeners early enough for launch events and make repeated activation idempotent.
- Account for macOS main-thread requirements. Keep blocking work off the UI thread and clean up listeners, tray items, and global registrations when their owner is destroyed.
- Add the minimum Cargo feature, plugin permission, capability grant, Info.plist key, URL/file-type declaration, or entitlement required by the chosen API.
- Treat Tauri capabilities, macOS usage descriptions, entitlements, and runtime permission prompts as separate layers; configure and verify every layer the feature needs.
- Use `$secure-tauri-capabilities` for every plugin, external URL, file scope, global shortcut, protected resource, or expanded IPC boundary. Use `$implement-tauri-feature` when the native behavior crosses into `ui/`.

## Follow macOS Conventions

- Build standard application menus and roles before adding custom items. Use familiar labels and shortcuts, keep menu enabled state synchronized with app state, and avoid overriding reserved system shortcuts.
- Give every primary command a discoverable menu item or in-app shortcut when appropriate. Do not register a global hotkey merely to satisfy the repository's keyboard-access rule.
- Request notifications or protected-resource permission only in response to a clear feature need. Explain the value first, handle denial without nagging, and provide a path to System Settings when useful.
- Validate file extensions, content, size, canonicalized paths, URL schemes, hosts, and payload lengths in Rust. Handle open-file and deep-link events both at cold launch and while the app is running.
- For native dialogs, cancellation is a normal result. Preserve the current document or state until a selected operation succeeds.
- For menu-bar apps, keep status-item labels and icons accessible, define behavior when all windows close, and make Quit unambiguous.
- For launch-at-login, expose an explicit reversible preference and reflect the actual system registration state.

## Verify Native Behavior

- Unit-test parsing, validation, deduplication, and event-to-domain mapping without launching the app where possible.
- Test cold launch, second activation, reopen after closing all windows, repeated events, multiple files or links, cancellation, denial, and revoked permissions.
- Confirm app-scoped shortcuts do nothing when the app is inactive and global shortcuts unregister cleanly.
- Run `$verify-tauri-change`, then exercise the integration in the real Tauri app rather than relying on browser preview.
- Use `$package-macos-app` when bundle metadata, file associations, URL schemes, usage descriptions, entitlements, signing, or launch behavior changed; inspect the built bundle instead of assuming configuration was embedded.
- Update README behavior, permissions, shortcuts, and any setup or recovery instructions visible to users.
