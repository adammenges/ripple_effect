#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

status=0

check_command() {
  local command="$1"
  if command -v "$command" >/dev/null 2>&1; then
    printf 'ok    %-14s %s\n' "$command" "$(command -v "$command")"
  else
    printf 'miss  %-14s required\n' "$command"
    status=1
  fi
}

check_command cargo
check_command rustc
check_command rustup

if [[ "${OSTYPE:-}" == darwin* ]]; then
  check_command xcode-select
  if xcode-select -p >/dev/null 2>&1; then
    printf 'ok    %-14s %s\n' "xcode tools" "$(xcode-select -p)"
  else
    printf 'miss  %-14s run: xcode-select --install\n' "xcode tools"
    status=1
  fi

  if rustup target list --installed --toolchain 1.95.0 | grep -qx 'aarch64-apple-darwin'; then
    printf 'ok    %-14s %s\n' "macOS target" "aarch64-apple-darwin"
  else
    printf 'miss  %-14s run: ./scripts/setup.sh\n' "macOS target"
    status=1
  fi
fi

if cargo tauri --version >/dev/null 2>&1; then
  printf 'ok    %-14s %s\n' "tauri" "$(cargo tauri --version)"
else
  printf 'miss  %-14s run: ./scripts/setup.sh\n' "tauri"
  status=1
fi

if cargo metadata --locked --no-deps --format-version 1 >/dev/null 2>&1; then
  printf 'ok    %-14s valid and locked\n' "workspace"
else
  printf 'fail  %-14s metadata or Cargo.lock is stale\n' "workspace"
  status=1
fi

exit "$status"
