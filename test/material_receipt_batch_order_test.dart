import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/native_usb_printer.dart';
import 'package:accord_mobile_v2/src/core/print_transport.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_picker_field.dart';
import 'package:accord_mobile_v2/src/features/gscale/gscale_mobile_app.dart';
import 'package:accord_mobile_v2/src/features/preparation/models/preparation_models.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/widgets/preparation_kirim_order_section.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _setSession();
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets(
    'order picker stays locked until state resolves and while active',
    (tester) async {
      final state = Completer<GScaleRpsBatchResponse>();
      final changes = <PreparationOrder?>[];
      await _withApi(tester, () async {
        await tester.pumpWidget(
          _app(
            _ReceiptHarness(
              initialOrder: _orderA,
              stateLoader: () => state.future,
              onOrderChanged: changes.add,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(_picker(tester).disabled, isTrue);
        expect(
          changes,
          isEmpty,
          reason: 'Loading orders must not clear context',
        );
        await tester.tap(find.byKey(_orderFieldKey));
        await tester.pumpAndSettle();
        expect(find.text('Order tanlang'), findsNothing);

        state.complete(
          GScaleRpsBatchResponse(
            ok: true,
            batch: GScaleRpsBatchSession.fromJson(_batch(active: true)),
          ),
        );
        await tester.pumpAndSettle();
        expect(_picker(tester).disabled, isTrue);
        // Also exercise the callback guard, independently of InkWell disabling.
        _picker(tester).onPick();
        await tester.pumpAndSettle();
        expect(find.text('Order tanlang'), findsNothing);
        expect(find.text('Faol batch orderi: order-A'), findsOneWidget);
        expect(changes, isEmpty);
      });
    },
  );

  testWidgets(
    'a result from an already open order sheet is ignored once locked',
    (tester) async {
      final disabled = ValueNotifier(false);
      final changes = <PreparationOrder?>[];
      addTearDown(disabled.dispose);
      await _withApi(tester, () async {
        await tester.pumpWidget(
          _app(
            ValueListenableBuilder<bool>(
              valueListenable: disabled,
              builder: (context, value, child) => PreparationKirimOrderSection(
                initialOrder: _orderA,
                disabled: value,
                loadOrders: () async => [_orderA, _orderB],
                onOrderChanged: changes.add,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        changes.clear();
        await tester.tap(find.byKey(_orderFieldKey));
        await tester.pumpAndSettle();
        expect(find.text('Order tanlang'), findsOneWidget);

        disabled.value = true;
        await tester.pump();
        await tester.tap(find.text('B — Second order'));
        await tester.pumpAndSettle();
        expect(changes, isEmpty);
        expect(_picker(tester).valueText, 'A — First order');
        expect(find.text('Order tanlang'), findsNothing);
      });
    },
  );

  testWidgets(
    'same-order draft survives restore and switching orders resets it',
    (tester) async {
      await saveOperatorControlDraft(_draft(saved: true));
      expect((await loadOperatorControlDraft()).orderId, 'order-A');
      final legacy = _draft().toJson()..remove('order_id');
      expect(OperatorControlDraft.fromJson(legacy).orderId, '');

      await _withApi(tester, () async {
        await tester.pumpWidget(_app(_ReceiptHarness(initialOrder: _orderA)));
        await tester.pumpAndSettle();
        expect(find.text('PET • 390 mm • 12 mikron • 125 m'), findsOneWidget);
        await tester.tap(find.byTooltip('Batch ma’lumotini tahrirlash'));
        await tester.pumpAndSettle();
        expect(_field(tester, 'Eni (mm)'), '390');
        expect(_field(tester, 'Mikron'), '12');
        expect(_field(tester, 'Metraj (m)'), '125');

        await tester.tap(find.byKey(_orderFieldKey));
        await tester.pumpAndSettle();
        await tester.tap(find.text('B — Second order'));
        await tester.pumpAndSettle();
        expect(_field(tester, 'Eni (mm)'), '500');
        expect(_field(tester, 'Mikron'), '');
        expect(_field(tester, 'Metraj (m)'), '');
        expect(find.text('PET'), findsNothing);
        expect(find.text('Homashyo'), findsOneWidget);
        expect(find.text('Stores'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 250));
        final switched = await loadOperatorControlDraft();
        expect(switched.orderId, 'order-B');
        expect(switched.itemCode, '');
        expect(switched.widthText, '500');
        expect(switched.micronText, '');
        expect(switched.lengthText, '');
        expect(switched.contextSaved, isFalse);
      });
    },
  );

  testWidgets(
    'stopping restored active A clears its material from selected B',
    (tester) async {
      await saveOperatorControlDraft(
        _draft(
          orderId: 'order-B',
          item: 'CPP',
          width: '510',
          micron: '20',
          length: '222',
          saved: true,
        ),
      );
      final stops = <Map<String, dynamic>>[];
      await _withApi(
        tester,
        () async {
          await tester.pumpWidget(
            _app(
              _ReceiptHarness(
                initialOrder: _orderB,
                stateLoader: () async => GScaleRpsBatchResponse(
                  ok: true,
                  batch: GScaleRpsBatchSession.fromJson(_batch(active: true)),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Faol batch orderi: order-A'), findsOneWidget);
          expect(find.text('PET • 390 mm • 12 mikron • 125 m'), findsOneWidget);
          expect(_picker(tester).disabled, isTrue);
          await tester.tap(find.text('To‘xtatish'));
          await tester.pumpAndSettle();

          expect(stops, [
            {'batch_id': 'batch-A', 'expected_revision': 7},
          ]);
          expect(_picker(tester).disabled, isFalse);
          expect(_picker(tester).valueText, 'B — Second order');
          expect(_field(tester, 'Eni (mm)'), '500');
          expect(_field(tester, 'Mikron'), '');
          expect(_field(tester, 'Metraj (m)'), '');
          expect(find.text('Homashyo'), findsOneWidget);
          expect(find.textContaining('PET'), findsNothing);
          await tester.pump(const Duration(milliseconds: 250));
          final stopped = await loadOperatorControlDraft();
          expect(stopped.orderId, 'order-B');
          expect(stopped.itemCode, '');
          expect(stopped.contextSaved, isFalse);
        },
        intercept: (request) async {
          if (!request.url.path.endsWith('/rps/batch/stop')) return null;
          stops.add(_body(request));
          return _json({'ok': true, 'batch': _batch(active: false)});
        },
      );
    },
  );

  testWidgets(
    'start locks before autosave and rejects a changed order after await',
    (tester) async {
      await saveOperatorControlDraft(_draft());
      final scope = Completer<http.Response>();
      final harness = GlobalKey<_ReceiptHarnessState>();
      var scopeRequests = 0;
      var starts = 0;
      await _withApi(
        tester,
        () async {
          await tester.pumpWidget(
            _app(_ReceiptHarness(key: harness, initialOrder: _orderA)),
          );
          await tester.pumpAndSettle();
          // Force autosave to await the warehouse-scope HTTP read this time.
          _setSession(assignedWarehouses: const []);
          await tester.tap(find.text('Boshlash'));
          await tester.pump();
          expect(scopeRequests, 1);
          expect(_picker(tester).disabled, isTrue);
          _picker(tester).onPick();
          await tester.pump();
          expect(find.text('Order tanlang'), findsNothing);
          expect(harness.currentState!.selected.id, 'order-A');

          // A parent rebuild can still replace context while an async start waits.
          // It must abort rather than combine the new order with the old material.
          harness.currentState!.selectOrder(_orderB);
          await tester.pump();
          scope.complete(
            _json([
              {
                'warehouse': 'Stores',
                'principal_role': 'material_taminotchi',
                'principal_ref': 'material-order-tests',
                'display_name': 'Materialchi',
              },
            ]),
          );
          await tester.pumpAndSettle();
          expect(starts, 0);
          expect(
            find.text('Order yoki batch holati o‘zgardi. Qayta tekshiring.'),
            findsOneWidget,
          );
          expect(_picker(tester).disabled, isFalse);
        },
        intercept: (request) async {
          if (request.url.path.endsWith('/warehouses/assignments')) {
            scopeRequests++;
            return scope.future;
          }
          if (request.url.path.endsWith('/rps/batch/start')) {
            starts++;
            return _json({'ok': true, 'batch': _batch(active: true)});
          }
          return null;
        },
      );
    },
  );

  testWidgets('an old state response cannot erase a newly started batch', (
    tester,
  ) async {
    await saveOperatorControlDraft(_draft(saved: true));
    final oldState = Completer<GScaleRpsBatchResponse>();
    var stateRequests = 0;
    await _withApi(
      tester,
      () async {
        await tester.pumpWidget(
          _app(
            _ReceiptHarness(
              initialOrder: _orderA,
              stateLoader: () {
                stateRequests++;
                if (stateRequests == 1) return oldState.future;
                return Future.value(
                  GScaleRpsBatchResponse(
                    ok: true,
                    batch:
                        GScaleRpsBatchSession.fromJson(_batch(active: false)),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Holatni qayta tekshirish'));
        await tester.pumpAndSettle();
        expect(_picker(tester).disabled, isFalse);
        await tester.tap(find.text('Boshlash'));
        await tester.pumpAndSettle();
        expect(find.text('Faol batch orderi: order-A'), findsOneWidget);

        oldState.complete(
          GScaleRpsBatchResponse(
            ok: true,
            batch: GScaleRpsBatchSession.fromJson(_batch(active: false)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Faol batch orderi: order-A'), findsOneWidget);
        expect(_picker(tester).disabled, isTrue);
        expect(find.text('To‘xtatish'), findsOneWidget);
      },
      intercept: (request) async {
        if (request.url.path.endsWith('/rps/batch/start')) {
          return _json({'ok': true, 'batch': _batch(active: true)});
        }
        return null;
      },
    );
  });

  testWidgets('failed conflict refresh can be retried without unlocking orders',
      (
    tester,
  ) async {
    await saveOperatorControlDraft(
      _draft(orderId: 'order-B', item: 'CPP', width: '510', saved: true),
    );
    final retry = Completer<http.Response>();
    var stateRequests = 0;
    var starts = 0;
    await _withApi(
      tester,
      () async {
        await tester.pumpWidget(
          _app(_ReceiptHarness(initialOrder: _orderB, useHttpState: true)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Boshlash'));
        await tester.pumpAndSettle();
        expect(starts, 1);
        expect(stateRequests, 2);
        expect(_picker(tester).disabled, isTrue);

        final retryButton = find.widgetWithText(
          TextButton,
          'Holatni qayta tekshirish',
        );
        await tester.tap(retryButton);
        await tester.pump();
        expect(stateRequests, 3);
        expect(_picker(tester).disabled, isTrue);
        expect(tester.widget<TextButton>(retryButton).onPressed, isNull);
        retry.complete(_json({'ok': true, 'batch': _batch(active: true)}));
        await tester.pumpAndSettle();
        expect(find.text('Faol batch orderi: order-A'), findsOneWidget);
        expect(_picker(tester).disabled, isTrue);
        expect(retryButton, findsNothing);
        await tester.tap(find.text('To‘xtatish'));
        await tester.pumpAndSettle();
        expect(_picker(tester).disabled, isFalse);
        expect(starts, 1);
      },
      intercept: (request) async {
        if (request.url.path.endsWith('/rps/batch/state')) {
          stateRequests++;
          if (stateRequests == 2) {
            throw http.ClientException('Temporary state refresh failure');
          }
          if (stateRequests == 3) return retry.future;
          return _json({'ok': true, 'batch': _batch(active: false)});
        }
        if (request.url.path.endsWith('/rps/batch/start')) {
          starts++;
          return _json({'error': 'batch_already_active'}, status: 409);
        }
        if (request.url.path.endsWith('/rps/batch/stop')) {
          return _json({'ok': true, 'batch': _batch(active: false)});
        }
        return null;
      },
    );
  });

  testWidgets('HTTP 409 refresh preserves the other-order conflict message', (
    tester,
  ) async {
    await saveOperatorControlDraft(
      _draft(
        orderId: 'order-B',
        item: 'CPP',
        width: '510',
        micron: '20',
        length: '222',
        saved: true,
      ),
    );
    var stateRequests = 0;
    final starts = <Map<String, dynamic>>[];
    await _withApi(
      tester,
      () async {
        await tester.pumpWidget(
          _app(_ReceiptHarness(initialOrder: _orderB, useHttpState: true)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Boshlash'));
        await tester.pumpAndSettle();

        expect(starts, hasLength(1));
        expect(starts.single['order_id'], 'order-B');
        expect(starts.single['item_code'], 'CPP');
        expect(starts.single['apparatus'], 'pechat');
        expect(starts.single['warehouse'], 'Stores');
        expect(starts.single['width_mm'], 510);
        expect(starts.single['micron'], 20);
        expect(starts.single['length_m'], 222);
        expect(stateRequests, 2);
        expect(find.text('Faol batch orderi: order-A'), findsOneWidget);
        expect(_picker(tester).disabled, isTrue);
        const conflict =
            'Boshqa order uchun batch faol: order-A. Avval uni to‘xtating.';
        expect(find.text(conflict), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text(conflict), findsOneWidget);
      },
      intercept: (request) async {
        if (request.url.path.endsWith('/rps/batch/state')) {
          stateRequests++;
          return _json({
            'ok': true,
            'batch': _batch(active: stateRequests > 1),
          });
        }
        if (request.url.path.endsWith('/rps/batch/start')) {
          starts.add(_body(request));
          return _json({
            'error': 'batch_already_active',
            'detail': 'batch already active for order-A',
          }, status: 409);
        }
        return null;
      },
    );
  });
}

const _orderFieldKey = ValueKey('preparation-kirim-order-field');
final _orderA = _order('order-A', 'A', 'First order', 384);
final _orderB = _order('order-B', 'B', 'Second order', 500);

PreparationOrder _order(String id, String code, String title, int width) =>
    PreparationOrder.fromJson({
      'id': id,
      'code': code,
      'title': title,
      'order_kg': '100',
      'width_mm': width,
      'saved': false,
    });

void _setSession({List<String> assignedWarehouses = const ['Stores']}) {
  AppSession.instance.token = 'token';
  AppSession.instance.profile = SessionProfile(
    role: UserRole.materialTaminotchi,
    displayName: 'Materialchi',
    legalName: '',
    ref: 'material-order-tests',
    phone: '',
    avatarUrl: '',
    capabilities: const [
      'raw_material.assign',
      'gscale.catalog.read',
      'rps.batch.manage',
    ],
    assignedWarehouses: assignedWarehouses,
  );
}

OperatorControlDraft _draft({
  String orderId = 'order-A',
  String item = 'PET',
  String width = '390',
  String micron = '12',
  String length = '125',
  bool saved = false,
}) =>
    OperatorControlDraft(
      orderId: orderId,
      itemCode: item,
      itemName: item,
      itemRequiresDimensions: true,
      warehouse: 'Stores',
      printMode: 'label',
      printer: 'godex',
      quantitySource: 'manual',
      manualQtyText: '',
      manualDuplicateText: '',
      babinaEnabled: false,
      babinaText: '',
      warehouseMode: 'manual',
      defaultWarehouse: '',
      widthText: width,
      micronText: micron,
      lengthText: length,
      contextSaved: saved,
    );

Map<String, dynamic> _batch({required bool active}) => {
      'id': 'batch-A',
      'revision': 7,
      'active': active,
      'order_assignment': {'order_id': 'order-A', 'apparatus': 'pechat'},
      'driver_url': 'usb://local',
      'item_code': 'PET',
      'item_name': 'PET',
      'warehouse': 'Stores',
      'printer': 'godex',
      'print_mode': 'label',
      'quantity_source': 'manual',
      'manual_qty_kg': 0,
      'tare_enabled': false,
      'tare_kg': 0,
      'width_mm': 390,
      'micron': 12,
      'length_m': 125,
    };

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );

AdminOrderPickerField _picker(WidgetTester tester) =>
    tester.widget<AdminOrderPickerField>(find.byKey(_orderFieldKey));

String _field(WidgetTester tester, String label) => tester
    .widget<TextField>(find.widgetWithText(TextField, label))
    .controller!
    .text;

Map<String, dynamic> _body(http.Request request) =>
    (jsonDecode(request.body) as Map).cast<String, dynamic>();

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Future<void> _withApi(
  WidgetTester tester,
  Future<void> Function() body, {
  Future<http.Response?> Function(http.Request)? intercept,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1400));
  await http.runWithClient(
    () async {
      try {
        await body();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.binding.setSurfaceSize(null);
      }
    },
    () => MockClient((request) async {
      final override = await intercept?.call(request);
      if (override != null) return override;
      if (request.url.path.endsWith('/gscale/items')) {
        final codes = request.url.queryParameters['order_id'] == 'order-B'
            ? ['CPP', 'PP']
            : ['PET'];
        return _json([
          for (final code in codes)
            {
              'code': code,
              'name': code,
              'requires_dimensions': true,
              'order_microns': [code == 'PET' ? 12 : 20],
              'order_apparatus_options': {'pechat': 'Pechat'},
            },
        ]);
      }
      if (request.url.path.endsWith('/warehouses')) {
        return _json([
          {'warehouse': 'Stores'},
        ]);
      }
      throw StateError(
        'Unexpected mock request: ${request.method} ${request.url}',
      );
    }),
  );
}

class _ReceiptHarness extends StatefulWidget {
  const _ReceiptHarness({
    super.key,
    required this.initialOrder,
    this.stateLoader,
    this.onOrderChanged,
    this.useHttpState = false,
  });

  final PreparationOrder initialOrder;
  final Future<GScaleRpsBatchResponse> Function()? stateLoader;
  final ValueChanged<PreparationOrder?>? onOrderChanged;
  final bool useHttpState;

  @override
  State<_ReceiptHarness> createState() => _ReceiptHarnessState();
}

class _ReceiptHarnessState extends State<_ReceiptHarness> {
  late PreparationOrder selected = widget.initialOrder;

  void selectOrder(PreparationOrder order) => setState(() => selected = order);

  @override
  Widget build(BuildContext context) => OperatorDashboardPage(
        controlOnly: true,
        server: null,
        printTransport: PrintTransport.offline,
        offlinePrinter: const UsbPrinterProfile(
          kind: UsbPrinterKind.godex,
          deviceName: 'usb:test',
          vendorId: 1,
          productId: 2,
          manufacturerName: 'GoDEX',
          productName: 'G500',
        ),
        linkedOrderId: selected.id,
        linkedOrderWidthMm: selected.widthMm,
        onExitMode: () async {},
        onChangeServer: () async {},
        rpsBatchStateLoader: widget.useHttpState
            ? null
            : widget.stateLoader ??
                () async => GScaleRpsBatchResponse(
                      ok: true,
                      batch:
                          GScaleRpsBatchSession.fromJson(_batch(active: false)),
                    ),
        rpsBatchHistoryLoader: () async => const [],
        orderSectionBuilder: (disabled) => PreparationKirimOrderSection(
          key: ValueKey('order-section-${selected.id}'),
          initialOrder: selected,
          disabled: disabled,
          loadOrders: () async => [_orderA, _orderB],
          onOrderChanged: (order) {
            widget.onOrderChanged?.call(order);
            if (order != null && order.id != selected.id) selectOrder(order);
          },
        ),
      );
}
