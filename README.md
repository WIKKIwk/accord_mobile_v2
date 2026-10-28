# Accord Mobile V2

`accord_mobile_v2` is the Flutter application for the Accord Manufacturing
Execution System (MES). It gives production operators, material and warehouse
teams, suppliers, customers, and administrators access to their assigned
workflows. Production and inventory operations are provided by the
[Accord MES Backend](https://github.com/WIKKIwk/mini_rs_erp).

The application supports Android and iOS, with web preview tooling for development.

## Functional Scope

| Area | Capabilities |
| --- | --- |
| Production | Assigned equipment queues, work sessions, material and tooling scans, production metrics, and WIP QR tracking. |
| Materials | Raw material assignment, preparation, receipts, consumption, and roll splitting. |
| Tooling | Mold inventory, storage locations, checkout, return, and transfers. |
| Warehouse | WIP and pallet receiving, supplier receipts, stock lookup, customer dispatch, and delivery confirmation. |
| Administration | Production routes, orders, equipment, catalogs, user access, and system monitoring. |
| Communication | Internal messaging and push notifications. |

## Architecture

- `MobileApi` centralizes communication with the backend's `/v1/mobile/*` API.
- Backend roles and capabilities determine available workspaces and routes.
- The backend validates production actions, stock movements, and resource access.
- Local storage holds account sessions, device preferences, and application caches.
- Shared application services manage navigation, network availability, app lock,
  notifications, scanning, and Android updates.

The application supports saved accounts and server selection. A saved server
selection overrides the initial endpoint configured at build time. GScale/RPS
weighing and printing use a separate LAN connection.

Named multi-product calculations create a typed combo catalog entry after a
successful calculation and name confirmation. Existing combos can be reused
from the finished-product catalog. The combo reference and layout revision travel
with the order; its original component SKUs remain the cutting and warehouse
outputs. Mold assignments belong to the combo revision. A changed layout needs
a new revision and explicit tooling assignment; quantity-only calculations reuse
the existing revision. This requires a backend with migration
`0169_combo_catalog` and the combo catalog API.

## Development

Requirements:

- Flutter and Dart versions compatible with [pubspec.yaml](pubspec.yaml).
- A running Accord MES backend and a provisioned user account.
- Chromium or Chrome for web preview.

Run commands from the repository root. Replace the example URL with the deployment
endpoint:

```bash
make deps
make run API_URL=https://mes.example.com
```

`API_URL` is passed to Flutter as `MOBILE_API_BASE_URL`. This sets the initial
backend endpoint; the active saved server selection can be changed in the app.
The separate GScale/RPS endpoint is configured through `API_BASE_URL` or LAN
discovery and server selection.

For the default test server, `make run` starts a loopback WebSocket bridge as
well as the HTTP preview proxy. Both reach the running local Mini RS ERP at
`127.0.0.1:18081`; accounts retain their canonical HTTPS endpoint. The bridge is
limited to the fixed test backend and `/v1/mobile/` paths. Native and release
builds use direct WSS.

For a manually launched Flutter web server, start `dart tools/runtime/dev_ws_proxy.dart`
and pass both `--dart-define=ACCORD_DEV_API_PROXY=true` and
`--dart-define=ACCORD_DEV_WS_PROXY_URL=ws://127.0.0.1:39119`.

## Build and Distribution

Android builds require the Android SDK and JDK 17. The build helper provisions
workspace tools when needed.

```bash
make apk API_URL=https://mes.example.com
```

The arm64 APK is written to `build/app/outputs/flutter-apk/accord.apk`.
Configure the application identifier and release signing before distribution.
Updates must preserve the installed application's identifier and signing certificate.
Android update metadata and APK files are served by the backend.

For iOS, use macOS, Xcode, configured signing, and Swift Package Manager:

```bash
flutter build ios --release \
  --dart-define=MOBILE_API_BASE_URL=https://mes.example.com
```

Application version and build number are maintained in `pubspec.yaml`.

## Verification

```bash
make analyze
make test
```

The test suite covers API behavior, production workflows, access control,
navigation, and shared application components.

## Repository Structure

| Path | Responsibility |
| --- | --- |
| `lib/main.dart` | Application startup. |
| `lib/src/app/` | Application composition, routing, and route access checks. |
| `lib/src/core/` | API client, accounts, device services, and shared UI components. |
| `lib/src/features/` | Operational and administrative workspaces. |
| `android/`, `ios/` | Native platform integrations. |
| `test/` | Unit and widget tests. |
| `tools/` | Build and runtime helpers. |
| `third_party/` | Local dependency overrides. |
