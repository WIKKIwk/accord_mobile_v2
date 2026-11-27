import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/core/widgets/display/app_metric_tile.dart';
import 'package:accord_mobile_v2/src/core/widgets/lists/app_segment_surface_card.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_shell.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/waste/presentation/waste_operator_screen.dart';
import 'package:accord_mobile_v2/src/features/waste/presentation/waste_weigh_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _apparatusId = 'apparatus:default:asset-010';

Map<String, dynamic> _cycleJson(
  String status, {
  Map<String, dynamic>? receipt,
}) =>
    {
      'id': 'cycle-123',
      'apparatus_id': _apparatusId,
      'apparatus_name': 'Rezka',
      'status': status,
      'opened_at_unix': 1000,
      'expected_kg': 20,
      'entries': [
        {'id': 'first', 'actor_display_name': 'Ali', 'kg': 12},
        {'id': 'second', 'actor_display_name': 'Vali', 'kg': 8},
      ],
      'receipt': receipt,
    };

Map<String, dynamic> _binJson(String status, {Map<String, dynamic>? cycle}) => {
      'code': 'CQ-10',
      'qr_payload': 'ACCORD-WASTE:CQ-10',
      'tare_kg': '5.000000',
      'tolerance_kg': 0.5,
      'status': status,
      'cycle': cycle ?? _cycleJson(status),
    };

http.Response _json(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = SessionProfile.fromJson({
      'role': 'chiqindi_qabulchi',
      'ref': 'receiver-96',
      'display_name': 'Qabulchi',
      'capabilities': ['waste.receive'],
    });
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('the waste receiver has its own capability-gated system workspace', () {
    final session = AppSession.instance;
    expect(session.profile?.role, UserRole.chiqindiQabulchi);
    expect(session.profile?.toJson()['role'], 'chiqindi_qabulchi');
    expect(session.homeRoute, AppRoutes.wasteReceiving);
    expect(AppRouter.canOpenRoute(AppRoutes.wasteReceiving), isTrue);
    expect(AppRouter.canOpenRoute(AppRoutes.wasteWarehouses), isTrue);
    expect(AppRouter.canOpenRoute(AppRoutes.adminHome), isFalse);
    expect(AppRouter.canOpenRoute(AppRoutes.apparatusQueue), isFalse);
    session.profile = session.profile!.copyWith(
      role: UserRole.aparatchi,
      assignedApparatus: [_apparatusId],
    );
    expect(AppRouter.canOpenRoute(AppRoutes.wasteReceiving), isFalse);
    expect(AppRouter.canOpenRoute(AppRoutes.wasteWarehouses), isFalse);
  });

  test(
      'the API does not request operator options without a token and passes QR denial through',
      () async {
    var sent = 0;
    final client = MockClient((request) async {
      sent++;
      expect(request.url.path, '/v1/mobile/waste/bins/assign');
      expect(request.headers['authorization'], 'Bearer token');
      expect(jsonDecode(request.body), {
        'code': 'FOREIGN-QR',
        'apparatus_id': _apparatusId,
      });
      return _json({
        'code': 'waste_bin_forbidden',
        'error': 'Bu quti sizga biriktirilmagan',
      }, 403);
    });
    await http.runWithClient(() async {
      final api = MobileApi.instance;
      AppSession.instance.token = null;
      await expectLater(api.wasteBinOptions(), throwsException);
      expect(sent, 0);
      AppSession.instance.token = 'token';
      await expectLater(
        api.assignWasteBin('ACCORD-WASTE:FOREIGN-QR', _apparatusId),
        throwsA(isA<MobileApiException>()
            .having((error) => error.code, 'code', 'waste_bin_forbidden')
            .having((error) => error.statusCode, 'status', 403)),
      );
    }, () => client);
    expect(sent, 1);
  });

  test('camera codes are reserved and receive/reset target one exact cycle',
      () async {
    expect(isWasteBinQr('CQ-10'), isFalse);
    expect(isWasteBinQr('ACCORD-WASTE:CQ-10'), isTrue);
    expect(isWasteBinQr('ACCORD-WASTE:CQ-10:extra'), isFalse);
    const receipt = {
      'gross_kg': 23,
      'tare_kg': 5,
      'net_kg': 18,
      'expected_kg': 20,
      'difference_kg': -2,
      'measurement_source': 'gscale',
      'outside_tolerance': true,
      'note': 'Qayta tortildi',
      'warehouse_id': 'wh-waste-1',
      'warehouse': 'Chiqindi ombori',
    };
    final calls = <String>[];
    final client = MockClient((request) async {
      final action = request.url.pathSegments.last;
      calls.add(action);
      expect(request.headers['authorization'], 'Bearer token');
      if (action == 'warehouses') {
        return _json({
          'warehouses': [
            {
              'id': 'wh-waste-1',
              'warehouse': 'Chiqindi ombori',
              'on_hand_kg': '18.000000',
              'receipt_count': 1,
            },
          ],
        });
      }
      if (action == 'bins') {
        final cycleSummary = _cycleJson('sealed')..remove('entries');
        return _json({
          'bins': [_binJson('sealed', cycle: cycleSummary)]
        });
      }
      if (action == 'detail') {
        expect(request.url.queryParameters['code'], 'CQ-10');
        return _json(_binJson('sealed'));
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['code'], 'CQ-10');
      expect(body['cycle_id'], 'cycle-123');
      if (action == 'receive') {
        expect(body['warehouse_id'], 'wh-waste-1');
        expect(body['gross_kg'], 23);
        expect(body['measurement_source'], 'gscale');
        expect(body['note'], 'Qayta tortildi');
        return _json(_binJson('received',
            cycle: _cycleJson('received', receipt: receipt)));
      }
      expect(action, 'reset');
      return _json(
          _binJson('empty', cycle: _cycleJson('reset', receipt: receipt)));
    });
    await http.runWithClient(() async {
      final api = MobileApi.instance;
      final warehouse = (await api.wasteWarehouses()).single;
      expect(warehouse.id, 'wh-waste-1');
      expect(warehouse.warehouse, 'Chiqindi ombori');
      expect(warehouse.onHandKg, 18);
      expect(warehouse.receiptCount, 1);
      final queue = await api.wasteBins();
      expect(queue.single.cycle?.expectedKg, 20);
      final bin = await api.wasteBinDetail(' ACCORD-WASTE:CQ-10 ');
      expect(
          bin.cycle?.entries.map((entry) => entry.actorName), ['Ali', 'Vali']);
      final received = await api.receiveWasteBin(
          bin: bin,
          warehouseId: warehouse.id,
          grossKg: 23,
          source: 'gscale',
          note: 'Qayta tortildi');
      expect(received.cycle?.receipt?.differenceKg, -2);
      expect(received.cycle?.receipt?.outsideTolerance, isTrue);
      expect(received.cycle?.receipt?.warehouse, 'Chiqindi ombori');
      final reset = await api.resetWasteBin(received);
      expect(reset.status, WasteBinStatus.empty);
      expect(reset.cycle?.receipt?.netKg, 18);
    }, () => client);
    expect(calls, ['warehouses', 'bins', 'detail', 'receive', 'reset']);
  });

  test('an old receipt retains its measured kg when a destination is assigned',
      () async {
    const receipt = {
      'gross_kg': 23,
      'tare_kg': 5,
      'net_kg': 18,
      'expected_kg': 20,
      'difference_kg': -2,
      'measurement_source': 'manual',
    };
    final legacy = WasteBin.fromJson(
      _binJson('received', cycle: _cycleJson('received', receipt: receipt)),
    );
    expect(legacy.cycle?.receipt?.warehouseId, isNull);
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/mobile/waste/bins/destination');
      expect(jsonDecode(request.body), {
        'code': 'CQ-10',
        'cycle_id': 'cycle-123',
        'warehouse_id': 'wh-waste-1',
      });
      return _json(_binJson('received',
          cycle: _cycleJson('received', receipt: {
            ...receipt,
            'warehouse_id': 'wh-waste-1',
            'warehouse': 'Chiqindi ombori',
          })));
    });
    await http.runWithClient(() async {
      final updated = await MobileApi.instance.assignWasteReceiptDestination(
        bin: legacy,
        warehouseId: 'wh-waste-1',
      );
      expect(updated.cycle?.receipt?.warehouseId, 'wh-waste-1');
      expect(updated.cycle?.receipt?.warehouse, 'Chiqindi ombori');
      expect(updated.cycle?.receipt?.netKg, legacy.cycle?.receipt?.netKg);
    }, () => client);
  });

  testWidgets(
      'weighing requires a destination and a reason for a difference outside tolerance',
      (tester) async {
    WasteMeasurement? result;
    final bin = WasteBin.fromJson(_binJson('sealed'));
    await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showDialog<WasteMeasurement>(
                      context: context,
                      builder: (_) => WasteWeighDialog(
                        bin: bin,
                        warehouses: [
                          WasteWarehouse.fromJson({
                            'id': 'waste-a',
                            'warehouse': 'Chiqindi ombori A',
                            'on_hand_kg': 0,
                            'receipt_count': 0,
                          }),
                          WasteWarehouse.fromJson({
                            'id': 'waste-b',
                            'warehouse': 'Chiqindi ombori B',
                            'on_hand_kg': 18,
                            'receipt_count': 1,
                          }),
                        ],
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              )),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '23');
    await tester.pumpAndSettle();
    expect(find.text('18 kg'), findsOneWidget);
    expect(find.text('-2 kg'), findsOneWidget);
    final accept = find.widgetWithText(FilledButton, 'Qabul qilish');
    expect(tester.widget<FilledButton>(accept).onPressed, isNull);
    await tester.enterText(find.byType(TextField).last, 'Qayta tortildi');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(accept).onPressed, isNull);
    final warehousePicker = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(warehousePicker);
    await tester.tap(warehousePicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chiqindi ombori B').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(accept);
    await tester.tap(accept);
    await tester.pumpAndSettle();
    expect(result?.grossKg, 23);
    expect(result?.source, 'manual');
    expect(result?.note, 'Qayta tortildi');
    expect(result?.warehouseId, 'waste-b');
  });

  testWidgets('operator attaches reported waste and swaps the bin',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AppSession.instance.profile = AppSession.instance.profile!.copyWith(
      role: UserRole.aparatchi,
      assignedApparatus: [_apparatusId],
    );
    final operations = <String>[];
    String? active;
    var hasWaste = false;
    var claimAttempts = 0;
    const report = {
      'id': 'astatka-entry',
      'order_id': 'current-order',
      'actor_display_name': 'Ali',
      'kg': 2.5,
      'reason': 'Astatka hisoboti',
    };
    Map<String, dynamic> bin(String code, String status) => {
          ..._binJson(status),
          'code': code,
          'name': code == 'CQ-A' ? 'Asosiy quti' : 'Zaxira quti',
          'configured': true,
          'qr_payload': 'ACCORD-WASTE:$code',
          'cycle': status == 'empty'
              ? null
              : {
                  ..._cycleJson(status),
                  'id': 'cycle-$code',
                  'expected_kg': hasWaste && code == 'CQ-A' ? 2.5 : 0,
                  'entries': [if (hasWaste && code == 'CQ-A') report],
                },
        };
    final client = MockClient((request) async {
      final action = request.url.pathSegments.last;
      if (action == 'active') {
        expect(request.url.queryParameters['apparatus_id'], _apparatusId);
        return _json({
          'bin': active == null ? null : bin(active!, 'open'),
          'pending': [if (!hasWaste) report],
        });
      }
      if (action == 'bins') {
        expect(request.url.queryParameters['status'], 'empty');
        expect(request.url.queryParameters['apparatus_id'], _apparatusId);
        return _json({
          'bins': [
            bin(active == null ? 'CQ-A' : 'CQ-B', 'empty'),
            {
              ...bin('CQ-OLD', 'empty'),
              'name': 'Eski quti',
              'configured': false,
            },
          ],
        });
      }
      operations.add(action);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['apparatus_id'], _apparatusId);
      if (action == 'assign') {
        expect(body['code'], 'CQ-A');
        if (claimAttempts++ == 0) {
          return _json({'code': 'waste_bin_conflict', 'error': 'Band'}, 409);
        }
        active = 'CQ-A';
        return _json(bin('CQ-A', 'open'));
      }
      expect(body['code'], 'CQ-A');
      expect(body['cycle_id'], 'cycle-CQ-A');
      if (action == 'reconcile') {
        expect(body['entry_ids'], ['astatka-entry']);
        hasWaste = true;
        return _json(bin('CQ-A', 'open'));
      }
      expect(action, 'submit');
      expect(body['replacement_code'], 'CQ-B');
      active = 'CQ-B';
      return _json(bin('CQ-A', 'sealed'));
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: const WasteOperatorScreen(
          apparatusId: _apparatusId,
          apparatusName: 'Rezka',
          orderId: 'current-order',
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
      await tester.tap(find.text('Quti tanlash'));
      await tester.pumpAndSettle();
      expect(find.text('Eski quti'), findsNothing);
      await tester.tap(find.text('Asosiy quti'));
      await tester.pumpAndSettle();
      expect(
        find.text(
            'Quti band yoki apparatda boshqa faol quti bor. Ro‘yxatni qayta oching.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Quti tanlash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asosiy quti'));
      await tester.pumpAndSettle();
      final activeCard = find.ancestor(
        of: find.text('Asosiy quti · CQ-A'),
        matching: find.byType(AppSegmentSurfaceCard),
      );
      expect(tester.getSize(activeCard).width, greaterThan(350));
      expect(find.text('Rezka'), findsOneWidget);
      expect(find.text('Yig‘ilmoqda'), findsOneWidget);
      final weightTile = find.descendant(
        of: activeCard,
        matching: find.byType(AppMetricTile),
      );
      expect(tester.widget<AppMetricTile>(weightTile).value, '0 kg');
      expect(find.text('0 kg'), findsOneWidget);
      expect(
        find.descendant(
            of: activeCard, matching: find.text('Qutini almashtirish')),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: activeCard, matching: find.text('Qutini topshirish')),
        findsOneWidget,
      );
      expect(find.text('Chiqindi qo‘shish'), findsNothing);
      expect(
          find.text('Hisobotdagi chiqindi faol qutiga avtomatik qo‘shiladi.'),
          findsOneWidget);
      await tester.tap(find.text('Biriktirish'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, '2.5 kg · Ali'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Biriktirish'));
      await tester.pumpAndSettle();
      expect(tester.widget<AppMetricTile>(weightTile).value, '2.5 kg');
      expect(find.textContaining('Astatka hisoboti · Buyurtma: current-order'),
          findsOneWidget);
      await tester.tap(find.text('Qutini almashtirish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zaxira quti'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Topshirish'));
      await tester.pumpAndSettle();
      expect(find.text('Zaxira quti · CQ-B'), findsOneWidget);
      expect(find.text('Qutini bo‘shatish'), findsNothing);
      expect(tester.takeException(), isNull);
    }, () => client);
    expect(operations, ['assign', 'assign', 'reconcile', 'submit']);
  });

  test('Bosma astatka keeps one request key across an uncertain retry',
      () async {
    final keys = <String>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      keys.add(body['request_id'] as String);
      if (keys.length == 1) return _json({'error': 'try again'}, 503);
      return _json({
        'report': {'report_id': 'astatka-1'}
      });
    });
    await http.runWithClient(() async {
      Future<Map<String, dynamic>> submit() =>
          MobileApi.instance.adminBosmaAstatkaReport(
            apparatus: 'apparatus:default:bosma_7',
            orderId: 'order-1',
            totalWaste: 12,
            returnedPaintItems: [],
            returnedPaintImageId: 'photo-1',
          );
      await expectLater(submit(), throwsA(isA<MobileApiException>()));
      expect((await submit())['report_id'], 'astatka-1');
      await submit();
    }, () => client);
    expect(keys[0], keys[1]);
    expect(keys[2], isNot(keys[1]));
  });
}
