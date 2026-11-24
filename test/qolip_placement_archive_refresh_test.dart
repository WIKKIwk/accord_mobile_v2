import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_home_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Map<String, Object?> body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  testWidgets('open placement search drops a remotely archived mold',
      (tester) async {
    tester.view.physicalSize = const Size(950, 1300);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'placement-archive-test';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      ref: 'placement-archive-test',
      displayName: 'Qolipchi',
      legalName: '',
      phone: '',
      avatarUrl: '',
      capabilities: ['qolip.manage'],
      assignedWarehouses: ['Molds A'],
    );
    AppSession.instance.revision.value++;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      AppSession.instance.token = null;
      AppSession.instance.profile = null;
      AppSession.instance.revision.value++;
    });

    final watch = <String, Completer<http.Response>>{};
    var revision = 'test.0';
    var isArchived = false;
    var placementReads = 0;
    var locationReads = 0;

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: QolipHomeScreen(),
      ));
      await tester.pumpAndSettle();
      final initialLocationReads = locationReads;
      expect(watch.keys, ['test.0']);
      await tester.tap(find.byKey(const ValueKey('qolip-grid-cell-A1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search by mold code or product name'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'Q-ARCH');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('Archive test mold'), findsOneWidget);
      expect(placementReads, 1);
      expect(locationReads, initialLocationReads);

      isArchived = true;
      revision = 'test.1';
      watch['test.0']!.complete(_json({'storage_revision': revision}));
      await tester.pumpAndSettle();
      expect(find.text('Archive test mold'), findsNothing);
      expect(find.text('Q-ARCH'), findsOneWidget);
      expect(placementReads, 2);
      expect(watch.keys, ['test.0', 'test.1']);

      isArchived = false;
      revision = 'test.2';
      watch['test.1']!.complete(_json({'storage_revision': revision}));
      await tester.pumpAndSettle();
      expect(find.text('Archive test mold'), findsOneWidget);
      expect(placementReads, 3);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      watch['test.2']!.complete(_json({'storage_revision': 'test.3'}));
      await tester.pumpAndSettle();
      expect(watch.keys, ['test.0', 'test.1', 'test.2']);
    },
        () => MockClient((request) async {
              switch (request.url.path) {
                case '/v1/mobile/qolip/blocks':
                  return _json({
                    'warehouses': ['Molds A'],
                    'blocks': [
                      {'name': 'A', 'warehouse': 'Molds A'}
                    ],
                    'storage_revision': revision,
                  });
                case '/v1/mobile/qolip/locations':
                  locationReads++;
                  return _json({'locations': []});
                case '/v1/mobile/qolip/products':
                  expect(request.url.queryParameters['placement_warehouse'],
                      'Molds A');
                  placementReads++;
                  return _json({
                    'placement_filtered': true,
                    'storage_revision': revision,
                    'products': [
                      if (!isArchived)
                        {
                          'code': 'ITEM-ARCH',
                          'name': 'Archive test mold',
                          'item_group': 'Tayyor mahsulot',
                          'qolip_code': 'Q-ARCH',
                          'size': 40,
                          'warehouse': 'Molds A',
                          'has_qolip_spec': true,
                        }
                    ],
                  });
                case '/v1/mobile/qolip/storage/revision':
                  final after = request.url.queryParameters['after']!;
                  expect(watch.containsKey(after), isFalse);
                  return (watch[after] = Completer<http.Response>()).future;
                default:
                  return _json({'ok': true, 'items': [], 'entries': []});
              }
            }));
  });
}
