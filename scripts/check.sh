#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Checking shell syntax"
for script in scripts/*.sh; do
  bash -n "$script"
done

if command -v node >/dev/null 2>&1; then
  echo "==> Checking JavaScript syntax"
  node --check ui/main.js
fi

echo "==> Checking Rust formatting"
cargo fmt --all -- --check

echo "==> Running Clippy"
cargo clippy --workspace --all-targets --all-features --locked -- -D warnings

echo "==> Running tests"
cargo test --workspace --all-features --locked
