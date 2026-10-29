import 'dart:convert';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_storage_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('mold filter shows archived pallet contents and snapshot details',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'archive-filter-test';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      ref: 'worker',
      displayName: 'Worker',
      legalName: '',
      phone: '',
      avatarUrl: '',
      capabilities: ['qolip.manage'],
      assignedWarehouses: ['Qolip ombori'],
    );
    AppSession.instance.revision.value++;
    addTearDown(() {
      AppSession.instance.token = null;
      AppSession.instance.profile = null;
    });
    final queries = <Map<String, String>>[];
    final requests = <String>[];
    await http.runWithClient(() async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: QolipStorageScreen(archive: true),
      ));
      await tester.pumpAndSettle();
      expect(find.text('QP-00012'), findsOneWidget);
      expect(queries.last.containsKey('view'), isFalse);
      await tester.tap(find.byKey(const ValueKey('qolip-archive-kind-filter')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('qolip-archive-kind-option-Molds')));
      await tester.pumpAndSettle();
      expect(queries.last['view'], 'molds');
      expect(find.text('QP-00012'), findsNothing);
      await tester.tap(
          find.byKey(const ValueKey('qolip-archive-product-expand-unlinked')));
      await tester.pumpAndSettle();
      expect(find.text('Q-IN-PALLET'), findsOneWidget);
      expect(find.text('Q-DIRECT'), findsOneWidget);
      expect(find.textContaining('QP-00012'), findsOneWidget);
      final requestCount = requests.length;
      await tester.tap(find.text('Q-IN-PALLET'));
      await tester.pumpAndSettle();
      expect(find.text('Snapshot product'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
      expect(requests.length, requestCount);
      Navigator.of(tester.element(find.text('Snapshot product'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('qolip-archive-kind-filter')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('qolip-archive-kind-option-All')));
      await tester.pumpAndSettle();
      expect(queries.last.containsKey('view'), isFalse);
      expect(find.text('QP-00012'), findsOneWidget);
      expect(find.text('Q-IN-PALLET'), findsNothing);
    },
        () => MockClient((request) async {
              requests.add(request.url.path);
              if (request.url.path.endsWith('/blocks')) {
                return http.Response(
                    jsonEncode({'ok': true, 'warehouses': [], 'blocks': []}),
                    200);
              }
              queries.add(request.url.queryParameters);
              final molds = request.url.queryParameters['view'] == 'molds';
              Map<String, dynamic> entry(String id, String kind, String code,
                      {String? parent}) =>
                  {
                    'id': id,
                    'kind': kind,
                    'code': code,
                    'warehouse': 'Qolip ombori',
                    'archived_at': '2026-10-29T10:00:00Z',
                    if (parent != null) 'parent_paddon_code': parent,
                    'snapshot': {
                      'qolip_code': code,
                      'warehouse': 'Qolip ombori',
                      'qolip_set_id': '9501',
                      'item_name': 'Snapshot product',
                      'size': 40,
                      'quantity': 1
                    },
                  };
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'entries': molds
                        ? [
                            entry('pa', 'paddon_mold', 'Q-IN-PALLET',
                                parent: 'QP-00012'),
                            entry('mo', 'qolip', 'Q-DIRECT')
                          ]
                        : [
                            entry('pa', 'paddon', 'QP-00012'),
                            entry('mo', 'qolip', 'Q-DIRECT')
                          ],
                    'has_more': false
                  }),
                  200,
                  headers: {'content-type': 'application/json'});
            }));
  });
}
