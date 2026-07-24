#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)"
ICON_PATH="${1:-$ROOT_DIR/assets/icons/AppIcon-1024.png}"

if [[ ! -f "$ICON_PATH" ]]; then
  echo "error: icon source not found: $ICON_PATH" >&2
  exit 1
fi

if ! command -v sips >/dev/null 2>&1; then
  echo "error: sips is required to validate a macOS icon source." >&2
  exit 1
fi

width="$(sips -g pixelWidth "$ICON_PATH" | awk '/pixelWidth/ {print $2}')"
height="$(sips -g pixelHeight "$ICON_PATH" | awk '/pixelHeight/ {print $2}')"
format="$(sips -g format "$ICON_PATH" | awk '/format/ {print $2}')"
alpha="$(sips -g hasAlpha "$ICON_PATH" | awk '/hasAlpha/ {print $2}')"

if [[ "$width" != "1024" || "$height" != "1024" ]]; then
  echo "error: icon source must be exactly 1024 x 1024 px; found ${width:-unknown} x ${height:-unknown}." >&2
  exit 1
fi

if [[ "$format" != "png" ]]; then
  echo "error: icon source must be PNG; found ${format:-unknown}." >&2
  exit 1
fi

printf 'ok: %s is 1024 x 1024 PNG (alpha: %s)\n' "$ICON_PATH" "${alpha:-unknown}"
