#!/usr/bin/env bash

if ! command -v rustup >/dev/null 2>&1; then
  echo "error: rustup is required. Run: ./scripts/setup.sh" >&2
  return 1 2>/dev/null || exit 1
fi

RIPPLE_RUST_BIN="$(dirname -- "$(rustup which --toolchain 1.95.0 rustc)")"
export PATH="$RIPPLE_RUST_BIN:$PATH"
unset RIPPLE_RUST_BIN
