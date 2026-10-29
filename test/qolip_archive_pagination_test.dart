import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_retry_state.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_catalog_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'qolip_archive_list_style_test.dart' as fixture;

http.Response page(List<Map<String, dynamic>> entries, {int? next}) =>
    http.Response(
        jsonEncode({
          'ok': true,
          'entries': entries,
          'has_more': next != null,
          if (next != null) 'next_offset': next
        }),
        200,
        headers: {'content-type': 'application/json'});

Map<String, dynamic> pallet(int i) => fixture.archiveEntry(
    'p$i', 'paddon', 'QP-${i.toString().padLeft(5, '0')}', {'items': []});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ServerEndpointStore.instance.clearOverride();
    AppSession.instance.token = 'archive-scroll-test';
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.qolipchi,
        ref: 'worker',
        displayName: 'Worker',
        legalName: '',
        phone: '',
        avatarUrl: '',
        capabilities: ['qolip.manage'],
        assignedWarehouses: ['Mold store']);
    AppSession.instance.revision.value++;
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    QolipCatalogStore.instance.reset();
  });

  testWidgets('archive scroll loads next page without a load more button',
      (tester) async {
    final offsets = <int>[];
    await http.runWithClient(() async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(fixture.app());
      await tester.pumpAndSettle();
      expect(offsets, [0]);
      expect(find.text('Load more'), findsNothing);
      await tester.drag(find.byKey(const ValueKey('qolip-archive-list')),
          const Offset(0, -2600));
      await tester.pumpAndSettle();
      expect(offsets, [0, 25]);
      expect(find.text('QP-00099'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
    },
        () => MockClient((request) async {
              if (!request.url.path.endsWith('/qolip/archive')) return page([]);
              final offset =
                  int.parse(request.url.queryParameters['offset'] ?? '0');
              offsets.add(offset);
              return offset == 0
                  ? page(List.generate(25, pallet), next: 25)
                  : page([pallet(99)]);
            }));
  });

  testWidgets('empty filtered pages advance and later errors allow retry',
      (tester) async {
    var nextCalls = 0;
    var firstCalls = 0;
    await http.runWithClient(() async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(fixture.app());
      await tester.pumpAndSettle();
      await fixture.tapVisible(
          tester, find.byKey(const ValueKey('qolip-archive-kind-filter')));
      await fixture.tapVisible(tester,
          find.byKey(const ValueKey('qolip-archive-kind-option-Pallets')));
      expect(nextCalls, 1);
      expect(find.byType(AppRetryState), findsOneWidget);
      await fixture.tapVisible(
          tester, find.byType(AppRetryState).findDescendantButton());
      expect(nextCalls, 2);
      expect(find.text('QP-00099'), findsOneWidget);
    },
        () => MockClient((request) async {
              if (!request.url.path.endsWith('/qolip/archive')) return page([]);
              final offset =
                  int.parse(request.url.queryParameters['offset'] ?? '0');
              if (offset == 0) {
                if (firstCalls++ == 0) return page([pallet(0)]);
                return page([
                  fixture.archiveEntry(
                      'm', 'qolip', 'Q-ONE', {'qolip_code': 'Q-ONE'})
                ], next: 1);
              }
              nextCalls++;
              return nextCalls == 1
                  ? http.Response(
                      jsonEncode({'ok': false, 'error': 'failed'}), 500,
                      headers: {'content-type': 'application/json'})
                  : page([pallet(99)]);
            }));
  });

  testWidgets('invalid page offset stops loading and offers retry',
      (tester) async {
    var requests = 0;
    await http.runWithClient(() async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(fixture.app());
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(find.byType(AppRetryState), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(requests, 2);
    },
        () => MockClient((request) async {
              if (!request.url.path.endsWith('/qolip/archive')) return page([]);
              requests++;
              return page([pallet(requests)], next: 1);
            }));
  });

  testWidgets('a late page cannot replace a newer search', (tester) async {
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(fixture.app());
      await tester.pumpAndSettle();
      await tester.drag(find.byKey(const ValueKey('qolip-archive-list')),
          const Offset(0, -2600));
      await tester.pump();
      await tester.pump();
      final search = find.descendant(
          of: find.byType(AdminCatalogSearchField),
          matching: find.byType(EditableText));
      await tester.enterText(search, 'new');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('QP-00099'), findsOneWidget);
      pending.complete(page([pallet(88)]));
      await tester.pumpAndSettle();
      expect(find.text('QP-00099'), findsOneWidget);
      expect(find.text('QP-00088'), findsNothing);
    },
        () => MockClient((request) async {
              if (!request.url.path.endsWith('/qolip/archive')) return page([]);
              if (request.url.queryParameters['q'] == 'new') {
                return page([pallet(99)]);
              }
              if (request.url.queryParameters['offset'] == '25') {
                return pending.future;
              }
              return page(List.generate(25, pallet), next: 25);
            }));
  });
}

extension RetryFinder on Finder {
  Finder findDescendantButton() =>
      find.descendant(of: this, matching: find.byType(TextButton));
}
