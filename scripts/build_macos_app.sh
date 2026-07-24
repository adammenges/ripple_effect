#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
export LC_ALL=C
MACOS_TARGET="aarch64-apple-darwin"

if [[ "${OSTYPE:-}" != darwin* ]]; then
  echo "error: macOS app bundles must be built on macOS." >&2
  exit 1
fi

for command in cargo codesign lipo rustup xcode-select; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "error: $command is required." >&2
    exit 1
  fi
done

if ! xcode-select -p >/dev/null 2>&1; then
  echo "error: Xcode Command Line Tools are required. Run: xcode-select --install" >&2
  exit 1
fi

if ! cargo tauri --version >/dev/null 2>&1; then
  echo "error: Tauri CLI is required. Run: ./scripts/setup.sh" >&2
  exit 1
fi

if ! rustup target list --installed --toolchain 1.95.0 | grep -qx "$MACOS_TARGET"; then
  echo "error: $MACOS_TARGET is required. Run: ./scripts/setup.sh" >&2
  exit 1
fi

read_toml_string() {
  local key="$1"
  sed -nE "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"([^\"]+)\".*/\1/p" src-tauri/Cargo.toml | head -n 1
}

read_json_string() {
  local key="$1"
  sed -nE "s/^[[:space:]]*\"${key}\"[[:space:]]*:[[:space:]]*\"([^\"]+)\".*/\1/p" src-tauri/tauri.conf.json | head -n 1
}

DEFAULT_APP_NAME="$(read_json_string productName)"
DEFAULT_BUNDLE_ID="$(read_json_string identifier)"
DEFAULT_VERSION="$(read_toml_string version)"

if [[ -z "$DEFAULT_APP_NAME" || -z "$DEFAULT_BUNDLE_ID" || -z "$DEFAULT_VERSION" ]]; then
  echo "error: could not read app metadata from src-tauri configuration." >&2
  exit 1
fi

APP_NAME="${APP_NAME:-$DEFAULT_APP_NAME}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-$DEFAULT_BUNDLE_ID}"
APP_VERSION="${APP_VERSION:-$DEFAULT_VERSION}"
ICON_SOURCE="${ICON_SOURCE:-assets/icons/AppIcon-1024.png}"
DIST_DIR="${DIST_DIR:-dist}"
FORCE_ICONS="${FORCE_ICONS:-0}"

if [[ ! "$APP_NAME" =~ ^[[:alnum:]][[:alnum:]\ ._-]{0,62}[[:alnum:]]$ && ! "$APP_NAME" =~ ^[[:alnum:]]$ ]]; then
  echo "error: APP_NAME must start and end with a letter or number and may contain spaces, dots, hyphens, and underscores." >&2
  exit 1
fi

bundle_id_is_valid() {
  local identifier="$1"
  local component
  local -a components

  [[ "$identifier" =~ ^[[:alnum:]][[:alnum:].-]*[[:alnum:]]$ ]] || return 1
  IFS='.' read -r -a components <<< "$identifier"
  [[ ${#components[@]} -ge 2 && ${#identifier} -le 255 ]] || return 1
  for component in "${components[@]}"; do
    [[ "$component" =~ ^[[:alnum:]]([[:alnum:]-]*[[:alnum:]])?$ ]] || return 1
  done
}

if ! bundle_id_is_valid "$APP_BUNDLE_ID"; then
  echo "error: APP_BUNDLE_ID must be a reverse-DNS identifier such as com.example.my-app." >&2
  exit 1
fi

if [[ ! "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]; then
  echo "error: APP_VERSION must be a semantic version such as 1.2.3." >&2
  exit 1
fi

if [[ ! -f "$ICON_SOURCE" ]]; then
  if command -v swift >/dev/null 2>&1; then
    echo "Icon source missing; generating a default icon."
    swift scripts/generate_default_icon.swift "$ICON_SOURCE"
  elif [[ -f src-tauri/icons/icon.png ]]; then
    echo "Icon source missing; using the existing generated icon."
    mkdir -p "$(dirname -- "$ICON_SOURCE")"
    cp src-tauri/icons/icon.png "$ICON_SOURCE"
  else
    echo "error: no icon source or generated fallback is available." >&2
    exit 1
  fi
fi

if [[ "$FORCE_ICONS" == "1" || ! -f src-tauri/icons/icon.icns || "$ICON_SOURCE" -nt src-tauri/icons/icon.icns ]]; then
  echo "Generating platform icons from $ICON_SOURCE..."
  cargo tauri icon "$ICON_SOURCE"
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rust-tauri-build.XXXXXX")"
OVERRIDE_CONFIG="$TEMP_DIR/override.json"
trap 'rm -rf "$TEMP_DIR"' EXIT

printf '%s\n' \
  '{' \
  "  \"productName\": \"$APP_NAME\"," \
  "  \"version\": \"$APP_VERSION\"," \
  "  \"identifier\": \"$APP_BUNDLE_ID\"" \
  '}' > "$OVERRIDE_CONFIG"

build_args=(build --bundles app --ci --config "$OVERRIDE_CONFIG" --target "$MACOS_TARGET")
BUNDLE_DIR="target/$MACOS_TARGET/release/bundle/macos"

echo "Building $APP_NAME ($APP_BUNDLE_ID) v$APP_VERSION for Apple Silicon..."
cargo tauri "${build_args[@]}" -- --locked

APP_BUNDLE="$BUNDLE_DIR/$APP_NAME.app"
if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "error: build completed but $APP_BUNDLE was not found." >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
DESTINATION="$DIST_DIR/$APP_NAME.app"
rm -rf "$DESTINATION"
cp -R "$APP_BUNDLE" "$DESTINATION"

if ! codesign --verify --deep --strict "$DESTINATION" >/dev/null 2>&1; then
  echo "Applying an ad-hoc signature for local use..."
  codesign --force --deep --sign - "$DESTINATION"
fi

INFO_PLIST="$DESTINATION/Contents/Info.plist"
ACTUAL_BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "$INFO_PLIST")"
ACTUAL_VERSION="$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")"
ACTUAL_DISPLAY_NAME="$(plutil -extract CFBundleDisplayName raw "$INFO_PLIST")"
ACTUAL_EXECUTABLE="$(plutil -extract CFBundleExecutable raw "$INFO_PLIST")"
ACTUAL_ICON="$(plutil -extract CFBundleIconFile raw "$INFO_PLIST")"
EXECUTABLE_PATH="$DESTINATION/Contents/MacOS/$ACTUAL_EXECUTABLE"

if [[ "$ACTUAL_BUNDLE_ID" != "$APP_BUNDLE_ID" \
  || "$ACTUAL_VERSION" != "$APP_VERSION" \
  || "$ACTUAL_DISPLAY_NAME" != "$APP_NAME" \
  || ! -x "$EXECUTABLE_PATH" \
  || ! -f "$DESTINATION/Contents/Resources/$ACTUAL_ICON" ]]; then
  echo "error: bundle metadata verification failed." >&2
  exit 1
fi

ACTUAL_ARCHITECTURES="$(lipo -archs "$EXECUTABLE_PATH")"
if [[ "$ACTUAL_ARCHITECTURES" != "arm64" ]]; then
  echo "error: expected an ARM64-only executable; found: $ACTUAL_ARCHITECTURES" >&2
  exit 1
fi

codesign --verify --deep --strict "$DESTINATION"

echo "Built and verified ARM64 bundle: $DESTINATION"
