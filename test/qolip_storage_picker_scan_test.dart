import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/core/widgets/paddon_widgets.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/raw_material_scan_dialog.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_catalog_search_field.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_storage_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _mold(String code) => {
      'qolip_code': code,
      'qolip_set_id': '9501',
      'warehouse': 'Qolip ombori',
      'item_name': 'Shared mold',
      'size': 40,
      'quantity': 1,
    };
Map<String, dynamic> _detail([List<String> codes = const []]) => {
      'ok': true,
      'paddon': {
        'code': 'QP-00012',
        'warehouse': 'Qolip ombori',
        'locked': false,
        'archived': false,
        'revision': codes.isEmpty ? 4 : 5,
        'item_count': codes.length,
      },
      'items': codes.map(_mold).toList(),
      'history': [],
    };
http.Response _json(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});
http.Response _molds(List<Map<String, dynamic>> molds) =>
    _json({'ok': true, 'molds': molds});

void _session(String ref) {
  AppSession.instance.token = 'scan-$ref';
  AppSession.instance.profile = SessionProfile(
    role: UserRole.qolipchi,
    ref: ref,
    displayName: ref,
    legalName: '',
    phone: '',
    avatarUrl: '',
    capabilities: const ['qolip.manage'],
    assignedWarehouses: const ['Qolip ombori'],
  );
  AppSession.instance.revision.value++;
}

Future<void> _openPicker(WidgetTester tester,
    {bool scan = true,
    Locale locale = const Locale('en'),
    Size size = const Size(390, 1000),
    ThemeData? theme}) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    theme: theme,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const QolipPaddonScreen(code: 'QP-00012'),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('app-primary-navigation-button')));
  await tester.pumpAndSettle();
  final action = locale.languageCode == 'uz'
      ? (scan ? 'QR skanerlash orqali qo‘shish' : 'Qolip qo‘shish')
      : (scan ? 'Add by scanning QR' : 'Add molds');
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

ProductionQuickScannerPanel _scanner(WidgetTester tester) =>
    tester.widget<ProductionQuickScannerPanel>(
        find.byType(ProductionQuickScannerPanel));
Finder get _confirm => find.byKey(const ValueKey('qolip-picker-confirm'));
Finder _card(String code) => find.byKey(ValueKey('qolip-scanned-mold-$code'));

Future<void> _confirmSelection(WidgetTester tester) async {
  await tester.tap(_confirm);
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
  await tester.pumpAndSettle();
}

void _pickerTest(String description, WidgetTesterCallback body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(null);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ServerEndpointStore.instance.clearOverride();
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    _session('worker');
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    QolipCatalogStore.instance.reset();
  });

  _pickerTest(
      'compact QR button aligns with the counter and product rows expand without arrows',
      (tester) async {
    final font = FontLoader(AppTheme.fontFamily)
      ..addFont(rootBundle.load('assets/fonts/google_sans/GoogleSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/google_sans/GoogleSans-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/google_sans/GoogleSans-Bold.ttf'));
    await font.load();
    await http.runWithClient(() async {
      await _openPicker(tester,
          scan: false,
          locale: const Locale('uz'),
          size: const Size(360, 780),
          theme: AppTheme.light());
      final summary = find.byKey(const ValueKey('qolip-picker-summary'));
      final metric = find.descendant(
          of: summary, matching: find.byType(PaddonMetric));
      final toggle = find.byKey(const ValueKey('qolip-picker-scan-toggle'));
      final metricRect = tester.getRect(metric);
      final toggleRect = tester.getRect(toggle);
      expect(find.text('QR skanerlash orqali'), findsOneWidget);
      expect(toggleRect.left, greaterThanOrEqualTo(metricRect.right));
      expect(toggleRect.center.dy, closeTo(metricRect.center.dy, 1));
      expect(toggleRect.height, closeTo(metricRect.height, 1));
      expect(toggleRect.right, lessThanOrEqualTo(tester.getRect(summary).right));
      final label = find.descendant(
          of: toggle, matching: find.text('QR skanerlash orqali'));
      expect(tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
          isFalse);
      await tester.binding.setSurfaceSize(const Size(320, 780));
      await tester.pumpAndSettle();
      expect(tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
          isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byType(ProductionQuickScannerPanel), findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byType(ProductionQuickScannerPanel), findsNothing);
      final product = find.byKey(const ValueKey('qolip-picker-product-unlinked'));
      final arrow = find.descendant(
          of: product, matching: find.byIcon(Icons.keyboard_arrow_down_rounded));
      expect(arrow, findsNothing);
      final expand = find.byKey(
          const ValueKey('qolip-picker-product-expand-unlinked'));
      await tester.ensureVisible(expand);
      await tester.tap(expand);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('qolip-picker-mold-M-A')), findsOneWidget);
      expect(arrow, findsNothing);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async {
          if (request.url.path.endsWith('/paddons/molds')) {
            return _molds([_mold('M-A')]);
          }
          return _json(_detail());
        }));
  });

  _pickerTest(
      'continuous scanner stages unique opaque codes before one reviewed write',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lookups = <String>[];
    final writes = <Map<String, dynamic>>[];
    final added = <String>[];
    await http.runWithClient(() async {
      await _openPicker(tester);
      expect(_scanner(tester).allowConcurrentDetections, isTrue);
      final scan = _scanner(tester).onCodeDetected;
      await Future.wait([
        scan('M-A'),
        scan('Milano Premium 30/40'),
        scan('m-a'),
        scan('https://erp.example/scan?qr=Milano%20Premium%2030%2F40'),
      ]);
      await tester.pumpAndSettle();
      expect(lookups, ['M-A', 'Milano Premium 30/40']);
      expect(writes, isEmpty);
      expect(_card('M-A'), findsOneWidget);
      expect(_card('Milano Premium 30/40'), findsOneWidget);
      expect(find.text('Confirm (2)'), findsOneWidget);
      await _confirmSelection(tester);
      expect(writes.length, 1);
      expect(writes.single['action'], 'add');
      expect(writes.single['expected_revision'], 4);
      expect(writes.single['qolip_codes'], ['M-A', 'Milano Premium 30/40']);
      expect(writes.single['request_id'], isNotEmpty);
      expect(find.byType(ProductionQuickScannerPanel), findsNothing);
      final product =
          find.byKey(const ValueKey('qolip-paddon-product-expand-unlinked'));
      await tester.ensureVisible(product);
      await tester.pumpAndSettle();
      await tester.tap(product);
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('qolip-paddon-mold-M-A')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/paddons/molds')) {
                final code = request.url.queryParameters['code'];
                if (code == null) return _molds([]);
                lookups.add(code);
                return _molds([_mold(code)]);
              }
              if (request.method == 'POST') {
                writes.add(
                    Map<String, dynamic>.from(jsonDecode(request.body) as Map));
                added.addAll(List<String>.from(writes.single['qolip_codes']));
              }
              return _json(_detail(added));
            }));
  });

  _pickerTest(
      'rapid scans wait in order and confirmation waits for all lookups',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final first = Completer<http.Response>();
    final started = Completer<void>();
    final lookups = <String>[];
    await http.runWithClient(() async {
      await _openPicker(tester);
      final scan = _scanner(tester).onCodeDetected;
      final a = scan('M-A');
      final b = scan('M-B');
      await started.future;
      await tester.pump();
      expect(lookups, ['M-A']);
      expect(tester.widget<FloatingActionButton>(_confirm).onPressed, isNull);
      first.complete(_molds([_mold('M-A')]));
      await Future.wait([a, b]);
      await tester.pumpAndSettle();
      expect(lookups, ['M-A', 'M-B']);
      expect(find.text('Confirm (2)'), findsOneWidget);
      expect(tester.widget<FloatingActionButton>(_confirm).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (!request.url.path.endsWith('/paddons/molds')) {
                return _json(_detail());
              }
              expect(request.method, 'GET');
              final code = request.url.queryParameters['code'];
              if (code == null) return _molds([]);
              lookups.add(code);
              if (code == 'M-A') {
                started.complete();
                return first.future;
              }
              return _molds([_mold(code)]);
            }));
  });

  _pickerTest(
      'blocked molds and invalid scans are rejected without poisoning the queue',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final blocked = <String, Map<String, dynamic>>{
      'USED': {'is_in_use': true},
      'REWORK': {'is_in_rework': true},
      'ARCHIVED': {'archived': true},
      'PACKED': {'paddon_code': 'QP-00013'},
      'TRANSFER': {'is_transferring': true},
      'CUSTODY': {'is_custody_mismatch': true},
      'FOREIGN': {'warehouse': 'Other warehouse'},
    };
    final lookups = <String>[];
    await http.runWithClient(() async {
      await _openPicker(tester);
      final scan = _scanner(tester).onCodeDetected;
      for (final code in [
        ...blocked.keys,
        'UNKNOWN',
        'NETWORK',
        'MALFORMED',
        'WRONG-CODE',
        'qolip-paddon:QP-00012',
        'https://erp.example/scan?qr=%FF'
      ]) {
        await scan(code);
        await tester.pumpAndSettle();
        expect(_scanner(tester).feedback, ProductionQuickScanFeedback.rejected);
        expect(find.text('Confirm (0)'), findsOneWidget);
      }
      expect(lookups, isNot(contains('qolip-paddon:QP-00012')));
      await scan('QP-00012'); // An opaque mold code can equal a pallet number.
      await tester.pumpAndSettle();
      expect(_card('QP-00012'), findsOneWidget);
      expect(find.text('Confirm (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              expect(request.method, 'GET');
              if (!request.url.path.endsWith('/paddons/molds')) {
                return _json(_detail());
              }
              final code = request.url.queryParameters['code'];
              if (code == null) return _molds([]);
              lookups.add(code);
              if (code == 'UNKNOWN') return _molds([]);
              if (code == 'NETWORK') {
                return _json({'error': 'temporary_failure'}, 500);
              }
              if (code == 'MALFORMED') return _json({'ok': true});
              if (code == 'WRONG-CODE') return _molds([_mold('OTHER')]);
              return _molds([
                {..._mold(code), ...?blocked[code]}
              ]);
            }));
  });

  _pickerTest(
      'inline scanner keeps the list and synchronizes checked selections',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final writes = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await _openPicker(tester, scan: false);
      await tester.ensureVisible(find.byKey(
          const ValueKey('qolip-picker-product-expand-unlinked')));
      await tester.tap(find.byKey(
          const ValueKey('qolip-picker-product-expand-unlinked')));
      await tester.pumpAndSettle();
      final a = find.byKey(const ValueKey('qolip-picker-mold-M-A'));
      await tester.ensureVisible(a);
      await tester.tap(a);
      await tester.pumpAndSettle();
      final input = find.descendant(
          of: find.byType(AdminCatalogSearchField),
          matching: find.byType(EditableText));
      final focus = tester.widget<EditableText>(input).focusNode;
      await tester.tap(input);
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      final toggle = find.byKey(const ValueKey('qolip-picker-scan-toggle'));
      expect(find.byType(SegmentedButton<bool>), findsNothing);
      expect(find.byType(ProductionQuickScannerPanel), findsNothing);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byType(AdminCatalogSearchField), findsOneWidget);
      expect(find.byKey(const ValueKey('qolip-picker-products')), findsOneWidget);
      expect(focus.hasFocus, isFalse);
      await _scanner(tester).onCodeDetected('M-A');
      await _scanner(tester).onCodeDetected('M-B');
      await tester.pumpAndSettle();
      expect(find.text('Confirm (2)'), findsOneWidget);
      final scannedCheckbox = find.byKey(
          const ValueKey('qolip-scanned-mold-select-M-B'));
      expect(tester.widget<Checkbox>(scannedCheckbox).value, isTrue);
      expect(tester.getTopLeft(_card('M-B')).dy,
          lessThan(tester.getTopLeft(_card('M-A')).dy));
      final remove = find.byKey(
          const ValueKey('qolip-scanned-mold-select-M-A'));
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(find.text('Confirm (1)'), findsOneWidget);
      expect(_card('M-A'), findsNothing);
      expect(_scanner(tester).statusText, 'Scan a mold QR code');
      await tester.drag(find.byKey(const ValueKey('qolip-picker-list')),
          const Offset(0, 600));
      await tester.pumpAndSettle();
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byType(ProductionQuickScannerPanel), findsNothing);
      await tester.drag(find.byKey(const ValueKey('qolip-picker-list')),
          const Offset(0, -350));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('qolip-picker-mold-M-B'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      final rowCheckbox =
          find.descendant(of: row, matching: find.byType(Checkbox));
      expect(tester.widget<Checkbox>(rowCheckbox).value, isTrue);
      await _confirmSelection(tester);
      expect(writes.single['qolip_codes'], ['M-B']);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/paddons/molds')) {
                final code = request.url.queryParameters['code'];
                return _molds(
                    [if (code == null) _mold('M-A'), _mold(code ?? 'M-B')]);
              }
              if (request.method == 'POST') {
                writes.add(
                    Map<String, dynamic>.from(jsonDecode(request.body) as Map));
              }
              return _json(_detail(writes.isEmpty ? [] : ['M-B']));
            }));
  });

  _pickerTest(
      'a scan stays selected when an earlier list request finishes later',
      (tester) async {
    final pendingList = Completer<http.Response>();
    final listStarted = Completer<void>();
    await http.runWithClient(() async {
      await _openPicker(tester, scan: false);
      final input = find.descendant(
          of: find.byType(AdminCatalogSearchField),
          matching: find.byType(EditableText));
      await tester.enterText(input, 'M-B');
      await tester.pump(const Duration(milliseconds: 350));
      await listStarted.future;
      final toggle = find.byKey(const ValueKey('qolip-picker-scan-toggle'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
      await _scanner(tester).onCodeDetected('M-B');
      pendingList.complete(_molds([
        {..._mold('M-B'), 'is_in_use': true}
      ]));
      await tester.pumpAndSettle();
      expect(_card('M-B'), findsOneWidget);
      expect(find.text('Confirm (1)'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byKey(
          const ValueKey('qolip-scanned-mold-select-M-B'))).value, isTrue);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async {
          if (!request.url.path.endsWith('/paddons/molds')) {
            return _json(_detail());
          }
          final code = request.url.queryParameters['code'];
          if (code != null) return _molds([_mold(code)]);
          if (request.url.queryParameters['q'] == 'M-B') {
            listStarted.complete();
            return pendingList.future;
          }
          return _molds([]);
        }));
  });

  _pickerTest(
      'a scan stays selected when a product lookup finishes later',
      (tester) async {
    final pendingProduct = Completer<http.Response>();
    final productStarted = Completer<void>();
    var listReads = 0;
    await http.runWithClient(() async {
      await _openPicker(tester, scan: false);
      await tester.tap(find.byKey(const ValueKey('qolip-picker-scan-toggle')));
      await tester.pumpAndSettle();
      final scan = _scanner(tester).onCodeDetected;
      final product = find.byKey(
          const ValueKey('qolip-picker-product-expand-unlinked'));
      await tester.ensureVisible(product);
      await tester.tap(product);
      await tester.pump();
      await productStarted.future;
      await scan('M-B');
      pendingProduct.complete(_molds([
        _mold('M-A'),
        {..._mold('M-B'), 'is_in_use': true}
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Confirm (1)'), findsOneWidget);
      final row = find.byKey(const ValueKey('qolip-picker-mold-M-B'));
      await tester.ensureVisible(row);
      final checked = find.descendant(of: row, matching: find.byType(Checkbox));
      expect(tester.widget<Checkbox>(checked).value, isTrue);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async {
          if (!request.url.path.endsWith('/paddons/molds')) {
            return _json(_detail());
          }
          final code = request.url.queryParameters['code'];
          if (code != null) return _molds([_mold(code)]);
          if (++listReads == 1) return _molds([_mold('M-A')]);
          productStarted.complete();
          return pendingProduct.future;
        }));
  });

  _pickerTest(
      'leaving scan mode discards late lookup results from its earlier session',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final first = Completer<http.Response>();
    final started = Completer<void>();
    await http.runWithClient(() async {
      await _openPicker(tester);
      final pending = _scanner(tester).onCodeDetected('M-A');
      await started.future;
      await tester.pump();
      final toggle = find.byKey(const ValueKey('qolip-picker-scan-toggle'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byType(ProductionQuickScannerPanel), findsNothing);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await _scanner(tester).onCodeDetected('M-B');
      first.complete(_molds([_mold('M-A')]));
      await pending;
      await tester.pumpAndSettle();
      expect(_card('M-A'), findsNothing);
      expect(_card('M-B'), findsOneWidget);
      expect(find.text('Confirm (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              expect(request.method, 'GET');
              if (!request.url.path.endsWith('/paddons/molds')) {
                return _json(_detail());
              }
              final code = request.url.queryParameters['code'];
              if (code == 'M-A') {
                started.complete();
                return first.future;
              }
              return _molds([if (code != null) _mold(code)]);
            }));
  });

  _pickerTest('account switch hides selected molds and rejects late scans',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    final lookups = <String>[];
    await http.runWithClient(() async {
      await _openPicker(tester);
      final scan = _scanner(tester).onCodeDetected;
      await scan('M-A');
      final b = scan('M-B');
      await started.future;
      _session('other-worker');
      pending.complete(_molds([_mold('M-B')]));
      await b;
      await tester.pumpAndSettle();
      await scan('M-C');
      expect(find.byType(ProductionQuickScannerPanel), findsNothing);
      expect(_card('M-A'), findsNothing);
      expect(_card('M-B'), findsNothing);
      expect(lookups, ['M-A', 'M-B']);
      expect(find.textContaining('Account or permissions changed'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              expect(request.method, 'GET');
              if (!request.url.path.endsWith('/paddons/molds')) {
                return _json(_detail());
              }
              final code = request.url.queryParameters['code'];
              if (code == null) return _molds([]);
              lookups.add(code);
              if (code == 'M-B') {
                started.complete();
                return pending.future;
              }
              return _molds([_mold(code)]);
            }));
  });

  _pickerTest(
      'scanner pauses behind mold details and leaving requires discard confirmation',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lookups = <String>[];
    await http.runWithClient(() async {
      await _openPicker(tester);
      final scan = _scanner(tester).onCodeDetected;
      await scan('M-A');
      await tester.pumpAndSettle();
      await tester.ensureVisible(_card('M-A'));
      await tester.pumpAndSettle();
      await tester.tap(_card('M-A'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductionQuickScannerPanel), findsNothing);
      await scan('M-B');
      expect(lookups, ['M-A']);
      final navigator =
          tester.state<NavigatorState>(find.byType(Navigator).first);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ProductionQuickScannerPanel), findsOneWidget);
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Discard the unsaved selection?'), findsOneWidget);
      expect(find.byType(ProductionQuickScannerPanel), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm (1)'), findsOneWidget);
      expect(find.byType(ProductionQuickScannerPanel), findsOneWidget);
      await navigator.maybePop();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('qolip-picker-confirm')), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              expect(request.method, 'GET');
              if (!request.url.path.endsWith('/paddons/molds')) {
                return _json(_detail());
              }
              final code = request.url.queryParameters['code'];
              if (code == null) return _molds([]);
              lookups.add(code);
              return _molds([_mold(code)]);
            }));
  });

  _pickerTest('canceling dock navigation resumes a pending scan', (tester) async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    await http.runWithClient(() async {
      await _openPicker(tester);
      final scan = _scanner(tester).onCodeDetected;
      await scan('M-A');
      await tester.pumpAndSettle();
      final lookup = scan('M-B');
      await started.future;
      await tester.pump();
      await tester.tap(find.descendant(
          of: find.byType(NavigationBar), matching: find.text('Chat')));
      await tester.pump();
      expect(find.text('Discard the unsaved selection?'), findsOneWidget);
      pending.complete(_molds([_mold('M-B')]));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pump();
      await lookup;
      await tester.pumpAndSettle();
      expect(find.text('Confirm (2)'), findsOneWidget);
      expect(_card('M-A'), findsOneWidget);
      expect(_card('M-B'), findsOneWidget);
    }, () => MockClient((request) async {
          if (!request.url.path.endsWith('/paddons/molds')) {
            return _json(_detail());
          }
          final code = request.url.queryParameters['code'];
          if (code == null) return _molds([]);
          if (code == 'M-B') {
            started.complete();
            return pending.future;
          }
          return _molds([_mold(code)]);
        }));
  });
}
