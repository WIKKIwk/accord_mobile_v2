import 'dart:convert';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> payload({bool received = false}) => {
      'paddon': {
        'id': 'p1',
        'total_gross_kg': 12,
        'total_net_kg': 11.25,
        'code': '00001',
        'location': received ? 'WH-1' : 'Rezka'
      },
      'items': [
        {
          'batch_id': 'b1',
          'apparatus': 'apparatus:default:asset-010',
          'finished_goods_kg': 12,
          'processed_by_apparatus': received ? 'warehouse:WH-1' : ''
        }
      ],
      'warehouses': ['WH-1'],
      'snapshot_token': 'snapshot-v1',
      'can_receive': !received,
      'receipt': received
          ? {'warehouse': 'WH-1', 'accepted_by_display_name': 'Werka'}
          : null,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSession.instance.setSession(
        token: 'token',
        profile: const SessionProfile(
            role: UserRole.werka,
            ref: 'keeper',
            displayName: 'Werka',
            legalName: '',
            phone: '',
            avatarUrl: '',
            capabilities: ['werka.access']));
  });
  tearDown(() => AppSession.instance.clear());

  test('Werka preview and receive use authenticated pallet contract', () async {
    var writes = 0;
    await http.runWithClient(() async {
      final preview = await MobileApi.instance.werkaPaddonPreview(' 00001 ');
      expect(preview.snapshot.items.single.batchId, 'b1');
      expect(preview.snapshot.paddon.totalGrossKg, 12);
      expect(preview.snapshot.paddon.totalNetKg, 11.25);
      final receipt =
          await MobileApi.instance.werkaReceivePaddon(preview, 'WH-1');
      expect(receipt['warehouse'], 'WH-1');
      expect(writes, 1);
    },
        () => MockClient((request) async {
              expect(request.headers['Authorization'], 'Bearer token');
              if (request.method == 'GET') {
                expect(request.url.path, '/v1/mobile/werka/paddons/preview');
                expect(request.url.queryParameters['code'], '00001');
                return http.Response(jsonEncode(payload()), 200);
              }
              writes++;
              expect(request.url.path, '/v1/mobile/werka/paddons/receive');
              expect(jsonDecode(request.body), {
                'code': '00001',
                'warehouse': 'WH-1',
                'expected_batch_ids': ['b1'],
                'snapshot_token': 'snapshot-v1'
              });
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'receipt': payload(received: true)['receipt']
                  }),
                  200);
            }));
  });

  test(
      'received batch supports warehouse processor without relaxing apparatus IDs',
      () {
    final preview = WerkaPaddonPreview.fromJson(payload(received: true));
    expect(
        preview.snapshot.items.single.processedByApparatus, 'warehouse:WH-1');
    expect(preview.canReceive, isFalse);
    for (final bad in ['Rezka', 'warehouse:', '']) {
      final data = payload();
      (data['items'] as List).single['apparatus'] = bad;
      expect(() => WerkaPaddonPreview.fromJson(data),
          throwsA(isA<MobileApiException>()));
    }
  });

  test('receipt conflict is surfaced to refresh, not retried automatically',
      () async {
    var writes = 0;
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.werkaReceivePaddon(
              WerkaPaddonPreview.fromJson(payload()), 'WH-1'),
          throwsA(isA<MobileApiException>()
              .having((e) => e.code, 'code', 'paddon_receipt_conflict')));
    },
        () => MockClient((_) async {
              writes++;
              return http.Response(
                  jsonEncode({'error': 'paddon_receipt_conflict'}), 409);
            }));
    expect(writes, 1);
  });
  test(
      'universal preview never guesses type from code and rejects unknown kind',
      () async {
    final codes = ['00001', 'WIP-v2:batch/01', 'https://example.invalid/W/QR'];
    var calls = 0;
    await http.runWithClient(() async {
      for (final code in codes) {
        await expectLater(
            MobileApi.instance.werkaQrPreview(code),
            throwsA(isA<MobileApiException>()
                .having((e) => e.code, 'code', 'qr_preview_invalid')));
      }
    },
        () => MockClient((request) async {
              expect(request.method, 'GET');
              expect(request.url.path, '/v1/mobile/werka/qr/preview');
              expect(request.url.queryParameters['qr_payload'], codes[calls++]);
              return http.Response('{"kind":"unknown"}', 200);
            }));
    expect(calls, codes.length);
  });

  test('single WIP stale token returns conflict without automatic POST retry',
      () async {
    final preview = WerkaWipPreview.fromJson({
      'batch': {
        'batch_id': 'b1',
        'apparatus': 'apparatus:default:asset-010',
        'qr_payload': 'QR-b1'
      },
      'snapshot_token': 'before',
      'can_receive': true,
      'warehouses': ['WH-1'],
    });
    var calls = 0;
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.werkaReceiveWip(preview, 'WH-1'),
          throwsA(isA<MobileApiException>()
              .having((e) => e.code, 'code', 'wip_receipt_conflict')));
    },
        () => MockClient((request) async {
              calls++;
              expect(request.method, 'POST');
              expect(request.url.path, '/v1/mobile/werka/wip/receive');
              expect(request.headers['Authorization'], 'Bearer token');
              expect(jsonDecode(request.body), {
                'progress_batch_id': 'b1',
                'qr_payload': 'QR-b1',
                'snapshot_token': 'before',
                'warehouse': 'WH-1'
              });
              return http.Response('{"error":"wip_receipt_conflict"}', 409);
            }));
    expect(calls, 1);
  });
}
