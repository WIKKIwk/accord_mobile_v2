import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/raw_material_scan_dialog.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_paddon_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _roll(String id,
        {String status = 'waiting', bool received = false}) =>
    {
      'batch_id': id,
      'apparatus': 'apparatus:default:asset-010',
      'qr_payload': 'QR-$id',
      'order_id': 'order-$id',
      'wip_status': status,
      'worker_ref': 'other-worker',
      'produced_qty': 10,
      'uom': 'm',
      'payload_json': {
        'order_number': id,
        'order_title': 'Paket $id',
        if (received) 'received_warehouse': 'warehouse-1',
      },
    };

Map<String, dynamic> _payload(
        {List<String> added = const [],
        bool editable = true,
        bool locked = false}) =>
    {
      'paddon': {
        'id': 'paddon-1',
        'code': '00001',
        'item_count': 1 + added.length,
        'total_gross_kg': 10 + added.length * 10,
        'total_net_kg': 9 + added.length * 9,
        if (locked) 'locked_at_unix': 1,
      },
      'items': [_roll('existing'), for (final id in added) _roll(id)],
      'can_manage_items': editable,
      'free_movement_enabled': locked && editable,
    };

void _session(String ref) {
  AppSession.instance.token = 'scan-token-$ref';
  AppSession.instance.profile = SessionProfile(
    role: UserRole.aparatchi,
    ref: ref,
    displayName: ref,
    legalName: '',
    phone: '',
    avatarUrl: '',
    capabilities: const ['apparatus.queue.read', 'apparatus.queue.manage'],
    assignedApparatus: const ['apparatus:default:asset-010'],
  );
}

Future<void> _openScanner(WidgetTester tester,
    {Map<String, dynamic>? initial}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1100));
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('uz'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: AparatchiPaddonDetailScreen(
      code: '00001',
      apparatus: const [],
      loader: () async => AdminPaddonSnapshot.fromJson(initial ?? _payload()),
    ),
  ));
  await tester.pumpAndSettle();
  await _startScanner(tester);
}

Future<void> _startScanner(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('app-primary-navigation-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('WIP QR scan qilib qo‘shish'));
  await tester.pumpAndSettle();
}

ProductionQuickScannerPanel _scanner(WidgetTester tester) =>
    tester.widget<ProductionQuickScannerPanel>(
        find.byType(ProductionQuickScannerPanel));

Future<void> _confirm(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('paddon-scan-confirm'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await tester.binding.setSurfaceSize(null);
  debugDefaultTargetPlatformOverride = null;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    _session('worker-1');
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets(
      'inline scanner stages unique rolls and confirms one bulk request',
      (tester) async {
    var writes = 0;
    final lookups = <String>[];
    await http.runWithClient(() async {
      await _openScanner(tester);
      expect(find.text('Qo‘shilayotganlar: 0 ta'), findsOneWidget);
      final scan = _scanner(tester).onCodeDetected;
      await Future.wait(
          [scan('A'), scan('B'), scan('A'), scan('alias-A'), scan('existing')]);
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(lookups, ['A', 'B', 'alias-A', 'existing']);
      expect(find.text('Qo‘shilayotganlar: 2 ta'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('paddon-scanned-wip-A')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('paddon-scanned-wip-B')), findsOneWidget);
      expect(find.text('Jami brutto: 10 kg'), findsOneWidget);
      expect(find.byKey(const ValueKey('paddon-wip-card-A')), findsNothing);
      await _confirm(tester);
      expect(writes, 1);
      expect(find.byType(ProductionQuickScannerPanel), findsNothing);
      expect(
          find.byKey(const ValueKey('paddon-scanned-wip-list')), findsNothing);
      expect(find.byKey(const ValueKey('paddon-wip-card-A')), findsOneWidget);
      expect(find.byKey(const ValueKey('paddon-wip-card-B')), findsOneWidget);
      expect(find.text('Jami brutto: 30 kg'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _dispose(tester);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/progress-qr/lookup')) {
                final qr = jsonDecode(request.body)['qr_payload'] as String;
                lookups.add(qr);
                return http.Response(
                    jsonEncode({'batch': _roll(qr == 'alias-A' ? 'A' : qr)}),
                    200);
              }
              expect(request.url.path,
                  '/v1/mobile/admin/production-maps/paddons/items/add-batch');
              expect(jsonDecode(request.body), {
                'code': '00001',
                'progress_batch_ids': ['A', 'B']
              });
              writes++;
              return http.Response(
                  jsonEncode(_payload(added: ['A', 'B'])), 200);
            }));
  });

  testWidgets('each scanned roll appears in the list below the scanner',
      (tester) async {
    await http.runWithClient(() async {
      await _openScanner(tester);
      expect(
          find.byKey(const ValueKey('paddon-scanned-wip-list')), findsNothing);
      await _scanner(tester).onCodeDetected('A');
      await tester.pumpAndSettle();
      final cardA = find.byKey(const ValueKey('paddon-scanned-wip-A'));
      expect(cardA, findsOneWidget);
      expect(find.descendant(of: cardA, matching: find.textContaining('QR-A')),
          findsOneWidget);
      expect(
          tester.getTopLeft(cardA).dy,
          greaterThan(tester
              .getBottomLeft(find.byType(ProductionQuickScannerPanel))
              .dy));
      await _scanner(tester).onCodeDetected('B');
      await _scanner(tester).onCodeDetected('A');
      await tester.pumpAndSettle();
      final list = find.byKey(const ValueKey('paddon-scanned-wip-list'));
      expect(
          find.descendant(
              of: list,
              matching: find.byWidgetPredicate((widget) =>
                  widget.key == const ValueKey('paddon-scanned-wip-A') ||
                  widget.key == const ValueKey('paddon-scanned-wip-B'))),
          findsNWidgets(2));
      expect(find.byKey(const ValueKey('paddon-wip-card-A')), findsNothing);
      expect(find.text('Jami brutto: 10 kg'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _dispose(tester);
    },
        () => MockClient((request) async {
              expect(request.url.path.endsWith('/progress-qr/lookup'), isTrue);
              return http.Response(
                  jsonEncode({
                    'batch': _roll(jsonDecode(request.body)['qr_payload']),
                  }),
                  200);
            }));
  });

  testWidgets(
      'fast scans remain queued and confirmation waits for every lookup',
      (tester) async {
    final first = Completer<http.Response>();
    final started = Completer<void>();
    final lookups = <String>[];
    await http.runWithClient(() async {
      await _openScanner(tester);
      final scan = _scanner(tester).onCodeDetected;
      final a = scan('A');
      final b = scan('B');
      await started.future;
      await tester.pump();
      expect(lookups, ['A']);
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('paddon-scan-confirm')))
              .onPressed,
          isNull);
      first.complete(http.Response(jsonEncode({'batch': _roll('A')}), 200));
      await Future.wait([a, b]);
      await tester.pumpAndSettle();
      expect(lookups, ['A', 'B']);
      expect(find.text('Qo‘shilayotganlar: 2 ta'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('paddon-scan-confirm')))
              .onPressed,
          isNotNull);
      await _dispose(tester);
    },
        () => MockClient((request) async {
              expect(request.url.path.endsWith('/progress-qr/lookup'), isTrue);
              final qr = jsonDecode(request.body)['qr_payload'] as String;
              lookups.add(qr);
              if (qr == 'A') started.complete();
              return qr == 'A'
                  ? first.future
                  : http.Response(jsonEncode({'batch': _roll(qr)}), 200);
            }));
  });

  testWidgets('pending dialog removes a roll and confirms the remaining list',
      (tester) async {
    var writes = 0;
    await http.runWithClient(() async {
      await _openScanner(tester);
      await _scanner(tester).onCodeDetected('A');
      await _scanner(tester).onCodeDetected('B');
      await tester.pumpAndSettle();
      final pending = find.byKey(const ValueKey('paddon-pending-scans'));
      await tester.ensureVisible(pending);
      await tester.tap(pending);
      await tester.pumpAndSettle();
      expect(find.byType(ProductionQuickScannerPanel), findsNothing);
      await tester.tap(find.byKey(const ValueKey('paddon-pending-wip-A')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paddon-pending-wip-A')), findsNothing);
      expect(writes, 0);
      await tester
          .tap(find.byKey(const ValueKey('paddon-scan-review-confirm')));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.byKey(const ValueKey('paddon-wip-card-A')), findsNothing);
      expect(find.byKey(const ValueKey('paddon-wip-card-B')), findsOneWidget);
      await _dispose(tester);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/progress-qr/lookup')) {
                return http.Response(
                    jsonEncode({
                      'batch': _roll(jsonDecode(request.body)['qr_payload'])
                    }),
                    200);
              }
              writes++;
              expect(jsonDecode(request.body)['progress_batch_ids'], ['B']);
              return http.Response(jsonEncode(_payload(added: ['B'])), 200);
            }));
  });

  testWidgets('failed save preserves the pending list for retry',
      (tester) async {
    var writes = 0;
    await http.runWithClient(() async {
      await _openScanner(tester);
      await _scanner(tester).onCodeDetected('A');
      await tester.pumpAndSettle();
      await _confirm(tester);
      expect(writes, 1);
      expect(find.text('Qo‘shilayotganlar: 1 ta'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('paddon-scanned-wip-A')), findsOneWidget);
      expect(find.byType(ProductionQuickScannerPanel), findsOneWidget);
      expect(find.text('Jami brutto: 10 kg'), findsOneWidget);
      await _confirm(tester);
      expect(writes, 2);
      expect(find.byKey(const ValueKey('paddon-wip-card-A')), findsOneWidget);
      await _dispose(tester);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/progress-qr/lookup')) {
                return http.Response(jsonEncode({'batch': _roll('A')}), 200);
              }
              expect(jsonDecode(request.body)['progress_batch_ids'], ['A']);
              writes++;
              return writes == 1
                  ? http.Response(
                      jsonEncode({'error': 'paddon_item_already_assigned'}),
                      409)
                  : http.Response(jsonEncode(_payload(added: ['A'])), 200);
            }));
  });

  testWidgets(
      'processed, received and unknown rolls never enter pending additions',
      (tester) async {
    await http.runWithClient(() async {
      await _openScanner(tester);
      final scan = _scanner(tester).onCodeDetected;
      await scan('processed');
      await scan('received');
      await scan('unknown');
      await tester.pumpAndSettle();
      expect(find.text('Qo‘shilayotganlar: 0 ta'), findsOneWidget);
      expect(_scanner(tester).feedback, ProductionQuickScanFeedback.rejected);
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('paddon-scan-confirm')))
              .onPressed,
          isNull);
      await _dispose(tester);
    },
        () => MockClient((request) async {
              expect(request.url.path.endsWith('/progress-qr/lookup'), isTrue);
              final qr = jsonDecode(request.body)['qr_payload'];
              if (qr == 'unknown') return http.Response('Not found', 404);
              return http.Response(
                  jsonEncode({
                    'batch': _roll(qr,
                        status: qr == 'processed' ? 'processed' : 'waiting',
                        received: qr == 'received')
                  }),
                  200);
            }));
  });

  testWidgets('discard cancels pending lookup results without adding anything',
      (tester) async {
    final lookup = Completer<http.Response>();
    final started = Completer<void>();
    await http.runWithClient(() async {
      await _openScanner(tester);
      final scan = _scanner(tester).onCodeDetected('A');
      await started.future;
      await tester.pump();
      final close = find.byKey(const ValueKey('paddon-scan-close'));
      await tester.ensureVisible(close);
      await tester.tap(close);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('paddon-scan-discard-confirm')));
      await tester.pumpAndSettle();
      lookup.complete(http.Response(jsonEncode({'batch': _roll('A')}), 200));
      await scan;
      await tester.pumpAndSettle();
      expect(find.byType(ProductionQuickScannerPanel), findsNothing);
      expect(find.byKey(const ValueKey('paddon-wip-card-A')), findsNothing);
      await _startScanner(tester);
      expect(find.text('Qo‘shilayotganlar: 0 ta'), findsOneWidget);
      await _dispose(tester);
    },
        () => MockClient((request) {
              expect(request.url.path.endsWith('/progress-qr/lookup'), isTrue);
              started.complete();
              return lookup.future;
            }));
  });

  testWidgets('lookup completion from a previous session is ignored',
      (tester) async {
    final lookup = Completer<http.Response>();
    final started = Completer<void>();
    await http.runWithClient(() async {
      await _openScanner(tester);
      final scan = _scanner(tester).onCodeDetected('A');
      await started.future;
      await tester.pump();
      _session('worker-2');
      lookup.complete(http.Response(jsonEncode({'batch': _roll('A')}), 200));
      await scan;
      await tester.pumpAndSettle();
      expect(find.text('Qo‘shilayotganlar: 0 ta'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('paddon-scan-confirm')))
              .onPressed,
          isNull);
      await _dispose(tester);
    },
        () => MockClient((request) {
              started.complete();
              return lookup.future;
            }));
  });

  for (final editable in [false, true]) {
    testWidgets(
        'printed paddon scanner respects server edit permission: $editable',
        (tester) async {
      await _openScanner(tester,
          initial: _payload(editable: editable, locked: true));
      expect(find.byType(ProductionQuickScannerPanel),
          editable ? findsOneWidget : findsNothing);
      await _dispose(tester);
    });
  }
}
