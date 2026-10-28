import 'dart:async';

import 'package:accord_mobile_v2/src/core/inventory/inventory_view_store.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_loading_indicator.dart';
import 'package:accord_mobile_v2/src/features/inventory/presentation/inventory_movements_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'inventory-live-test';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Materialchi',
      legalName: '',
      ref: 'inventory-live-test',
      phone: '',
      avatarUrl: '',
      capabilities: ['inventory.movement.manage', 'raw_material.assign'],
      assignedWarehouses: ['Material ombor'],
      assignedApparatus: ['apparatus:default:asset-005'],
    );
  });

  tearDown(() {
    InventoryViewStore.debugOverride = null;
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('deltas preserve the page and route reentry reuses live cache',
      (tester) async {
    final fixture = _LiveInventoryFixture();
    InventoryViewStore.debugOverride = fixture.store;
    try {
      await _open(tester);
      expect(find.text('Original polymer'), findsOneWidget);
      expect(fixture.opens, hasLength(2));
      expect(fixture.httpReads, 0);

      final tab = tester.element(find.byType(TabBarView));
      final product = fixture.windows['products']!;
      product.add(_delta(2, [
        _asset('first', 'Renamed polymer', label: '0100 · Live order'),
        _asset('second', 'Added polymer'),
      ], [], [
        'raw_material:raw:first',
        'raw_material:raw:second'
      ]));
      await _settle(tester);
      expect(find.text('0100 · Live order'), findsOneWidget);
      expect(find.text('Added polymer'), findsOneWidget);
      expect(identical(tester.element(find.byType(TabBarView)), tab), isTrue);
      expect(find.byType(AppLoadingIndicator), findsNothing);
      final sibling = tester
          .element(find.byKey(const ValueKey('inventory-asset-raw:second')));

      product.add(_delta(
          3, [], ['raw_material:raw:first'], ['raw_material:raw:second']));
      await _settle(tester);
      expect(find.text('0100 · Live order'), findsNothing);
      expect(find.text('Added polymer'), findsOneWidget);
      expect(
          identical(
              tester.element(
                  find.byKey(const ValueKey('inventory-asset-raw:second'))),
              sibling),
          isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      product.add(_delta(4, [_asset('second', 'Changed while closed')], [],
          ['raw_material:raw:second']));
      await tester.pump();
      await _open(tester);
      expect(find.text('Changed while closed'), findsOneWidget);
      expect(fixture.opens, hasLength(2));
      expect(fixture.httpReads, 0);

      // Transfer views remain lazy, then survive their own route reentry.
      await tester.tap(find.text('Kiruvchi'));
      await _settle(tester);
      final transferOpens =
          fixture.opens.where((query) => query.kind == 'transfers').length;
      expect(transferOpens, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await _open(tester);
      await tester.tap(find.text('Kiruvchi'));
      await _settle(tester);
      expect(fixture.opens.where((q) => q.kind == 'transfers'), hasLength(1));
      expect(fixture.httpReads, 0);
    } finally {
      await tester.pumpWidget(const SizedBox());
      fixture.store.reset();
      fixture.close();
      await tester.pump();
    }
  });

  testWidgets('authorization reset clears visible rows and reports permission',
      (tester) async {
    final fixture = _LiveInventoryFixture();
    InventoryViewStore.debugOverride = fixture.store;
    try {
      await _open(tester);
      fixture.windows['products']!.add({'event': 'inventory.reset'});
      await _settle(tester);
      expect(find.text('Original polymer'), findsNothing);
      expect(find.textContaining('ruxsatlari o‘zgardi'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      fixture.store.reset();
      fixture.close();
      await tester.pump();
    }
  });

  testWidgets(
      'state rows use deltas and keep their cache across route disposal',
      (tester) async {
    final fixture = _LiveInventoryFixture();
    InventoryViewStore.debugOverride = fixture.store;
    try {
      await _open(tester);
      await tester.tap(find.text('State’lar'));
      await _settle(tester);
      await tester
          .tap(find.byKey(const ValueKey('material-state-filter-chip')));
      await _settle(tester);
      await tester.tap(find.text('Bosma oldi'));
      await _settle(tester);
      expect(find.text('Original state polymer'), findsOneWidget);

      fixture.windows['states']!.add(_delta(
          2,
          [_stateAsset('state-first', 'Updated state polymer')],
          [],
          ['raw_material:raw:state-first']));
      await _settle(tester);
      expect(find.text('Updated state polymer'), findsOneWidget);
      expect(find.text('Original state polymer'), findsNothing);
      expect(find.byType(AppLoadingIndicator), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await _open(tester);
      await tester.tap(find.text('State’lar'));
      await _settle(tester);
      expect(
          fixture.opens.where((query) =>
              query.parameters['current_user_states_only'] == 'true'),
          hasLength(1));
      expect(fixture.httpReads, 0);
    } finally {
      await tester.pumpWidget(const SizedBox());
      fixture.store.reset();
      fixture.close();
      await tester.pump();
    }
  });
}

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(
    locale: Locale('uz'),
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: InventoryMovementsScreen(),
  ));
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _LiveInventoryFixture {
  final opens = <InventoryViewQuery>[];
  final windows = <String, StreamController<Map<String, dynamic>>>{};
  int httpReads = 0;
  late final store = InventoryViewStore(
    snapshotLoader: (_) async {
      httpReads++;
      throw StateError('Unexpected inventory HTTP fallback');
    },
    liveLoader: (query, version) {
      opens.add(query);
      final key = query.kind == 'assets'
          ? query.parameters['current_user_states_only'] == 'true'
              ? 'states'
              : 'products'
          : query.kind == 'transfers'
              ? query.parameters['direction']!
              : query.kind;
      final controller = StreamController<Map<String, dynamic>>();
      windows[key] = controller;
      controller.add({
        'event': 'inventory.snapshot',
        'id': 'window',
        'epoch': 'test-epoch',
        'revision': 1,
        'version': 'test-version-1',
        'rows': switch (key) {
          'locations' => [
              {
                'id': 'inventory_location:warehouse:a',
                'kind': 'warehouse',
                'name': 'Material ombor',
                'warehouse_id': 'warehouse:a',
                'active': true,
              },
            ],
          'products' => [_asset('first', 'Original polymer')],
          'states' => [_stateAsset('state-first', 'Original state polymer')],
          _ => <Object>[],
        },
      });
      return controller.stream;
    },
  );

  void close() {
    for (final controller in windows.values) {
      unawaited(controller.close());
    }
  }
}

Map<String, dynamic> _delta(int revision, List<Object> upserts,
        List<String> removed, List<String> order) =>
    {
      'event': 'inventory.delta',
      'id': 'window',
      'epoch': 'test-epoch',
      'base_revision': revision - 1,
      'revision': revision,
      'version': 'test-version-$revision',
      'upserts': upserts,
      'removed': removed,
      'order': order,
    };

Map<String, dynamic> _asset(String id, String name, {String? label}) => {
      'kind': 'raw_material',
      'asset_ref': 'raw:$id',
      'custody_warehouse_id': 'warehouse:a',
      'custody_warehouse': 'Material ombor',
      'item_code': 'PE-$id',
      'item_name': name,
      'identifier': 'QR-$id',
      'qty': 10,
      'uom': 'kg',
      'status': 'available',
      'physical_location': {
        'id': 'inventory_location:warehouse:a',
        'kind': 'warehouse',
        'name': 'Material ombor',
      },
      'placement_version': 1,
      'order_assignment': label == null
          ? null
          : {
              'order_id': 'order-100',
              'order_label': label,
              'order_control': 'active',
            },
    };

Map<String, dynamic> _stateAsset(String id, String name) => _asset(id, name)
  ..['physical_location'] = {
    'id': 'inventory_location:state:bosma',
    'kind': 'state',
    'name': 'Bosma oldi',
  };
