#!/bin/sh
set -eu

# Both local builds and CI's IOS_GOOGLE_SERVICE_INFO_PLIST use this location.
firebase_source="${SRCROOT}/Runner/GoogleService-Info.plist"
firebase_destination="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"

if [ ! -f "$firebase_source" ]; then
  # Avoid retaining configuration from an earlier incremental build.
  rm -f "$firebase_destination"
  echo "Firebase client settings will be loaded from the Accord server."
  exit 0
fi

/usr/bin/plutil -lint "$firebase_source" >/dev/null
firebase_bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$firebase_source")
if [ "$firebase_bundle_id" != "$PRODUCT_BUNDLE_IDENTIFIER" ]; then
  echo "error: GoogleService-Info.plist BUNDLE_ID does not match this app."
  exit 1
fi
for firebase_field in GOOGLE_APP_ID GCM_SENDER_ID PROJECT_ID API_KEY; do
  firebase_value=$(/usr/libexec/PlistBuddy -c "Print :${firebase_field}" "$firebase_source")
  if [ -z "$firebase_value" ]; then
    echo "error: GoogleService-Info.plist is incomplete."
    exit 1
  fi
done

mkdir -p "$(dirname "$firebase_destination")"
cp "$firebase_source" "$firebase_destination"
