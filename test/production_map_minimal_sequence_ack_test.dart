import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/realtime/sequence_delta.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const apparatus = 'apparatus:default:bosma_8';
const before = ['a', 'hidden', 'b', 'c'];
const after = ['c', 'a', 'hidden', 'b'];
final oldVersion = '0' * 64;
final newVersion = '1' * 64;

Map<String, Object?> reply({List<String> ids = after, bool adjusted = false}) =>
    {
      'ok': true,
      'base_version': oldVersion,
      'version': newVersion,
      'adjusted': adjusted,
      'revision': 9,
      'epoch': 'server',
      'order_count': ids.length,
      'order_hash': sequenceFingerprint(ids),
      'ops': [
        {
          'type': 'move',
          'id': 'c',
          'before_id': adjusted ? 'b' : 'a',
          'after_id': adjusted ? 'hidden' : null,
          'base_version': oldVersion,
          'version': newVersion,
        }
      ],
    };

Future<AdminSequenceMoveResult> move({List<String>? baseline = before}) =>
    MobileApi.instance.adminMoveProductionMapSequence(
      apparatus: apparatus,
      orderId: 'c',
      beforeOrderId: 'a',
      expectedVersion: oldVersion,
      idempotencyKey: 'same-command',
      canonicalOrderIds: baseline,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'minimal-ack-test';
  });
  tearDown(() => AppSession.instance.token = null);

  test(
      'negotiates a minimal ACK without uploading IDs and retains the command body',
      () async {
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      final first = await move();
      expect(first.orderIds, after);
      expect(first.revision, 9);
      expect(first.epoch, 'server');
      expect((await move()).orderIds, after);
    },
        () => MockClient((request) async {
              requests.add(request);
              expect(request.headers['Prefer'], 'return=minimal');
              final body = jsonDecode(request.body) as Map;
              expect(body.keys.toSet(), {
                'apparatus',
                'order_id',
                'before_order_id',
                'expected_version',
                'idempotency_key'
              });
              return http.Response(jsonEncode(reply()), 200,
                  headers: {'preference-applied': 'return=minimal'});
            }));
    expect(requests[0].body, requests[1].body);
  });

  test('applies clamped server neighbors instead of requested anchors',
      () async {
    await http.runWithClient(() async {
      final result = await move();
      expect(result.adjusted, isTrue);
      expect(result.orderIds, ['a', 'hidden', 'c', 'b']);
    },
        () => MockClient((_) async => http.Response(
            jsonEncode(reply(ids: ['a', 'hidden', 'c', 'b'], adjusted: true)),
            200)));
  });

  test(
      'no-op receipt retains the captured full list and allows an absent revision',
      () async {
    await http.runWithClient(() async {
      final result = await move();
      expect(result.orderIds, before);
      expect(result.version, oldVersion);
      expect(result.revision, isNull);
    },
        () => MockClient((_) async => http.Response(
            jsonEncode({
              ...reply(ids: before),
              'version': oldVersion,
              'revision': null,
              'ops': [],
            }),
            200)));
  });

  test('older backend complete ACK is accepted when Prefer is ignored',
      () async {
    await http.runWithClient(() async {
      expect((await move()).orderIds, after);
    },
        () => MockClient((_) async => http.Response(
            jsonEncode({
              'ok': true,
              'order_ids': after,
              'version': newVersion,
              'adjusted': false,
            }),
            200)));
  });

  test(
      'without a complete baseline no minimal response is requested or accepted',
      () async {
    await http.runWithClient(() async {
      await expectLater(
          move(baseline: null), throwsA(isA<MobileApiException>()));
    },
        () => MockClient((request) async {
              expect(request.headers.containsKey('Prefer'), isFalse);
              return http.Response(jsonEncode(reply()), 200);
            }));
  });

  test(
      'baseline is captured before a delayed response and cannot be mutated by caller',
      () async {
    final release = Completer<void>();
    final entered = Completer<void>();
    final ids = [...before];
    await http.runWithClient(() async {
      final pending = move(baseline: ids);
      await entered.future;
      ids.clear();
      release.complete();
      expect((await pending).orderIds, after);
    },
        () => MockClient((_) async {
              entered.complete();
              await release.future;
              return http.Response(jsonEncode(reply()), 200);
            }));
  });

  final corruptions = <String, void Function(Map<String, Object?>)>{
    'wrong base version': (v) => v['base_version'] = 'f' * 64,
    'wrong count': (v) => v['order_count'] = 3,
    'wrong hash': (v) => v['order_hash'] = '0000000000000000',
    'null IDs': (v) => v['order_ids'] = null,
    'missing epoch': (v) => v.remove('epoch'),
    'fractional revision': (v) => v['revision'] = 9.5,
    'missing operation': (v) => v['ops'] = [],
    'wrong canonical order': (v) => (v['ops'] as List).single['id'] = 'a',
    'wrong operation version': (v) =>
        (v['ops'] as List).single['version'] = oldVersion,
    'wrong operation base': (v) =>
        (v['ops'] as List).single['base_version'] = newVersion,
    'missing anchor': (v) => (v['ops'] as List).single['before_id'] = 'missing',
    'inconsistent neighbors': (v) =>
        (v['ops'] as List).single['after_id'] = 'b',
    'unknown operation': (v) => (v['ops'] as List).single['type'] = 'remove',
    'multiple operations': (v) =>
        v['ops'] = [...v['ops'] as List, ...(v['ops'] as List)],
  };
  for (final entry in corruptions.entries) {
    test('rejects ${entry.key} so caller reconciles the committed server state',
        () async {
      final payload = reply();
      entry.value(payload);
      await http.runWithClient(() async {
        await expectLater(move(), throwsA(isA<MobileApiException>()));
      },
          () =>
              MockClient((_) async => http.Response(jsonEncode(payload), 200)));
      expect(before, ['a', 'hidden', 'b', 'c']);
    });
  }

  for (final ids in [
    <String>[],
    ['a', 'a', 'c'],
    ['a', 'b']
  ]) {
    test('invalid baseline $ids never writes a command', () async {
      await http.runWithClient(() async {
        await expectLater(
            move(baseline: ids), throwsA(isA<MobileApiException>()));
      },
          () => MockClient(
              (_) async => throw StateError('must not POST invalid baseline')));
    });
  }
}
