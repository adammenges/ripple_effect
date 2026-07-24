---
name: verify-tauri-change
description: Validate changes to this Rust/Tauri macOS repository with risk-proportional syntax checks, formatting, Clippy, unit tests, UI inspection, icon validation, configuration review, and app-bundle verification. Use after implementation, before handoff, when reviewing a patch, or when deciding which repository checks are required for a changed file set.
---

# Verify Tauri Change

Prove the changed behavior while keeping the validation scope proportional to its risk.

## Select Checks

- Documentation or agent guidance: inspect the diff, check paths and commands, and search for stale references.
- Frontend-only changes: run JavaScript syntax checks when Node is available, open the browser preview, and exercise changed states at narrow and normal widths.
- Rust or IPC changes: run focused unit tests first, then `./scripts/check.sh`.
- Tauri config or capability changes: run `./scripts/check.sh`, validate the relevant schema/build path, and exercise the affected window or API.
- Icon changes: run `$create-macos-app-icon` validation, regenerate icons, and inspect small outputs.
- Build, bundle metadata, signing, architecture, or release changes: run `$package-macos-app` after checks pass.

## Standard Loop

1. Inspect `git diff --check`, `git diff --stat`, and the actual diff. Preserve unrelated user changes.
2. Run the narrowest test that can fail for the edited behavior.
3. Run `./scripts/check.sh` for code changes unless the environment prevents it.
4. Perform visual or runtime verification for behavior that static checks cannot prove.
5. Reinspect the final diff for generated noise, stale documentation, debug output, secrets, and unintended capability expansion.
6. Report commands run, results, and anything not verified. Never imply a check passed when it was skipped or unavailable.

## Acceptance Bar

- Test invalid input and error paths, not only the happy path.
- Confirm keyboard interaction and browser-preview fallback for primary UI changes.
- Confirm generated artifacts are expected and source-controlled when the repository requires them.
- Treat warnings as failures where the repository scripts do.
