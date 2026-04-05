#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
APP_DIR="$PROJECT_DIR/dist/InputTimeline.app"

if [[ ! -d "$APP_DIR" ]]; then
  "$SCRIPT_DIR/build-app.sh"
fi

open "$APP_DIR"
