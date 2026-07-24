---
name: tauri-local-data
description: Design and implement durable local data for this Tauri v2 repository using Rust-owned SQLite or filesystem storage, including schemas, migrations, queries, search, backups, import/export, corruption handling, and tests. Use when an app needs persistent settings, structured records, local search, user documents, caches with recovery rules, or any change to its on-disk data lifecycle.
---

# Tauri Local Data

Keep durable state behind a narrow Rust data layer so the webview never receives generic filesystem or SQL authority.

## Choose the Storage Model

1. Classify each datum as ephemeral state, preference, secret, user-owned document, cache, or authoritative app data.
2. Use memory for ephemeral state; do not persist it by accident.
3. Use a small versioned settings file for simple preferences that are read and written as a unit.
4. Use SQLite for structured, mutable, queryable data or when transactions, indexing, relationships, or full-text search matter.
5. Store user-owned documents at an explicitly chosen path. Keep only bookmarks or metadata in app storage when appropriate.
6. Store credentials and tokens in macOS Keychain through an audited integration, never in SQLite, JSON, frontend storage, logs, or source control.
7. Treat caches as disposable: define their source of truth, invalidation rule, size limit, and rebuild path.

Avoid `localStorage` as the system of record. It is acceptable only for nonessential webview presentation state that can be discarded without user-visible data loss.

## Implement the Data Layer

1. Resolve storage from Tauri's application data/config directories; never depend on the process working directory or write into bundled resources.
2. Put storage and query logic in ordinary Rust modules. Expose domain operations through typed `#[tauri::command]` functions rather than raw paths, SQL, or database handles.
3. Define stable serialized types and explicit time, identifier, nullability, and ordering semantics. Keep Rust authoritative for validation.
4. Add only the smallest justified dependency and pin it through the existing Cargo workflow. Prefer a direct Rust data layer over granting the webview a general-purpose database plugin.
5. Bound list and search commands with pagination or result limits. Select only the fields the interface needs.
6. Make writes atomic. For files, write a sibling temporary file, flush when durability matters, and rename. For SQLite, group related changes in a transaction.
7. Map internal failures to actionable, user-safe errors without exposing sensitive values or private paths.

Use `$implement-tauri-feature` for the UI-to-Rust contract and `$secure-tauri-capabilities` whenever the work adds file pickers, path access, plugins, Keychain access, or another OS permission boundary.

## Design Migrations and Recovery

- Assign every persisted format an explicit schema version from its first release.
- Run migrations before serving commands, in order, transactionally, and exactly once. Back up or snapshot valuable data before an irreversible migration.
- Test opening a fresh store and upgrading from every supported historical version. Do not silently discard unknown or malformed data.
- Define behavior for a locked, missing, read-only, partially written, or corrupt store. Prefer a recoverable error and a user-controlled restore/reset path over automatic deletion.
- Keep export formats versioned and portable. Create exports from a consistent snapshot; validate imports fully before replacing or merging live data.
- State whether import replaces, merges, deduplicates, or rejects conflicts, and make cancellation leave the original store intact.

## Verify the Lifecycle

- Unit-test schema creation, constraints, query ordering, pagination, transactions, and validation with isolated temporary storage.
- Test migration fixtures representing real previous versions, plus rollback behavior on a failed migration.
- Test unusual Unicode, large inputs, duplicate identifiers, interrupted writes, invalid imports, and search metacharacters.
- Confirm app relaunch persistence, first-run creation, backup/export readability, and useful error states in the packaged app.
- Update README documentation when storage location, retention, import/export behavior, or user-visible recovery changes.
- Finish with `$verify-tauri-change` at the depth appropriate to the implementation.
