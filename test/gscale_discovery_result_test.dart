import 'package:accord_mobile_v2/src/features/gscale/gscale_mobile_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'mergeDiscoveryResults keeps current servers when fast scan is empty',
    () {
      final current = DiscoveryResult(
        servers: [_server('192.168.1.4', 'rp-scale')],
        candidateCount: 1,
      );

      final merged = mergeDiscoveryResults(
        current: current,
        next: const DiscoveryResult(
          servers: <DiscoveredServer>[],
          candidateCount: 5,
        ),
        keepCurrentWhenNextEmpty: true,
      );

      expect(merged.servers, hasLength(1));
      expect(merged.servers.single.endpoint.host, '192.168.1.4');
    },
  );

  test('mergeDiscoveryResults replaces duplicate server with fresh result', () {
    final current = DiscoveryResult(
      servers: [_server('192.168.1.4', 'rp-scale', latencyMs: 90)],
      candidateCount: 1,
    );
    final next = DiscoveryResult(
      servers: [_server('gscale.local', 'rp-scale', latencyMs: 12)],
      candidateCount: 5,
    );

    final merged = mergeDiscoveryResults(
      current: current,
      next: next,
      keepCurrentWhenNextEmpty: true,
    );

    expect(merged.servers, hasLength(1));
    expect(merged.servers.single.endpoint.host, 'gscale.local');
    expect(merged.servers.single.latencyMs, 12);
  });

  test(
    'mergeDiscoveryResults shows verified scan before stale cached server',
    () {
      final current = DiscoveryResult(
        servers: [_server('192.168.1.4', 'cached-rps', latencyMs: 1)],
        candidateCount: 1,
      );
      final next = DiscoveryResult(
        servers: [_server('192.168.1.103', 'rp-scale', latencyMs: 12)],
        candidateCount: 5,
      );

      final merged = mergeDiscoveryResults(
        current: current,
        next: next,
        keepCurrentWhenNextEmpty: true,
      );

      expect(merged.servers, hasLength(2));
      expect(merged.servers.first.endpoint.host, '192.168.1.103');
      expect(merged.servers.last.endpoint.host, '192.168.1.4');
    },
  );

  test(
    'mergeDiscoveryResults can clear servers after confirmed empty scans',
    () {
      final current = DiscoveryResult(
        servers: [_server('192.168.1.4', 'rp-scale')],
        candidateCount: 1,
      );

      final merged = mergeDiscoveryResults(
        current: current,
        next: const DiscoveryResult(
          servers: <DiscoveredServer>[],
          candidateCount: 5,
        ),
        keepCurrentWhenNextEmpty: false,
      );

      expect(merged.servers, isEmpty);
    },
  );

  test('driverUrlForRs uses 5070 Tailscale address for RS print requests', () {
    final server = _server('192.168.1.114', '5070');

    expect(driverUrlForRs(server), 'http://100.117.62.18:39117');
  });

  test('driverUrlForRs keeps non-5070 endpoint unchanged', () {
    final server = _server('192.168.1.114', 'lab-scale');

    expect(driverUrlForRs(server), 'http://192.168.1.114:39117');
  });

  test('driverUrlForRs maps godex 2 LAN endpoint to Tailscale mini-pc', () {
    final server = _server('192.168.0.100', 'rp-scale-godex-2', port: 41257);

    expect(driverUrlForRs(server), 'http://100.117.62.18:41257');
  });

  test('printTargetLabel includes server ref and port', () {
    final server = _server('100.117.62.18', 'rp-scale-godex-2');

    expect(printTargetLabel(server), 'rp-scale-godex-2 @ 39117');
  });

  test('ServerHandshake keeps printer busy activity from driver', () {
    final handshake = ServerHandshake.fromJson(const {
      'server_name': 'rp-scale',
      'display_name': 'RP Scale',
      'role': 'operator',
      'server_ref': 'rps-1',
      'busy': true,
      'print_activity': {
        'busy': true,
        'status': 'printing',
        'label': 'Band',
        'detail': "Printer server boshqa mobile print so'rovi bilan band.",
        'item_code': 'ITEM-1',
        'item_name': 'Green Tea',
        'printer': 'godex',
      },
    });

    expect(handshake.isBusy, true);
    expect(handshake.printActivity.status, 'printing');
    expect(handshake.printActivity.itemCode, 'ITEM-1');
  });
}

DiscoveredServer _server(
  String host,
  String serverRef, {
  int latencyMs = 1,
  int port = 39117,
}) {
  return DiscoveredServer(
    endpoint: ServerEndpoint(
      host: host,
      port: port,
      baseUrl: 'http://$host:$port',
    ),
    handshake: ServerHandshake(
      serverName: 'gscale',
      displayName: 'RP Scale',
      role: 'operator',
      serverRef: serverRef,
    ),
    latencyMs: latencyMs,
  );
}
