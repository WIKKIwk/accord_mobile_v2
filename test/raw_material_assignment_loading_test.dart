import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/material_taminotchi/presentation/widgets/raw_material_order_assignment_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _assignKey = ValueKey('raw-material-assign-order-button');
const _retryKey = ValueKey('raw-material-assignment-retry');
const _shimmerKey = ValueKey('raw-material-assignment-loading-shimmer');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({'test_mode_enabled': false});
    AppSession.instance.token = 'synthetic-token';
  });
  tearDown(() => AppSession.instance.token = null);

  testWidgets(
      'candidate failure retains lookup and retry detects a new assignment',
      (tester) async {
    final lookup = Completer<http.Response>();
    var lookupReads = 0;
    var candidateReads = 0;
    var apparatusReads = 0;
    var recovering = false;
    await http.runWithClient(() async {
      await _open(tester);
      final before =
          tester.getSize(find.byType(RawMaterialOrderAssignmentSection));
      expect(find.byKey(_shimmerKey), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(_assignKey)).onPressed,
          isNull);
      lookup.complete(_json({'barcode': '30AA', 'assignment': null}));
      await _pumpReads(tester);
      expect(find.text('Ulanmagan'), findsOneWidget);
      expect(find.text('Xato'), findsNothing);
      expect(find.text('Mos buyurtmalar yuklanmadi'), findsOneWidget);
      expect(find.byKey(_retryKey), findsOneWidget);
      expect(tester.getSize(find.byType(RawMaterialOrderAssignmentSection)),
          before);
      expect(lookupReads, 1);
      expect(candidateReads, 2);
      expect(apparatusReads, 0);

      recovering = true;
      await tester.tap(find.byKey(_retryKey));
      await _pumpReads(tester);
      expect(lookupReads, 2);
      expect(candidateReads, 2);
      expect(find.byKey(_retryKey), findsNothing);
      expect(find.text('Ulangan'), findsOneWidget);
      expect(find.byKey(_assignKey), findsNothing);
      expect(find.byKey(const ValueKey('raw-material-unlink-button')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/lookup')) {
                lookupReads++;
                if (recovering) {
                  return _json({
                    'barcode': '30AA',
                    'assignment': {
                      'order_id': 'order-elsewhere',
                      'apparatus': 'apparatus:default:asset-005',
                      'barcode': '30AA',
                    },
                  });
                }
                return lookup.future;
              }
              if (request.url.path.endsWith('/candidate-orders')) {
                candidateReads++;
                return recovering
                    ? _json([])
                    : _json({'error': 'unavailable'}, 503);
              }
              apparatusReads++;
              return _json([]);
            }));
  });

  testWidgets('linked material can be unlinked even when optional names fail',
      (tester) async {
    final names = Completer<http.Response>();
    var apparatusReads = 0;
    await http.runWithClient(() async {
      await _open(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Ulangan'), findsOneWidget);
      final unlink = find.byKey(const ValueKey('raw-material-unlink-button'));
      expect(tester.widget<OutlinedButton>(unlink).onPressed, isNotNull);
      expect(find.text('ORD-1 · Buyurtma A'), findsOneWidget);
      names.complete(_json({'error': 'unavailable'}, 503));
      await _pumpReads(tester);
      expect(apparatusReads, 2);
      expect(find.text('Ulangan'), findsOneWidget);
      expect(find.byKey(_retryKey), findsNothing);
      expect(tester.widget<OutlinedButton>(unlink).onPressed, isNotNull);
      expect(find.text('apparatus:default:asset-005'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/lookup')) {
                return _json({
                  'barcode': '30AA',
                  'assignment': {
                    'barcode': '30AA',
                    'order_id': 'order-1',
                    'apparatus': 'apparatus:default:asset-005'
                  },
                  'order': {
                    'id': 'order-1',
                    'code': 'ORD-1',
                    'title': 'Buyurtma A'
                  },
                });
              }
              expect(request.url.path.endsWith('/apparatus'), isTrue);
              apparatusReads++;
              return names.future;
            }));
  });

  testWidgets('eligibility stays disabled until candidates are verified',
      (tester) async {
    final candidates = Completer<http.Response>();
    await http.runWithClient(() async {
      await _open(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Ulanmagan'), findsOneWidget);
      expect(find.byKey(_shimmerKey), findsOneWidget);
      final assign = find.byKey(_assignKey);
      expect(tester.widget<FilledButton>(assign).onPressed, isNull);
      candidates.complete(_json([
        {
          'order': {
            'map': {'id': 'order-1', 'title': 'Buyurtma A'},
            'program': {}
          },
          'apparatus_options': ['apparatus:default:asset-005'],
        }
      ]));
      await _pumpReads(tester);
      expect(find.byKey(_shimmerKey), findsNothing);
      expect(tester.widget<FilledButton>(assign).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/lookup')) {
                return _json({'barcode': '30AA'});
              }
              expect(request.url.path.endsWith('/candidate-orders'), isTrue);
              return candidates.future;
            }));
  });
}

http.Response _json(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status,
        headers: {'content-type': 'application/json'});

Future<void> _open(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(
    locale: Locale('uz'),
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
        body: Center(
            child: SizedBox(
                width: 350,
                child: RawMaterialOrderAssignmentSection(
                    barcode: '30AA', allowAssignment: true)))),
  ));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _pumpReads(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
