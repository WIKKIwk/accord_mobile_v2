import 'package:accord_mobile_v2/src/features/gscale/gscale_mobile_app.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const usbPrinterChannel = MethodChannel('accord/usb_printer');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(usbPrinterChannel, (call) async {
      if (call.method == 'detectPrinter') {
        return <String, Object?>{
          'ok': true,
          'printer': 'godex',
          'deviceName': '/dev/mock-usb-printer',
          'vendorId': 0x195f,
          'productId': 0x0001,
          'manufacturerName': 'GoDEX',
          'productName': 'G500',
        };
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(usbPrinterChannel, null);
  });

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

  test('MonitorSnapshot shows connected printer label from RPS state', () {
    final snapshot = MonitorSnapshot.fromJson(const {
      'ok': true,
      'state': {
        'scale': {'unit': 'kg'},
        'printer': {
          'connected': true,
          'kind': 'godex',
          'label': 'ulangan',
        },
      },
    });

    expect(snapshot.printerLabel, 'ulangan');
    expect(snapshot.printerKind, 'godex');
  });

  test('MonitorSnapshot keeps connected status when printer label is empty',
      () {
    final snapshot = MonitorSnapshot.fromJson(const {
      'ok': true,
      'state': {
        'printer': {
          'connected': true,
          'kind': 'godex',
          'label': '',
        },
      },
    });

    expect(snapshot.printerLabel, 'ulangan');
    expect(snapshot.printerKind, 'godex');
  });

  test('MonitorSnapshot reads top-level printer status fallback', () {
    final snapshot = MonitorSnapshot.fromJson(const {
      'ok': true,
      'state': {},
      'printer': {
        'connected': 'true',
        'kind': 'godex',
        'label': 'ulanmagan',
      },
    });

    expect(snapshot.printerLabel, 'ulangan');
    expect(snapshot.printerKind, 'godex');
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

  test('empty picker copy keeps user in printer and scale selection flow', () {
    const copy = GScalePickerEmptyCopy.noDevices();

    expect(copy.title, isNot('Server topilmadi'));
    expect(copy.title, contains('Qurilma'));
    expect(copy.message, 'Service tarmoqda topilmadi.');
    expect(copy.primaryActionLabel, 'Qayta qidirish');
    expect(copy.secondaryActionLabel, 'Manzil qo‘shish');
  });

  testWidgets('GScale mode opens dashboard shell before server is selected', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(GScaleMobileApp(onExitMode: () async {}));
    await tester.pump();

    expect(find.text('Boshqaruv'), findsOneWidget);
    expect(find.text('Arxiv'), findsOneWidget);
    expect(find.text('Server'), findsOneWidget);
    expect(find.text('Printer yoki tarozi tanlanmagan'), findsOneWidget);
    expect(find.text('Qurilma tanlash'), findsOneWidget);
    expect(find.text('Mahsulot tanlang'), findsOneWidget);
    expect(find.text('Babina'), findsOneWidget);
    expect(find.text('Joriy kg'), findsNothing);
    expect(find.text('Scale: ulanmagan'), findsNothing);
    expect(
      find.text('Scale ulangan va kg kelganda tugma aktiv bo‘ladi.'),
      findsNothing,
    );
  });

  testWidgets('device picker exposes Offline USB and existing WiFi tabs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(GScaleMobileApp(onExitMode: () async {}));
    await tester.pump();
    await tester.tap(find.text('Qurilma tanlash'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('WiFi'), findsOneWidget);
    expect(find.text('Offline rejimni tanlash'), findsOneWidget);

    await tester.tap(find.text('Offline rejimni tanlash'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('GoDEX • G500'), findsOneWidget);
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
