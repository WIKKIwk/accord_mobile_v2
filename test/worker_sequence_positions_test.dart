import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/cache/production_snapshot_store.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'production_snapshot_test_backend.dart';
import 'worker_queue_window_widget_test.dart' as fixture;

const _apparatus = fixture.apparatus;
const _other = 'apparatus:default:asset-005';

Map<String, dynamic> _wire(List<int> indices, {int? position, int rev = 7}) {
  final wire =
      encodeProductionMapQueueSnapshot(fixture.snapshot(indices, 'ranks'));
  wire['rev'] = rev;
  if (position != null) {
    (wire['sequences'] as Map)[_other] = ['zakaz-${indices.single}'];
    (wire['visible_order_ids'] as Map)[_other] = ['zakaz-${indices.single}'];
    (wire['queue_states'] as Map)[_other] = {
      'zakaz-${indices.single}': 'pending'
    };
    wire['sequence_positions_by_apparatus'] = {
      _apparatus: {'zakaz-${indices.single}': position},
      _other: {'zakaz-${indices.single}': 9},
    };
  } else {
    wire.remove('sequence_positions_by_apparatus');
  }
  return wire;
}

Map<String, dynamic> _rankPatch(int position) => {
      'sequence_positions_by_apparatus': {
        'scopes': {
          _apparatus: {
            'upsert': {'zakaz-3': position},
            'remove': <String>[],
          },
        },
        'remove': <String>[],
      },
    };

AdminProductionMapLiveStateDelta _delta(String protocol,
        {int position = 5, int base = 7, Map<String, dynamic>? patch}) =>
    AdminProductionMapLiveStateDelta.fromJson({
      'protocol': protocol,
      'epoch': 'server',
      'scope': 'ranks',
      'base_rev': base,
      'rev': base + 1,
      'patch': patch ?? _rankPatch(position),
    });

Finder _row(int index) => find.byKey(ValueKey('worker-order-zakaz-$index'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    resetMobileApiTestModeData();
    ProductionSnapshotStore.debugOverride =
        ProductionSnapshotStore(backend: MemoryProductionSnapshotBackend());
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'rank-worker';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Worker',
      legalName: '',
      ref: 'rank-worker',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [_apparatus],
    );
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    ProductionSnapshotStore.debugOverride = null;
  });

  test('HTTP/background/live/cache decode preserves apparatus-specific ranks',
      () async {
    final wire = _wire([3], position: 4);
    final source = jsonEncode(wire);
    final inline = await decodeProductionMapQueueSnapshotPayload(source,
        backgroundThresholdCodeUnits: source.length + 1);
    final background = await decodeProductionMapQueueSnapshotPayload(source,
        backgroundThresholdCodeUnits: 0);
    final cached = decodeCachedProductionMapQueueSnapshot(
        encodeProductionMapQueueSnapshot(inline));
    for (final value in [
      inline,
      background,
      cached,
      AdminProductionMapLiveSnapshot.fromJson(wire)
    ]) {
      expect(value.sequencePositionsByApparatus, {
        _apparatus: {'zakaz-3': 4},
        _other: {'zakaz-3': 9},
      });
      expect(
          () => value.sequencePositionsByApparatus[_apparatus]!['zakaz-3'] = 1,
          throwsUnsupportedError);
    }
    final queueWire = {...wire}..remove('completed_orders');
    expect(
        (await decodeProductionMapQueueSnapshotPayload(jsonEncode(queueWire)))
            .sequencePositionsByApparatus[_apparatus]!['zakaz-3'],
        4);
    expect(
        decodeCachedProductionMapQueueSnapshot(_wire([3]))
            .sequencePositionsByApparatus,
        isEmpty);
  });

  test('malformed rank metadata rejects atomically', () {
    for (final invalid in [
      null,
      [],
      {
        'wrong-apparatus': {'zakaz-3': 4}
      },
      {_apparatus: null},
      {
        _apparatus: {'': 4}
      },
      {_apparatus: {}},
      {
        _apparatus: {'unknown': 4}
      },
      {
        _apparatus: {'zakaz-3': 4, 'extra': 4}
      },
      for (final rank in [0, -1, 1.5, '4', true])
        {
          _apparatus: {'zakaz-3': rank}
        }
    ]) {
      expect(
          () => decodeCachedProductionMapQueueSnapshot({
                ..._wire([3]),
                'sequence_positions_by_apparatus': invalid,
              }),
          throwsA(isA<MobileApiException>()));
    }
  });

  for (final protocol in ['state_delta_v1', 'state_delta_v2']) {
    test(
        '$protocol applies rank-only changes without replacing maps or old ranks',
        () {
      final before =
          decodeCachedProductionMapQueueSnapshot(_wire([3], position: 4));
      var current = before;
      for (var i = 0; i < 1000; i++) {
        current = _delta(protocol, position: i + 5, base: current.revision!)
            .applyTo(current);
        expect(current.sequencePositionsByApparatus[_apparatus]!['zakaz-3'],
            i + 5);
        expect(current.sequencePositionsByApparatus[_other]!['zakaz-3'], 9);
        expect(identical(current.maps, before.maps), isTrue);
      }
      expect(before.sequencePositionsByApparatus[_apparatus]!['zakaz-3'], 4);
      final cached = decodeCachedProductionMapQueueSnapshot(
          encodeProductionMapQueueSnapshot(current));
      expect(cached.sequencePositionsByApparatus,
          current.sequencePositionsByApparatus);
      expect(() => _delta(protocol, position: 0).applyTo(before),
          throwsA(isA<MobileApiException>()));
      expect(() => _delta(protocol, base: 8).applyTo(before),
          throwsA(isA<MobileApiException>()));
      final removed = _delta(protocol, patch: {
        'sequence_positions_by_apparatus': {
          'scopes': {},
          'remove': [_apparatus]
        },
      }).applyTo(before);
      expect(removed.sequencePositionsByApparatus.containsKey(_apparatus),
          isFalse);
      expect(before.sequencePositionsByApparatus[_apparatus]!['zakaz-3'], 4);
    });

    testWidgets(
        '$protocol worker searched rank 4 and cold rank 28 survive live updates',
        (tester) async {
      final catalog = await MobileApi.instance.adminApparatus(limit: 200);
      final events = StreamController<Object>.broadcast();
      addTearDown(events.close);
      var reads = 0;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate
        ],
        home: AdminProductionMapOrdersScreen(
          workerMode: true,
          readOnly: true,
          apparatusLoader: () async =>
              catalog.where((a) => a.id == _apparatus).toList(),
          queueSnapshotLoader: () async {
            reads++;
            return decodeCachedProductionMapQueueSnapshot(reads == 1
                ? _wire(List.generate(10, (i) => i))
                : reads == 2
                    ? _wire([3], position: 4)
                    : _wire([27], position: 28, rev: 9));
          },
          liveEventsLoader: () => events.stream,
        ),
      ));
      await tester.pumpAndSettle();
      expect(reads, 1);
      await tester.enterText(find.byType(EditableText).first, 'C3');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.descendant(of: _row(3), matching: find.text('4')),
          findsOneWidget);
      final oldElement = tester.element(_row(3));
      events.add(_delta(protocol));
      await tester.pumpAndSettle();
      expect(find.descendant(of: _row(3), matching: find.text('5')),
          findsOneWidget);
      expect(identical(tester.element(_row(3)), oldElement), isTrue);
      expect(reads, 2,
          reason: 'Rank-only delta must not trigger a snapshot fetch');
      await tester.enterText(find.byType(EditableText).first, 'C27');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(find.descendant(of: _row(27), matching: find.text('28')),
          findsOneWidget);
      expect(_row(0), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets(
      'worker tabs use their apparatus ranks even when an active row is pinned first',
      (tester) async {
    final catalog = await MobileApi.instance.adminApparatus(limit: 200);
    final events = StreamController<Object>.broadcast();
    addTearDown(events.close);
    final wire = _wire([0, 3]);
    wire['worker_show_all_apparatus_tabs'] = true;
    (wire['sequences'] as Map)[_other] = ['zakaz-3'];
    (wire['visible_order_ids'] as Map)[_apparatus] = ['zakaz-3', 'zakaz-0'];
    (wire['visible_order_ids'] as Map)[_other] = ['zakaz-3'];
    wire['queue_policies'] = [
      {
        'apparatus_id': _apparatus,
        'apparatus': _apparatus,
        'policy': 'free_pick'
      },
    ];
    (wire['queue_states'] as Map)[_apparatus]['zakaz-3'] = 'in_progress';
    (wire['queue_states'] as Map)[_other] = {'zakaz-3': 'pending'};
    wire['sequence_positions_by_apparatus'] = {
      _apparatus: {'zakaz-0': 1, 'zakaz-3': 4},
      _other: {'zakaz-3': 9},
    };
    final saved = (wire['maps'] as List).last as Map;
    ((saved['map'] as Map)['nodes'] as List).insert(2, {
      'id': 'other-work',
      'kind': 'apparatus',
      'apparatus_id': _other,
      'title': 'Other work',
    });
    final otherCatalog = catalog.firstWhere((a) => a.id == _other);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      home: AdminProductionMapOrdersScreen(
        workerMode: true,
        readOnly: true,
        apparatusLoader: () async =>
            catalog.where((a) => [_apparatus, _other].contains(a.id)).toList(),
        queueSnapshotLoader: () async =>
            decodeCachedProductionMapQueueSnapshot(wire),
        liveEventsLoader: () => events.stream,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.descendant(of: _row(3).hitTestable(), matching: find.text('4')),
        findsOneWidget);
    final dynamic row = tester.widget(find.descendant(
        of: _row(3).hitTestable(),
        matching: find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_SequenceOrderRow')));
    expect(row.index, 0,
        reason: 'Active pinning must not replace the authoritative badge rank');
    await tester.tap(find.widgetWithText(Tab, otherCatalog.name.trim()));
    await tester.pumpAndSettle();
    expect(find.descendant(of: _row(3).hitTestable(), matching: find.text('9')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('legacy full snapshot retains rank 4 across local search',
      (tester) async {
    final catalog = await MobileApi.instance.adminApparatus(limit: 200);
    final events = StreamController<Object>.broadcast();
    addTearDown(events.close);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      home: AdminProductionMapOrdersScreen(
        workerMode: true,
        readOnly: true,
        apparatusLoader: () async =>
            catalog.where((a) => a.id == _apparatus).toList(),
        queueSnapshotLoader: () async =>
            fixture.snapshot([0, 1, 2, 3, 4], 'legacy'),
        liveEventsLoader: () => events.stream,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'C3');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
        find.descendant(of: _row(3), matching: find.text('4')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
