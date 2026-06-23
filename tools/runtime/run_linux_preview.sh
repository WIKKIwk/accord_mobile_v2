#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

FLUTTER_BIN="${FLUTTER_BIN:-$(command -v flutter 2>/dev/null || true)}"
if [ -z "$FLUTTER_BIN" ] && [ -x "$HOME/.local/flutter/bin/flutter" ]; then
	FLUTTER_BIN="$HOME/.local/flutter/bin/flutter"
fi
if [ -z "$FLUTTER_BIN" ]; then
	echo "flutter not found in PATH and ~/.local/flutter/bin/flutter is missing" >&2
	exit 1
fi

"$FLUTTER_BIN" pub get
API_URL="${MOBILE_API_BASE_URL:-https://mini-rs-erp-dev.wspace.sbs}"
"$FLUTTER_BIN" run -d linux --dart-define=MOBILE_API_BASE_URL="$API_URL"
