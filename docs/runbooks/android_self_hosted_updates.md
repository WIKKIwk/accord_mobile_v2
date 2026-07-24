# Self-hosted Android update release guide

This guide is for maintainers who distribute Accord Mobile as an APK from their
own `mini_rs_erp` server instead of Google Play.

The APK may be built on a developer or CI computer while the backend runs on a
different server. The finished APK is uploaded through SSH, published by the
backend release script, and then offered to every installed mobile client.

## Release architecture

```text
Developer or CI computer
  └─ builds signed accord.apk
       └─ SCP/SSH upload
            └─ mini_rs_erp release directory
                 ├─ android.json
                 └─ content-addressed APK files
                      └─ Accord Mobile downloads and verifies the APK
                           └─ Android system installer asks for approval
```

The mobile app:

- checks for updates shortly after startup;
- also exposes **Profile → Settings → App update**;
- downloads only the URL returned by the backend;
- verifies size and SHA-256;
- asks native Android code to verify package name, newer version code, and
  signing certificate;
- opens Android's system package installer.

## One-time project setup

### Choose a permanent application ID

Before distributing a fork, replace the sample application ID
`com.example.accord_mobile_v2` with a unique ID owned by your organization.
Once users install the app, changing this ID creates a different Android app
instead of updating the existing one.

### Configure a permanent signing key

The repository currently uses the Android debug signing configuration for
local release builds. Do not rely on an automatically generated debug key for
long-term public distribution.

Configure a stable release signing key before the first public install:

- keep the keystore outside the repository;
- load passwords through local or CI secrets;
- back up the keystore securely;
- use the same key for every future APK.

No paid certificate is required for self-hosted APK distribution. Android
identifies update compatibility by application ID and signing key.

If users already have an APK installed, the next APK must use that existing
app's signing key. Switching keys requires a one-time uninstall and fresh
install unless a supported Android signing-key rotation process was configured
in advance.

### Deploy the backend updater once

Deploy `mini_rs_erp` with its Android update routes and configure a persistent
release directory:

```env
MOBILE_APP_RELEASE_DIR=/var/lib/mini-rs-erp/mobile-releases
```

The server-side setup and operations are documented in:

```text
mini_rs_erp/docs/deploy/android-apk-updates.md
```

## Prepare a release

Increase both the user-visible version and Android build number in
`pubspec.yaml`:

```yaml
version: 0.2.1+6
```

Rules:

- `0.2.1` is the displayed `versionName`;
- `6` is the Android `versionCode`;
- every published release must have a higher `versionCode`;
- never reuse one version code for different public APK contents.

Add release notes describing user-visible changes.

## Build the APK

Build an arm64 release that points to the public backend:

```bash
make apk \
  API_URL=https://erp.example.com \
  APK_NAME=accord.apk
```

Result:

```text
build/app/outputs/flutter-apk/accord.apk
```

The build bootstrap stores Android SDK and Eclipse Temurin JDK 17 under the
workspace `.tools` directory when they are not already available. It does not
need a global Android Studio installation.

Before publishing, verify:

- application ID;
- `versionName` and `versionCode`;
- expected ABI, currently `arm64-v8a`;
- signing certificate SHA-256;
- embedded `MOBILE_API_BASE_URL`.

## Publish when backend and mobile are on the same computer

The local convenience target builds and publishes into the sibling backend:

```bash
make publish-apk-local \
  API_URL=https://erp.example.com \
  RELEASE_NOTES="Bug fixes and performance improvements"
```

By default it writes to:

```text
../mini_rs_erp/data/mobile_releases
```

Use this for local or single-machine deployments. For a production server,
prefer a persistent absolute release directory.

## Publish to a backend on another computer

Build locally, then upload the APK:

```bash
scp \
  build/app/outputs/flutter-apk/accord.apk \
  deploy@erp.example.com:/tmp/accord-0.2.1-6.apk
```

Publish it on the server:

```bash
ssh deploy@erp.example.com
cd /opt/mini_rs_erp

make publish-mobile-apk \
  APK=/tmp/accord-0.2.1-6.apk \
  VERSION_CODE=6 \
  VERSION_NAME=0.2.1 \
  MOBILE_RELEASE_DIR=/var/lib/mini-rs-erp/mobile-releases \
  RELEASE_NOTES="Bug fixes and performance improvements"
```

No backend restart is required after publishing a new APK.

### Optional update

The normal command creates an optional update. Users may choose **Later**.

### Require only very old clients

```bash
make publish-mobile-apk \
  APK=/tmp/accord-0.2.1-6.apk \
  VERSION_CODE=6 \
  VERSION_NAME=0.2.1 \
  MINIMUM_VERSION_CODE=5 \
  MOBILE_RELEASE_DIR=/var/lib/mini-rs-erp/mobile-releases
```

Only installed versions below code 5 are blocked until they update.

### Require every older client

```bash
make publish-mobile-apk \
  APK=/tmp/accord-0.2.1-6.apk \
  VERSION_CODE=6 \
  VERSION_NAME=0.2.1 \
  MANDATORY_UPDATE=1 \
  MOBILE_RELEASE_DIR=/var/lib/mini-rs-erp/mobile-releases
```

Use mandatory updates carefully. A server or download outage would prevent
affected users from continuing past the update dialog.

## Verify before announcing

Check the live manifest:

```bash
curl -fsS \
  https://erp.example.com/v1/mobile/app-update/android
```

Confirm that:

- `version_code` and `version_name` match `pubspec.yaml`;
- `mandatory` and `minimum_supported_version_code` are intentional;
- `size_bytes` matches the published APK;
- the returned `apk_url` downloads successfully;
- the downloaded APK SHA-256 matches `sha256`.

Perform an upgrade test on a device with the previous version installed:

1. Open Accord Mobile.
2. Wait for the automatic prompt, or open
   **Profile → Settings → App update**.
3. Tap **Update**.
4. On Android 8 or newer, allow Accord Mobile to install unknown apps when
   prompted, then tap **Update** again.
5. Approve the Android system installer.
6. Reopen the app and verify login and normal server communication.

## First release and existing users

Users whose installed APK predates the updater cannot receive an in-app prompt.
Distribute the first updater-enabled APK one final time through the old channel
or install it directly. In-app distribution works from that version onward.

The bridge APK must:

- keep the same application ID;
- use the same signing key as the old APK;
- have a higher `versionCode`;
- point to the backend where update routes are deployed.

## Failure guide

### Android says the app is not installed

Most often the new APK uses a different signing key, the same or lower version
code, or a different application ID.

### The update downloads but fails security verification

Compare the server manifest SHA-256 and size with the actual file. Confirm that
the uploaded APK was not replaced after publication.

### The update prompt never appears

Check:

```bash
curl -i https://erp.example.com/v1/mobile/app-update/android
```

- `204` means no release is published;
- `200` should contain a version code higher than the installed app;
- `503` means the server release manifest or referenced APK is invalid.

Also confirm that the installed app's `MOBILE_API_BASE_URL` points to this
server.

### Unknown-app permission opens instead of the installer

Enable **Install unknown apps** for Accord Mobile, return to the app, and tap
**Update** again. The already verified APK is reused from cache.

### A bad release was published

Do not attempt an Android downgrade. Fix or revert the code, assign a new higher
`versionCode`, and publish a hotfix.

## Public release checklist

- [ ] Unique, permanent application ID configured.
- [ ] Stable signing key configured and backed up.
- [ ] Backend updater deployed over HTTPS.
- [ ] Persistent release directory configured.
- [ ] `versionCode` increased.
- [ ] APK built against the correct public API URL.
- [ ] APK package, version, ABI, and certificate verified.
- [ ] Release uploaded through an authenticated channel.
- [ ] Live manifest and APK SHA-256 verified.
- [ ] Upgrade tested from the previous installed version.
- [ ] Release notes and mandatory-update policy reviewed.
