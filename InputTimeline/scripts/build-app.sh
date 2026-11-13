#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"

APP_NAME="InputTimeline"
PRODUCT_NAME="$APP_NAME.app"
configuration="${CONFIGURATION:-release}"
signing_identity="${INPUT_TIMELINE_CODESIGN_IDENTITY:-}"
open_app=1
install_to_applications=1

usage() {
  cat <<'EOF'
Usage: ./scripts/build-app.sh [options]

Options:
  --debug                 Build the debug configuration.
  --release               Build the release configuration (default).
  --install               Sync built .app to /Applications (default).
  --no-install            Keep build only under dist/ without syncing /Applications.
  --open                  Restart and launch the built .app after building (default).
  --no-open               Build without launching the app.
  --sign <identity>       Sign with a specific code-signing identity.
  --adhoc                 Force ad-hoc signing (TCC permissions may reset).
  -h, --help              Show this help.

CONFIGURATION (debug/release) and INPUT_TIMELINE_CODESIGN_IDENTITY are also
supported. When signing identity is omitted, the script automatically selects
an Apple Development identity, then a Developer ID Application identity, and
only falls back to ad-hoc signing (-) if none is installed.
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --debug)
      configuration=debug
      shift
      ;;
    --release)
      configuration=release
      shift
      ;;
    --install)
      install_to_applications=1
      shift
      ;;
    --no-install)
      install_to_applications=0
      shift
      ;;
    --open)
      open_app=1
      shift
      ;;
    --no-open)
      open_app=0
      shift
      ;;
    --sign)
      if (( $# < 2 )); then
        echo "Error: --sign requires an identity." >&2
        exit 2
      fi
      signing_identity="$2"
      shift 2
      ;;
    --adhoc)
      signing_identity="-"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

find_signing_identity() {
  local identities candidate
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"

  candidate="$(
    print -r -- "$identities" |
      awk '/"Apple Development:/ { print $2; exit }'
  )"
  if [[ -z "$candidate" ]]; then
    candidate="$(
      print -r -- "$identities" |
        awk '/"Developer ID Application:/ { print $2; exit }'
    )"
  fi

  print -r -- "$candidate"
}

if [[ -z "$signing_identity" ]]; then
  signing_identity="$(find_signing_identity)"
fi

if [[ -z "$signing_identity" ]]; then
  cat >&2 <<'EOF'
Warning: no stable macOS code-signing identity (Apple Development / Developer ID)
was found; falling back to ad-hoc signing (-).

Ad-hoc builds tie macOS Input Monitoring TCC permissions to the changing
binary hash, so macOS will require re-authorizing after rebuilds. To preserve
permissions across rebuilds, create an Apple Development certificate once:

  Xcode > Settings > Accounts > select your Apple ID
        > Manage Certificates > + > Apple Development
EOF
  signing_identity="-"
elif [[ "$signing_identity" == "-" ]]; then
  cat >&2 <<'EOF'
Warning: using ad-hoc signing (-). macOS Input Monitoring TCC permissions
may reset after rebuilds because the designated requirement uses a code hash.
EOF
fi

echo "Building $APP_NAME ($configuration)..."
swift build --package-path "$PROJECT_DIR" -c "$configuration"
binary="$(swift build --package-path "$PROJECT_DIR" -c "$configuration" --show-bin-path)/$APP_NAME"
if [[ ! -x "$binary" ]]; then
  echo "Error: build product not found: $binary" >&2
  exit 1
fi

PRODUCT_DIR="$PROJECT_DIR/dist"
APP_DIR="$PRODUCT_DIR/$PRODUCT_NAME"
mkdir -p "$PRODUCT_DIR"
stage="$(mktemp -d "$PRODUCT_DIR/.build-app.XXXXXX")"
trap 'rm -rf "$stage"' EXIT INT TERM

bundle="$stage/$PRODUCT_NAME"
MACOS_DIR="$bundle/Contents/MacOS"
RESOURCES_DIR="$bundle/Contents/Resources"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$PROJECT_DIR/Support/Info.plist" "$bundle/Contents/Info.plist"
cp "$PROJECT_DIR/Support/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$binary" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

bundle_identifier="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PROJECT_DIR/Support/Info.plist"
)"

echo "Signing: $signing_identity"
codesign \
  --force \
  --sign "$signing_identity" \
  --identifier "$bundle_identifier" \
  --timestamp=none \
  "$bundle"
codesign --verify --deep --strict --verbose=2 "$bundle"

rm -rf "$APP_DIR"
mv "$bundle" "$APP_DIR"

echo "Built app bundle at:"
echo "  $APP_DIR"
codesign -dr - "$APP_DIR" 2>&1 | sed -n '/designated =>/p'

stop_running_app() {
  pkill -x "$APP_NAME" 2>/dev/null || true
  for _ in {1..50}; do
    if ! pgrep -x "$APP_NAME" >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done

  if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    echo "Error: the previous $APP_NAME process did not exit." >&2
    exit 1
  fi
}

launch_target="$APP_DIR"

if (( install_to_applications )); then
  INSTALLED_APP="/Applications/$PRODUCT_NAME"
  if [[ -w /Applications ]]; then
    stop_running_app
    rm -rf "$INSTALLED_APP"
    ditto "$APP_DIR" "$INSTALLED_APP"
    codesign --verify --deep --strict "$INSTALLED_APP"
    launch_target="$INSTALLED_APP"
    echo "Installed app bundle at:"
    echo "  $INSTALLED_APP"
  else
    echo "Warning: /Applications is not writable; skipping install." >&2
  fi
fi

if (( open_app )); then
  stop_running_app
  open -n "$launch_target"
fi
