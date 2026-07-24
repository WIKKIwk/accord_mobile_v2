#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKSPACE_ROOT="$(cd "$REPO_ROOT/.." && pwd)"
LOCAL_TOOLS_ROOT="${LOCAL_TOOLS_ROOT:-$WORKSPACE_ROOT/.tools}"
HOST_OS="$(uname -s)"
HOST_ARCH="$(uname -m)"
if [ "$HOST_OS" = "Darwin" ]; then
	SDK_ROOT="${ANDROID_HOME:-$LOCAL_TOOLS_ROOT/android-sdk}"
	JDK_ROOT="${JDK_HOME:-$LOCAL_TOOLS_ROOT/jdk-17/Contents/Home}"
	JDK_INSTALL_ROOT="${JDK_ROOT%/Contents/Home}"
	CMDLINE_PLATFORM="mac"
else
	SDK_ROOT="${ANDROID_HOME:-$LOCAL_TOOLS_ROOT/android-sdk}"
	JDK_ROOT="${JDK_HOME:-$LOCAL_TOOLS_ROOT/jdk-17}"
	JDK_INSTALL_ROOT="$JDK_ROOT"
	CMDLINE_PLATFORM="linux"
fi
case "$HOST_ARCH" in
	arm64|aarch64) JDK_ARCH="aarch64" ;;
	x86_64|amd64) JDK_ARCH="x64" ;;
	*)
		echo "Unsupported CPU architecture for Android JDK bootstrap: $HOST_ARCH" >&2
		exit 1
		;;
esac
CMDLINE_VERSION="${ANDROID_CMDLINE_VERSION:-13114758}"
ZIP_URL="https://dl.google.com/android/repository/commandlinetools-${CMDLINE_PLATFORM}-${CMDLINE_VERSION}_latest.zip"
TMP_DIR="$(mktemp -d)"
ZIP_PATH="$TMP_DIR/cmdline-tools.zip"
JDK_ARCHIVE="$TMP_DIR/temurin-jdk17.tar.gz"
JDK_URL="https://api.adoptium.net/v3/binary/latest/17/ga/${CMDLINE_PLATFORM}/${JDK_ARCH}/jdk/hotspot/normal/eclipse"

cleanup() {
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ ! -x "$JDK_ROOT/bin/java" ]; then
	echo "Downloading workspace-local Eclipse Temurin JDK 17..."
	curl --fail --location "$JDK_URL" --output "$JDK_ARCHIVE"
	mkdir -p "$TMP_DIR/jdk"
	tar -xzf "$JDK_ARCHIVE" -C "$TMP_DIR/jdk"
	JDK_EXTRACTED="$(find "$TMP_DIR/jdk" -mindepth 1 -maxdepth 1 -type d -print -quit)"
	if [ -z "$JDK_EXTRACTED" ]; then
		echo "Downloaded JDK archive is empty" >&2
		exit 1
	fi
	rm -rf "$JDK_INSTALL_ROOT"
	mkdir -p "$(dirname "$JDK_INSTALL_ROOT")"
	mv "$JDK_EXTRACTED" "$JDK_INSTALL_ROOT"
fi

if [ ! -x "$JDK_ROOT/bin/java" ]; then
	echo "JDK 17 is unavailable at $JDK_ROOT" >&2
	exit 1
fi

mkdir -p "$SDK_ROOT/cmdline-tools"

if [ ! -x "$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]; then
	echo "Downloading Android command line tools..."
	curl -L "$ZIP_URL" -o "$ZIP_PATH"
	rm -rf "$SDK_ROOT/cmdline-tools/latest"
	mkdir -p "$SDK_ROOT/cmdline-tools/latest"
	unzip -q "$ZIP_PATH" -d "$TMP_DIR/unpacked"
	cp -R "$TMP_DIR/unpacked/cmdline-tools/." "$SDK_ROOT/cmdline-tools/latest/"
fi

export ANDROID_HOME="$SDK_ROOT"
export ANDROID_SDK_ROOT="$SDK_ROOT"
export JAVA_HOME="$JDK_ROOT"
export PATH="$JDK_ROOT/bin:$PATH"
export PATH="$SDK_ROOT/cmdline-tools/latest/bin:$SDK_ROOT/platform-tools:$PATH"

run_sdkmanager() {
	"$JDK_ROOT/bin/java" \
		"-Dcom.android.sdklib.toolsdir=$SDK_ROOT/cmdline-tools/latest" \
		-classpath "$SDK_ROOT/cmdline-tools/latest/lib/sdkmanager-classpath.jar" \
		com.android.sdklib.tool.sdkmanager.SdkManagerCli \
		"$@"
}

set +o pipefail
yes | run_sdkmanager --licenses >/dev/null || true
set -o pipefail
run_sdkmanager \
	"platform-tools" \
	"platforms;android-36" \
	"platforms;android-35" \
	"build-tools;35.0.0" \
	"build-tools;28.0.3" >/dev/null

FLUTTER_BIN="${FLUTTER_BIN:-$(command -v flutter 2>/dev/null || true)}"
if [ -z "$FLUTTER_BIN" ] && [ -x "$HOME/.local/flutter/bin/flutter" ]; then
	FLUTTER_BIN="$HOME/.local/flutter/bin/flutter"
fi
if [ -z "$FLUTTER_BIN" ]; then
	echo "flutter not found in PATH and ~/.local/flutter/bin/flutter is missing" >&2
	exit 1
fi
FLUTTER_ROOT="$(cd "$(dirname "$FLUTTER_BIN")/.." && pwd)"

printf 'sdk.dir=%s\nflutter.sdk=%s\n' "$SDK_ROOT" "$FLUTTER_ROOT" \
	>"$REPO_ROOT/android/local.properties"

trap - EXIT
cleanup
echo "Android SDK ready at $SDK_ROOT"
echo "JDK 17 ready at $JDK_ROOT"
