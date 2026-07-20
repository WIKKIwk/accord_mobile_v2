#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-build/ios/iphoneos/Runner.app}"
INFO_PLIST="$APP_PATH/Info.plist"
APP_BINARY="$APP_PATH/Runner"

if [ ! -f "$INFO_PLIST" ] || [ ! -x "$APP_BINARY" ]; then
	echo "iOS release artifact is incomplete: $APP_PATH" >&2
	exit 1
fi

microphone_usage="$(/usr/libexec/PlistBuddy -c 'Print :NSMicrophoneUsageDescription' "$INFO_PLIST" 2>/dev/null || true)"
if [ -z "${microphone_usage//[[:space:]]/}" ]; then
	echo "NSMicrophoneUsageDescription is missing from iOS release artifact" >&2
	exit 1
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/accord-ios-chat-runtime.XXXXXX")"
trap 'rm -rf -- "$work_dir"' EXIT
strings "$APP_BINARY" >"$work_dir/strings.txt"

for marker in RecordIosPlugin com.llfbandit.record/messages; do
	if ! grep -Fq "$marker" "$work_dir/strings.txt"; then
		echo "iOS release artifact is missing chat voice runtime marker: $marker" >&2
		exit 1
	fi
done

build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
echo "iOS chat runtime verified: build=$build_number app=$APP_PATH"
