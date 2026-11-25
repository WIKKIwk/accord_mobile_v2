# Source with the absolute Accord workspace directory as the argument.
export LOCAL_TOOLS_ROOT="${1:?Accord workspace required}/.tools"
accord_flutter_sdk="$LOCAL_TOOLS_ROOT/flutter-sdk/current"
if [[ ! -x "$accord_flutter_sdk/bin/flutter" ]]; then
  accord_flutter_sdk="$LOCAL_TOOLS_ROOT/flutter-sdk/flutter"
fi
export FLUTTER_ROOT="${accord_flutter_sdk:A}"
unset accord_flutter_sdk
export FLUTTER_BIN="$FLUTTER_ROOT/bin/flutter"
export PUB_CACHE="$LOCAL_TOOLS_ROOT/pub-cache"
export ANDROID_HOME="$LOCAL_TOOLS_ROOT/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME="$LOCAL_TOOLS_ROOT/jdk-17/Contents/Home"
export GRADLE_USER_HOME="$LOCAL_TOOLS_ROOT/gradle-home"
export CARGO_HOME="$LOCAL_TOOLS_ROOT/rust/cargo"
export RUSTUP_HOME="$LOCAL_TOOLS_ROOT/rust/rustup"
export TMPDIR="$LOCAL_TOOLS_ROOT/flutter-tmp"
# The macOS JDK selects its own temporary directory independently of TMPDIR.
if [[ ${JAVA_TOOL_OPTIONS:-} != *-Djava.io.tmpdir=* ]]; then
  export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-Djava.io.tmpdir=\"$TMPDIR\""
fi

# zsh keeps PATH in sync with this array. Drop duplicate entries on reactivation.
typeset -gU path
path=(
  "$1/accord_mobile_v2/tools/workspace/bin" "$FLUTTER_ROOT/bin" "$CARGO_HOME/bin"
  "$JAVA_HOME/bin" "$ANDROID_HOME/platform-tools" "$ANDROID_HOME/cmdline-tools/latest/bin"
  "$LOCAL_TOOLS_ROOT/postgres/current/bin" "${path[@]}"
)
