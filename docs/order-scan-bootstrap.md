# Order detail scan bootstrap

Worker order details can load a fresh scoped control plus the required raw
material and Qolip scan data in one request:

`GET /v1/mobile/admin/production-maps/order-scan-bootstrap`

The optimization is enabled only for a worker scan-required detail route with a
canonical live-snapshot callback. Training, freeze/pause-on-open and other detail
entry points retain their existing readers. No warehouse catalog, history,
photo, WIP lookup, opening-WIP or mutation payload is added to the aggregate.

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
