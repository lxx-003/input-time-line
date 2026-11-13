#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
INSTALLED_APP="/Applications/InputTimeline.app"
DIST_APP="$PROJECT_DIR/dist/InputTimeline.app"

if [[ -d "$INSTALLED_APP" ]]; then
  open "$INSTALLED_APP"
  exit 0
fi

if [[ ! -d "$DIST_APP" ]]; then
  "$SCRIPT_DIR/build-app.sh" --no-open
fi

if [[ -d "$INSTALLED_APP" ]]; then
  open "$INSTALLED_APP"
else
  open "$DIST_APP"
fi
