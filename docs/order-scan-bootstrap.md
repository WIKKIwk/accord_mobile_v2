# Order detail scan bootstrap

Worker order details can load a fresh scoped control plus the required raw
material and Qolip scan data in one request:

`GET /v1/mobile/admin/production-maps/order-scan-bootstrap`

The optimization is enabled only for a worker scan-required detail route with a
canonical live-snapshot callback. Training, freeze/pause-on-open and other detail
entry points retain their existing readers. No warehouse catalog, history,
photo, opening-WIP or mutation payload is added to the ordinary detail aggregate.
The FAB preparation described below additionally supports scoped WIP proof and
bounded input candidates.

## Request path

For a printing detail that requires both sections:

- Before: one scoped sequence GET, then raw requirements GET and empty-code
  Qolip requirements POST in parallel (three requests, two network stages)
- With complete aggregate support: one bootstrap GET (one network stage)
- Old backend: an empty-body route 404/405 permits one unsupported-route probe
  followed by the existing three requests; deploy the additive backend endpoint
  before shipping this client to realize the request reduction
- A missing, failed or malformed section invokes only its existing independent
  reader. A ready section is reused only after structural completeness checks
- Top-level domain 404, authorization failures, conflicts and server failures do
  not fan out through legacy readers

## Safety boundaries

The response's production `epoch` and `rev` describe the control snapshot, not a
transactionally atomic raw-stock/Qolip snapshot. Requirements are short-lived
sheet data and are never cached against that revision. Existing Start commands
continue sending selected resources and performing the authoritative server
validation and transaction checks.

The endpoint's `scope` is separate from the whole-worker live/delta scope. The
aggregate cannot be used as a global snapshot or advance a global cursor. The
parent's canonical live snapshot is read only to reject delayed response and
section acceptance, including an initial QR continuation. A later unrelated
live revision does not disable an already settled detail or add a request.

Route, account/authorization/server scope, load generation and action generation
protect asynchronous reads. An ordinary token refresh for the same account and
permissions does not discard valid work. Scope changes invalidate pending reads
and old scanner/action callbacks. Missing or failed sections retain retry/error
behavior; no failed or uncertain write is automatically replayed.

## Focused checks

```sh
flutter test test/order_scan_bootstrap_api_test.dart
flutter test test/admin_production_map_test_screen_test.dart --plain-name 'scan bootstrap'
```

The API suite contains a deterministic fake-network comparison using a 250 ms
response delay on each request. It exercises the real API methods and measures
request count/serialized fixture bodies. These timings and bodies are synthetic
fixtures, not production latency, CPU, RAM or PostgreSQL measurements.

## Measured fixtures

The backend production-library HTTP fixture, using the exact original mobile
query, measured both cold and warm cache cases:

- Old: sequence GET 1,488 bytes + raw requirements GET 371 bytes + Qolip
  requirements POST 204 bytes = 2,063 response-body bytes in three requests
- New: 1,588 response-body bytes in one request (475 bytes / 23.0% less)

The independent mobile fixture includes one assigned roll and one required
mold. Its real API methods measured 1,910 → 1,674 JSON body bytes and three → one
requests. With a deterministic 250 ms response delay per request, its old
serial-then-parallel path completes after 500 ms and the aggregate after 250 ms.
This isolates network-stage savings; it excludes server processing, transfer
bandwidth, HTTP headers, TLS and compression. It is not a production benchmark.

## FAB scan preparation

A production worker FAB scan can request `include_context=true` and the exact
`qr_payload` after identifying the roll's order and assigned consumer apparatus.
The existing endpoint adds optional fields:

- `queue_context`: a sheet-local sequence snapshot at the control's epoch and
  revision. It carries the target and active jobs' maps/contracts, plus station
  occupancy and queue policy. It never replaces the filtered list/delta cursor.
- `validated_progress`: the existing scoped, active-order progress-QR lookup
  response, using the same capability, assignment, order and WIP route checks.
- With `include_context=true` and `include_sections=true`,
  `sections.material_assignments` carries the existing order/apparatus assignment
  reader when raw-material scans are not required. `sections.input_progress`
  carries the existing waiting-WIP reader for the exact order, limited to 500,
  when previous-stage WIP scans are required. Both include apparatus, order and
  stage identity; the client validates these before reusing the lists. Invalid,
  failed or missing sections use only their existing independent readers.

The WIP list retains the existing stage/alternative-route filter. Its 500-row
window is not complete history: the exact scanned WIP proof can still supply a
batch outside that window. The backend reads sections in parallel, rechecks
authorization and retries a changed production revision before responding.
Decoded queue context is reused directly without a JSON encode/decode round trip.

The client passes this response once into the detail sheet. Required resource
sections retain their independent fallback readers; material and mold scans are
never marked complete by the progress proof. Start remains an explicit command
with all server-side transactional validation. A newer live revision during
section reads requires one fresh QR proof; an uncertain/stale proof is rejected.

The FAB no longer waits for whole-page catalog/history refreshes. In the focused
modern-backend fixture the ordinary waiting-input route uses two data requests
(one identification and one aggregate), down from four requests in three network
stages to two requests in two stages. This excludes at most one existing
asynchronous image request and the existing material-link-request panel read on
cards requiring material scans. The complete-sections fixture
also verifies that outstanding mold scans still disable Start. Request counts
are fixture measurements, not a production latency benchmark.

Old servers may omit the new fields or return the established empty 404/405.
Those clients retain scoped control reads and exact QR validation. Domain errors
and malformed supplied context/proofs never fall back to broader reads.
Opening WIP and training retain their existing validation paths.
