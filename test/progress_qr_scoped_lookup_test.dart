import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const station = 'apparatus:default:asset-007';
  const order = 'zakaz-0073';
  const qr = '400118D5A225166D31898C1F';
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'test-session';
  });
  tearDown(() { AppSession.instance.token = null; });
  for (final entry in {
    'progress_batch_already_used': 'allaqachon ishlatilgan',
    'progress_batch_in_use': 'ishlatilmoqda',
  }.entries) {
    for (final apparatusName in ['Rezka 5', '']) {
      test('scoped QR explains ${entry.key} with owner "$apparatusName"', () async {
        await http.runWithClient(() async {
          try {
            await MobileApi.instance.adminProgressQrLookup(qr,
                apparatus: station, orderId: order);
            fail('An unavailable roll must remain blocked');
          } on MobileApiException catch (error) {
            expect(error.code, entry.key);
            expect(error.message, contains(entry.value));
            expect(error.message, isNot(contains('oldingi bosqich mahsulotiga mos emas')));
            expect(AppLocalizations(const Locale('uz')).productionErrorMessage(
                error.code, fallback: error.message), error.message);
            if (apparatusName.isNotEmpty) {
              expect(error.message, contains('Rezka 5 apparatida'));
            }
          }
        }, () => MockClient((_) async => http.Response(jsonEncode({
          'error': entry.key,
          if (apparatusName.isNotEmpty) 'apparatus_name': apparatusName,
        }), 400)));
      });
    }
  }
  for (final validation in ['valid', 'missing', 'wrong_apparatus', 'wrong_order']) {
    test('scoped QR lookup requires exact server confirmation: $validation', () async {
      Object? sent;
      await http.runWithClient(() async {
        final future = MobileApi.instance.adminProgressQrLookup(qr,
          apparatus: station, orderId: order);
        if (validation == 'valid') {
          final batch = await future;
          expect(batch.nextApparatus, 'apparatus:default:asset-008');
          expect(batch.wipStatus, 'waiting');
        } else {
          await expectLater(future, throwsA(isA<MobileApiException>().having(
            (e) => e.code, 'code', 'progress_batch_not_accepted')));
        }
      }, () => MockClient((request) async {
        sent = jsonDecode(request.body);
        return http.Response(jsonEncode({
          if (validation != 'missing') ...{
            'validated_apparatus': validation == 'wrong_apparatus' ? 'apparatus:default:asset-008' : station,
            'validated_order_id': validation == 'wrong_order' ? 'other-order' : order,
          },
          'batch': {
            'batch_id': 'roll-0073', 'order_id': order, 'qr_payload': qr,
            'apparatus': 'apparatus:default:bosma_9',
            'next_apparatus': 'apparatus:default:asset-008', 'wip_status': 'waiting',
          },
        }), 200);
      }));
      expect(sent, {'qr_payload': qr, 'apparatus': station, 'order_id': order});
    });
  }

  test('lookup route metadata preserves original printed QR and historical nodes', () async {
    const printedQr = '400118DA2F17C3617F59DDC6';
    final originalPayload = {
      'production_stage_node_id': 'laminatsiya_4',
      'next_stage_node_id': 'rezka_5',
      'gross_qty': 120,
    };
    await http.runWithClient(() async {
      final batch = await MobileApi.instance.adminProgressQrLookup(printedQr);
      expect(batch.qrPayload, printedQr);
      expect(batch.batchId, 'original-roll');
      expect(batch.payloadJson, originalPayload);
      expect(batch.nextApparatus, station);
      expect(batch.hasInputRouteMetadata, isTrue);
      expect(batch.inputRouteError, isEmpty);
      expect(batch.inputRoute!.stageNodeId, 'apparatus_6');
      expect(batch.inputRoute!.consumerApparatusIds, [station, 'apparatus:default:asset-008']);
      expect(batch.inputRoute!.remapped, isTrue);
      expect(batch.copyWith(wipStatus: 'in_use').inputRoute, same(batch.inputRoute));
    }, () => MockClient((request) async => http.Response(jsonEncode({
      'batch': {
        'batch_id': 'original-roll', 'apparatus': 'apparatus:default:bosma_9',
        'order_id': order, 'qr_payload': printedQr, 'produced_qty': 6170,
        'uom': 'm', 'wip_status': 'waiting', 'next_apparatus': station,
        'payload_json': originalPayload,
      },
      'input_route': {
        'source_stage_node_id': 'laminatsiya_4',
        'stage_node_id': 'apparatus_6',
        'consumer_apparatus_ids': [station, 'apparatus:default:asset-008'],
        'map_fingerprint': 'current-map', 'remapped': true,
      },
    }), 200)));
  });

  for (final metadata in [
    <String, dynamic>{},
    {'input_route': null},
    {'input_route_error': 'wip_route_source_unresolved'},
    {'input_route_error': 'wip_route_ambiguous'},
  ]) {
    test('lookup preserves authoritative route presence/error: $metadata', () async {
      await http.runWithClient(() async {
        final batch = await MobileApi.instance.adminProgressQrLookup(qr);
        expect(batch.hasInputRouteMetadata, metadata.isNotEmpty);
        expect(batch.inputRoute, isNull);
        expect(batch.inputRouteError, metadata.isEmpty ? '' :
          metadata['input_route_error'] ?? 'wip_route_destination_unresolved');
      }, () => MockClient((_) async => http.Response(jsonEncode({
        'batch': {'batch_id': 'roll', 'apparatus': station}, ...metadata,
      }), 200)));
    });
  }

  for (final code in [
    'wip_route_source_unresolved', 'wip_route_destination_unresolved',
    'wip_route_ambiguous', 'wip_route_changed',
  ]) {
    test('scoped route failure $code explains map recovery in every locale', () async {
      await http.runWithClient(() async {
        try {
          await MobileApi.instance.adminProgressQrLookup(qr, apparatus: station, orderId: order);
          fail('Route error must stay blocked');
        } on MobileApiException catch (error) {
          expect(error.code, code);
          expect(error.message, isNot(contains('oldingi bosqich mahsulotiga mos emas')));
          for (final locale in ['uz', 'ru', 'en']) {
            final localized = AppLocalizations(Locale(locale)).productionErrorMessage(code);
            expect(localized, isNotEmpty);
            expect(localized, isNot(code));
          }
        }
      }, () => MockClient((_) async => http.Response(jsonEncode({'error': code}), 400)));
    });
  }
  for (final scenario in ['route-error', 'null-route', 'wrong-consumer', 'empty-consumers']) {
    test('scoped lookup rejects contradictory authoritative metadata: $scenario', () async {
      final route = {
        'source_stage_node_id': 'source', 'stage_node_id': 'target',
        'map_fingerprint': 'current-map', 'remapped': true,
        'consumer_apparatus_ids': scenario == 'empty-consumers' ? <String>[] :
          ['apparatus:default:asset-008'],
      };
      final expectedCode = scenario == 'route-error' ? 'wip_route_ambiguous' :
        scenario == 'wrong-consumer' ? 'progress_batch_not_accepted' :
        'wip_route_destination_unresolved';
      await http.runWithClient(() async {
        await expectLater(MobileApi.instance.adminProgressQrLookup(qr,
          apparatus: station, orderId: order), throwsA(isA<MobileApiException>().having(
            (error) => error.code, 'route error', expectedCode)));
      }, () => MockClient((_) async => http.Response(jsonEncode({
        'validated_apparatus': station, 'validated_order_id': order,
        'batch': {'batch_id': 'roll', 'apparatus': station},
        if (scenario == 'route-error') 'input_route_error': 'wip_route_ambiguous'
        else 'input_route': scenario == 'null-route' ? null : route,
      }), 200)));
    });
  }
}
