import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/widgets/paddon_widgets.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_storage_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> mold(String code) => {
      'qolip_code': code,
      'warehouse': 'Mold store',
      'qolip_set_id': '9501',
      'item_name': 'Product',
      'size': 40,
    };

Map<String, dynamic> archivedPaddon(String id, List<String> codes,
        {bool restored = false}) =>
    {
      'id': id,
      'kind': 'paddon',
      'code': 'QP-00001',
      'warehouse': 'Mold store',
      'archived_at': '2026-10-29T10:00:00Z',
      if (restored) 'restored_at': '2026-10-30T10:00:00Z',
      'snapshot': {
        'paddon': {'location': 'A1', 'item_count': codes.length},
        'items': codes.map(mold).toList(),
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ServerEndpointStore.instance.clearOverride();
    AppSession.instance.token = 'archive-paddon-test';
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

  testWidgets('archive uses pallet cards and opens the saved pallet visit',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final queries = <Map<String, String>>[];
    await http.runWithClient(() async {
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
      final cardFinder =
          find.byKey(const ValueKey('qolip-archive-paddon-current'));
      expect(cardFinder, findsOneWidget);
      final card = tester.widget<PaddonListCard>(cardFinder);
      expect(card.code, 'QP-00001');
      expect(card.countLabel, contains('2'));
      expect(card.subtitle, contains('Mold store'));
      expect(card.subtitle, contains('Archived'));
      expect(
          find.descendant(
              of: cardFinder,
              matching: find.byIcon(Icons.chevron_right_rounded)),
          findsNothing);
      expect(find.textContaining('29.10.2026'), findsNothing);
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();
      final detail = tester.widget<QolipArchiveDetailScreen>(
          find.byType(QolipArchiveDetailScreen));
      expect(detail.entry.id, 'current');
      expect((detail.entry.snapshot['items'] as List).length, 2);
      expect(queries.last['status'], 'open');
    },
        () => MockClient((request) async {
              queries.add(request.url.queryParameters);
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'entries': [
                      archivedPaddon('current', ['Q-A', 'Q-B'])
                    ],
                    'has_more': false
                  }),
                  200,
                  headers: {'content-type': 'application/json'});
            }));
  });

  testWidgets('history keeps visits of the same pallet separate',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final statuses = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate
        ],
        home: QolipStorageScreen(archive: true),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      final current =
          find.byKey(const ValueKey('qolip-archive-paddon-current'));
      final old = find.byKey(const ValueKey('qolip-archive-paddon-old'));
      expect(current, findsOneWidget);
      expect(old, findsOneWidget);
      expect(tester.widget<PaddonListCard>(current).countLabel, contains('2'));
      expect(tester.widget<PaddonListCard>(old).countLabel, contains('1'));
      expect(tester.widget<PaddonListCard>(old).subtitle, contains('Restored'));
      expect(statuses.last, 'all');
      await tester.tap(old);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<QolipArchiveDetailScreen>(
                  find.byType(QolipArchiveDetailScreen))
              .entry
              .id,
          'old');
      expect(find.text('Restore'), findsNothing);
    },
        () => MockClient((request) async {
              final status = request.url.queryParameters['status'] ?? '';
              statuses.add(status);
              final entries = [
                archivedPaddon('current', ['Q-A', 'Q-B'])
              ];
              if (status == 'all') {
                entries.add(archivedPaddon('old', ['Q-C'], restored: true));
              }
              return http.Response(
                  jsonEncode(
                      {'ok': true, 'entries': entries, 'has_more': false}),
                  200,
                  headers: {'content-type': 'application/json'});
            }));
  });
}
