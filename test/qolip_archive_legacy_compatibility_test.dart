import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const oldServerError =
    'Failed to deserialize query string: view: unknown field `view`, expected one of `q`, `status`';

Map<String, dynamic> archiveEntry(
        String id, String kind, String code, Map<String, dynamic> snapshot) =>
    {
      'id': id,
      'kind': kind,
      'code': code,
      'warehouse': 'Qolip ombori',
      'archived_at': '2026-10-29T10:00:00Z',
      'restored_at': '2026-10-30T10:00:00Z',
      'snapshot': snapshot,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    AppSession.instance.token = 'legacy-archive-test';
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
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('old server flattens pallet snapshots across paginated archive entries',
      () async {
    final queries = <Map<String, String>>[];
    final items = List.generate(
        101,
        (i) => {
              'qolip_code': 'Q-${i.toString().padLeft(3, '0')}',
              'item_name': i == 100 ? 'Only target' : 'Product',
            }).reversed.toList();
    await http.runWithClient(() async {
      Future<QolipStoragePage<QolipArchiveEntry>> get(
              {int offset = 0, String query = ''}) =>
          MobileApi.instance.qolipArchive(
              view: 'molds',
              status: 'all',
              query: query,
              offset: offset,
              warehouse: 'Qolip ombori',
              from: DateTime(2026, 10, 1),
              to: DateTime(2026, 10, 30));
      final first = await get();
      expect(first.items.length, 100);
      expect(first.items.first.code, 'Q-000');
      expect(first.items.last.code, 'Q-099');
      expect(first.nextOffset, 100);
      expect(first.items.first.kind, 'paddon_mold');
      expect(first.items.first.id, 'pallet-entry');
      expect(first.items.first.parentPaddonCode, 'QP-00001');
      expect(first.items.first.restoredAt, isNotNull);
      final second = await get(offset: first.nextOffset!);
      expect(second.items.map((e) => e.code), ['Q-100', 'Q-DIRECT']);
      expect(second.items.last.kind, 'qolip');
      expect(second.nextOffset, isNull);
      final filtered = await get(query: 'only target');
      expect(filtered.items.map((e) => e.code), ['Q-100']);
      final sourceQueries = queries.where((q) => !q.containsKey('view'));
      expect(sourceQueries.map((q) => q['offset']), contains('100'));
      for (final q in sourceQueries) {
        expect(q['status'], 'all');
        expect(q['warehouse'], 'Qolip ombori');
        expect(q['from'], '2026-10-01');
        expect(q['to'], '2026-10-30');
      }
    },
        () => MockClient((request) async {
              final q = request.url.queryParameters;
              queries.add(q);
              if (q.containsKey('view')) {
                return http.Response(oldServerError, 400,
                    headers: {'content-type': 'text/plain; charset=utf-8'});
              }
              final later = q['offset'] == '100';
              final entries = later
                  ? [
                      archiveEntry('direct-entry', 'qolip', 'Q-DIRECT',
                          {'qolip_code': 'Q-DIRECT'})
                    ]
                  : [
                      archiveEntry('pallet-entry', 'paddon', 'QP-00001',
                          {'items': items})
                    ];
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'entries': entries,
                    'has_more': !later,
                    if (!later) 'next_offset': 100
                  }),
                  200,
                  headers: {'content-type': 'application/json'});
            }));
  });

  test('other errors never use the compatibility fallback', () async {
    for (final response in [
      http.Response(jsonEncode({'ok': false, 'error': 'forbidden'}), 403,
          headers: {'content-type': 'application/json'}),
      http.Response(
          'Failed to deserialize query string: unknown field `status`', 400,
          headers: {'content-type': 'text/plain'}),
      http.Response(oldServerError, 500,
          headers: {'content-type': 'text/plain'}),
    ]) {
      var requests = 0;
      await http.runWithClient(() async {
        await expectLater(
            MobileApi.instance.qolipArchive(view: 'molds'), throwsA(anything));
        expect(requests, 1);
      },
          () => MockClient((request) async {
                requests++;
                return response;
              }));
    }
  });
}
