import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _station = 'apparatus:default:bosma_7';
Map<String, dynamic> _row(String id, int position,
        {String state = 'missing'}) =>
    {
      'id': id,
      'code': id,
      'order_number': '42',
      'title': 'Mahsulot 😀',
      'product_code': 'product',
      'customer_name': 'Mijoz',
      'image_id': 'image-1',
      'position': position,
      'apparatus_count': 2,
      'task_state': state,
    };
Map<String, dynamic> _wire({String kind = 'material', String search = ''}) => {
      'ok': true,
      'projection': 'supply_tasks_v1',
      'kind': kind,
      'epoch': 'server',
      'scope': 'scope',
      'rev': 7,
      'version': 'version-7',
      'apparatus_id': _station,
      'limit': 10,
      'search': search,
      'checked_count': 10,
      'missing_count': 2,
      'rows': [_row('first', 0), _row('third', 2, state: 'partial')],
      'apparatus': [
        {
          'apparatus_id': _station,
          'source_revision': 1,
          'source_aasx_sha256': '1' * 64,
          'display': {'display_name': 'Bosma 7'},
          'execution_profile': {
            'operation': 'print',
            'technology': 'flexographic'
          }
        }
      ],
    };
Map<String, dynamic> _delta() => {
      'ok': true,
      'type': 'tasks_delta',
      'epoch': 'server',
      'scope': 'scope',
      'base_rev': 7,
      'rev': 8,
      'version': 'version-8',
      'checked_count': 10,
      'missing_count': 2,
      'order_ids': ['second', 'third'],
      'upsert': [_row('second', 1), _row('third', 2)],
      'remove': ['first'],
    };
Map<String, dynamic> _ready() => {
      'ok': true,
      'type': 'tasks_ready',
      'epoch': 'server',
      'scope': 'scope',
      'rev': 7,
      'version': 'version-7',
      'resync': false,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpServer server;
  final sockets = <WebSocket>[];
  setUp(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({'test_mode_enabled': false});
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    await ServerEndpointStore.instance
        .setBaseUrl('http://127.0.0.1:${server.port}');
    AppSession.instance.token = 'supply-test-token';
  });
  tearDown(() async {
    for (final socket in sockets) {
      unawaited(socket.close());
    }
    sockets.clear();
    await server.close(force: true);
    await ServerEndpointStore.instance.clearOverride();
    AppSession.instance.token = null;
  });

  test('material and Qolip rows roundtrip without graph or action authority',
      () {
    for (final kind in supplyTaskKinds) {
      final window = SupplyTaskWindow.fromJson(_wire(kind: kind));
      expect(SupplyTaskWindow.fromJson(window.toJson()).rows.first.title,
          'Mahsulot 😀');
      expect(window.rows.first.position, 0);
      expect(window.missingCount, 2);
      final shell = window.rows.first.toPresentationOrder();
      expect(identical(shell, window.rows.first.toPresentationOrder()), isTrue);
      expect(isSupplyTaskPresentationOrder(shell), isTrue);
      expect(shell.map.nodes, isEmpty);
      expect(shell.program.operations, isEmpty);
      expect(() => window.rows.clear(), throwsUnsupportedError);
    }
  });

  test('malformed and incomplete windows never become empty ready lists', () {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (wire) => wire.remove('rows'),
      (wire) => wire.remove('apparatus'),
      (wire) => wire['checked_count'] = '10',
      (wire) => wire['missing_count'] = 11,
      (wire) => wire['projection'] = 'worker_list_v1',
      (wire) => wire['scope'] = '',
      (wire) => wire['rows'] = [],
      (wire) => wire['rows'] = [_row('same', 0), _row('same', 1)],
      (wire) => wire['rows'] = [_row('out-of-window', 10)],
      (wire) => wire['rows'] = [_row('bad-state', 0, state: 'ready')],
      (wire) => wire['rows'] = [_row('later', 2), _row('earlier', 0)],
      (wire) => wire['apparatus_id'] = 'apparatus:default:other',
    ]) {
      final wire = _wire();
      mutate(wire);
      expect(() => SupplyTaskWindow.fromJson(wire),
          throwsA(isA<MobileApiException>()));
    }
    final empty = _wire()
      ..addAll({
        'apparatus': [],
        'apparatus_id': '',
        'checked_count': 0,
        'missing_count': 0,
        'rows': []
      });
    expect(SupplyTaskWindow.fromJson(empty).rows, isEmpty);
  });

  test('verified mixed delta applies atomically and preserves baseline', () {
    final baseline = SupplyTaskWindow.fromJson(_wire());
    final next = SupplyTaskMessage.fromJson(_delta()).applyTo(baseline);
    expect(next.rows.map((row) => row.id), ['second', 'third']);
    expect(next.rows.last.taskState, 'missing');
    expect(next.revision, 8);
    expect(baseline.rows.map((row) => row.id), ['first', 'third']);
    expect(baseline.revision, 7);
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (wire) => wire['base_rev'] = 6,
      (wire) => wire['epoch'] = 'old-server',
      (wire) => wire['scope'] = 'other-account',
      (wire) => wire['remove'] = [],
      (wire) => wire['upsert'] = [],
      (wire) => wire['order_ids'] = ['second', 'second'],
      (wire) => wire['upsert'] = [_row('second', 12)],
    ]) {
      final wire = _delta();
      mutate(wire);
      expect(() => SupplyTaskMessage.fromJson(wire).applyTo(baseline),
          throwsA(isA<MobileApiException>()));
      expect(baseline.rows.first.id, 'first');
    }
  });

  test('checkpoint delta advances only cursor; ready must match exact baseline',
      () {
    final baseline = SupplyTaskWindow.fromJson(_wire());
    expect(
        identical(
            SupplyTaskMessage.fromJson(_ready()).applyTo(baseline), baseline),
        isTrue);
    for (final key in ['scope', 'epoch', 'version', 'rev', 'resync']) {
      final raw = _ready();
      raw[key] = key == 'rev'
          ? 8
          : key == 'resync'
              ? true
              : 'wrong';
      expect(() => SupplyTaskMessage.fromJson(raw).applyTo(baseline),
          throwsA(isA<MobileApiException>()));
    }
    final checkpoint = _delta()
      ..addAll({
        'order_ids': ['first', 'third'],
        'upsert': [],
        'remove': [],
        'missing_count': 2
      });
    expect(
        SupplyTaskMessage.fromJson(checkpoint).applyTo(baseline).revision, 8);
  });

  test('snapshot allows normalized picker but rejects another requested window',
      () {
    final baseline = SupplyTaskWindow.fromJson(_wire());
    final raw = _wire()..addAll({'rev': 9, 'scope': 'new-scope'});
    expect(
        SupplyTaskSnapshot(SupplyTaskWindow.fromJson(raw))
            .applyTo(baseline)
            .scope,
        'new-scope');
    expect(
        () =>
            SupplyTaskSnapshot(SupplyTaskWindow.fromJson(_wire(kind: 'qolip')))
                .applyTo(baseline),
        throwsA(isA<MobileApiException>()));
  });

  test('HTTP deduplicates in-flight selected-window reads, then reads afresh',
      () async {
    final gate = Completer<void>();
    var requests = 0;
    server.listen((request) async {
      requests++;
      expect(request.uri.path, '/v1/mobile/production-tasks/window');
      expect(
          request.headers.value('authorization'), 'Bearer supply-test-token');
      expect(request.uri.queryParameters, {
        'kind': 'material',
        'apparatus': '',
        'limit': '10',
        'search': 'hello'
      });
      await gate.future;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_wire(search: 'hello')));
      await request.response.close();
    });
    final first = MobileApi.instance
        .supplyTaskWindow(kind: 'material', search: ' hello ');
    final second =
        MobileApi.instance.supplyTaskWindow(kind: 'material', search: 'hello');
    expect(identical(first, second), isTrue);
    gate.complete();
    await Future.wait([first, second]);
    expect(requests, 1);
    await MobileApi.instance
        .supplyTaskWindow(kind: 'material', search: 'hello');
    expect(requests, 2);
  });

  test('real socket sends scoped cursor and decodes ready/delta/snapshot',
      () async {
    server.listen((request) async {
      expect(request.uri.path, '/v1/mobile/production-tasks/live');
      expect(request.uri.queryParameters, {
        'kind': 'material',
        'apparatus': _station,
        'limit': '10',
        'search': '',
        'token': 'supply-test-token',
        'epoch': 'server',
        'rev': '7',
        'scope': 'scope'
      });
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {});
      for (final wire in [
        _ready(),
        _delta(),
        {'ok': true, 'type': 'tasks_snapshot', 'window': _wire()..['rev'] = 9}
      ]) {
        socket.add(jsonEncode(wire));
      }
    });
    final baseline = SupplyTaskWindow.fromJson(_wire());
    final events = await MobileApi.instance
        .supplyTaskLive(baseline)
        .take(3)
        .toList()
        .timeout(const Duration(seconds: 5));
    var latest = baseline;
    for (final message in events) {
      latest = message.applyTo(latest);
    }
    expect(latest.revision, 9);
  });

  test('socket refuses unknown or incomplete payload instead of empty state',
      () async {
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {});
      socket.add(jsonEncode({'ok': true, 'type': 'tasks_snapshot'}));
    });
    await expectLater(
        MobileApi.instance.supplyTaskLive(SupplyTaskWindow.fromJson(_wire())),
        emitsError(isA<MobileApiException>()));
  });
}
