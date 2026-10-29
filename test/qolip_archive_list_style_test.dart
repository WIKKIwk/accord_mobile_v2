import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/widgets/feedback/rps_qr_reprint_sheet.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_products_screen.dart'
    show QolipCodeRow, QolipProductContainerCard;
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_storage_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> mold(String code, String name) => {
      'qolip_code': code,
      'qolip_set_id': name,
      'warehouse': 'Mold store',
      'item_name': name,
      'size': 40,
      'products': [
        {'code': 'ITEM-A', 'name': 'Alpha'}
      ],
    };

Map<String, dynamic> archiveEntry(
        String id, String kind, String code, Map<String, dynamic> snapshot,
        {String? parent, bool returned = false}) =>
    {
      'id': id,
      'kind': kind,
      'code': code,
      'warehouse': 'Mold store',
      'archived_at': '2026-10-29T10:00:00Z',
      if (returned) 'restored_at': '2026-10-30T10:00:00Z',
      if (parent != null) 'parent_paddon_code': parent,
      'snapshot': snapshot,
    };

Widget app() => const MaterialApp(
      locale: Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: QolipStorageScreen(archive: true),
    );

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ServerEndpointStore.instance.clearOverride();
    AppSession.instance.token = 'archive-list-test';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      ref: 'worker',
      displayName: 'Worker',
      legalName: '',
      phone: '',
      avatarUrl: '',
      capabilities: ['qolip.manage'],
      assignedWarehouses: ['Mold store'],
    );
    AppSession.instance.revision.value++;
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    QolipCatalogStore.instance.reset();
  });

  testWidgets('archive list groups both kinds of molds and opens their details',
      (tester) async {
    final requests = <String>[];
    final palletMold = mold('Q-PALLET', 'Pallet snapshot');
    final directMold = mold('Q-DIRECT', 'Direct snapshot');
    await http.runWithClient(() async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      // Pallets in the unfiltered archive have no timestamp or forward arrow.
      expect(find.text('QP-00012'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.textContaining('29.10.2026'), findsNothing);
      expect(find.textContaining('15:00'), findsNothing);

      await tapVisible(
          tester, find.byKey(const ValueKey('qolip-archive-kind-filter')));
      await tapVisible(tester,
          find.byKey(const ValueKey('qolip-archive-kind-option-Molds')));
      expect(find.byKey(const ValueKey('qolip-archive-product-product:item-a')),
          findsOneWidget);
      expect(find.byType(QolipProductContainerCard), findsOneWidget);
      await tapVisible(
          tester,
          find.byKey(
              const ValueKey('qolip-archive-product-expand-product:item-a')));
      expect(find.byType(QolipCodeRow), findsNWidgets(2));
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.textContaining('29.10.2026'), findsNothing);
      expect(find.textContaining('15:00'), findsNothing);
      final countBefore = requests.length;
      await tapVisible(
          tester, find.byKey(const ValueKey('qolip-archive-mold-pa-Q-PALLET')));
      final sheet =
          tester.widget<RpsQrReprintSheet>(find.byType(RpsQrReprintSheet));
      expect(sheet.payload, 'Q-PALLET');
      expect(sheet.itemName, 'Alpha');
      expect(sheet.details.map((detail) => detail.value),
          contains('Pallet snapshot'));
      expect(sheet.onReprint, isNull);
      expect(requests.length, countBefore);
      Navigator.of(tester.element(find.byType(RpsQrReprintSheet))).pop();
      await tester.pumpAndSettle();

      await tapVisible(tester,
          find.byKey(const ValueKey('qolip-archive-mold-direct-Q-DIRECT')));
      final detail = tester.widget<QolipArchiveDetailScreen>(
          find.byType(QolipArchiveDetailScreen));
      expect(detail.entry.id, 'direct');
      expect(find.text('Restore'), findsOneWidget);
      expect(requests.length, countBefore);
    },
        () => MockClient((request) async {
              requests.add(request.url.path);
              final view = request.url.queryParameters['view'];
              final entries = view == 'molds'
                  ? [
                      archiveEntry('pa', 'paddon_mold', 'Q-PALLET', palletMold,
                          parent: 'QP-00012'),
                      archiveEntry(
                          'direct', 'qolip', 'Q-DIRECT', {'mold': directMold}),
                    ]
                  : [
                      archiveEntry('pa', 'paddon', 'QP-00012', {
                        'items': [palletMold]
                      }),
                    ];
              final response = request.url.path.endsWith('/qolip/archive')
                  ? {'ok': true, 'entries': entries, 'has_more': false}
                  : {'ok': true, 'items': [], 'has_more': false};
              return http.Response(jsonEncode(response), 200,
                  headers: {'content-type': 'application/json'});
            }));
  });

  testWidgets('history retains separate visits of the same archived mold',
      (tester) async {
    final first = mold('Q-SAME', 'First visit');
    final second = mold('Q-SAME', 'Second visit');
    await http.runWithClient(() async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tapVisible(
          tester, find.byKey(const ValueKey('qolip-archive-kind-filter')));
      await tapVisible(tester,
          find.byKey(const ValueKey('qolip-archive-kind-option-Molds')));
      await tapVisible(tester, find.byType(SwitchListTile));
      await tapVisible(
          tester,
          find.byKey(
              const ValueKey('qolip-archive-product-expand-product:item-a')));
      expect(find.byKey(const ValueKey('qolip-archive-mold-visit-1-Q-SAME')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('qolip-archive-mold-visit-2-Q-SAME')),
          findsOneWidget);
      expect(find.byType(QolipCodeRow), findsNWidgets(2));
      await tapVisible(tester,
          find.byKey(const ValueKey('qolip-archive-mold-visit-1-Q-SAME')));
      var sheet =
          tester.widget<RpsQrReprintSheet>(find.byType(RpsQrReprintSheet));
      expect(
          sheet.details.map((detail) => detail.value), contains('First visit'));
      Navigator.of(tester.element(find.byType(RpsQrReprintSheet))).pop();
      await tester.pumpAndSettle();
      await tapVisible(tester,
          find.byKey(const ValueKey('qolip-archive-mold-visit-2-Q-SAME')));
      sheet = tester.widget<RpsQrReprintSheet>(find.byType(RpsQrReprintSheet));
      expect(sheet.details.map((detail) => detail.value),
          contains('Second visit'));
    },
        () => MockClient((request) async {
              final isHistory = request.url.queryParameters['status'] == 'all';
              final entries = [
                archiveEntry('visit-1', 'paddon_mold', 'Q-SAME', first,
                    parent: 'QP-00001'),
                if (isHistory)
                  archiveEntry('visit-2', 'paddon_mold', 'Q-SAME', second,
                      parent: 'QP-00002', returned: true),
              ];
              final response = request.url.path.endsWith('/qolip/archive')
                  ? {'ok': true, 'entries': entries, 'has_more': false}
                  : {'ok': true, 'items': [], 'has_more': false};
              return http.Response(jsonEncode(response), 200,
                  headers: {'content-type': 'application/json'});
            }));
  });
}
