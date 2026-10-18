import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/widgets/lists/m3_sequence_list.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_expandable_filter_chip.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_sequence_apparatus_filter.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_apparatus_filter_order_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _catalog = [
  AdminApparatus(id: 'apparatus:test:a', name: 'A'),
  AdminApparatus(id: 'apparatus:test:b', name: 'B'),
  AdminApparatus(id: 'apparatus:test:c', name: 'C'),
];

Widget _host({
  String? profileRef = 'ADMIN-A',
  List<AdminApparatus> catalog = _catalog,
  ValueChanged<AdminApparatus>? onSelect,
}) =>
    MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AdminSequenceApparatusFilter(
          apparatus: catalog,
          selectedId: _catalog[1].id,
          expanded: true,
          onToggle: () {},
          onSelect: onSelect ?? (_) {},
          editableProfileRef: profileRef,
        ),
      ),
    );

List<String> _displayedIds(WidgetTester tester) => tester
    .widget<AdminExpandableFilterChip<String>>(
      find.byType(AdminExpandableFilterChip<String>),
    )
    .options
    .map((option) => option.value)
    .toList();

Future<void> _choose(
  WidgetTester tester,
  String apparatus,
  String action,
) async {
  await tester.longPress(
    find.byKey(ValueKey('admin-filter-option-$apparatus')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('apparatus-filter-order-$action')));
  await tester.pumpAndSettle();
}

List<String> _editorIds(WidgetTester tester) {
  final list = tester.widget<M3SequenceList>(find.byType(M3SequenceList));
  return [
    for (var index = 0; index < list.itemCount; index++)
      (list.itemKey(index) as ValueKey<String>)
          .value
          .replaceFirst('apparatus-filter-order-row-', ''),
  ];
}

Future<void> _dragToRow(
  WidgetTester tester,
  String sourceId,
  String targetId,
) async {
  final source = find.byKey(ValueKey('apparatus-filter-order-row-$sourceId'));
  final target = find.byKey(ValueKey('apparatus-filter-order-row-$targetId'));
  final handle = find.descendant(
    of: source,
    matching: find.byType(M3SequenceDragHandle),
  );
  final start = tester.getCenter(handle);
  final end = Offset(start.dx, tester.getCenter(target).dy);
  final gesture = await tester.startGesture(start);
  // Let the list update its gap during the gesture, as it does for a real drag.
  for (var step = 1; step <= 12; step++) {
    await gesture.moveTo(Offset.lerp(start, end, step / 12)!);
    await tester.pump(const Duration(milliseconds: 50));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('local order is normalized, isolated by profile and resettable',
      () async {
    await AdminApparatusFilterOrderStore.save('ADMIN-A', [
      ' ${_catalog[2].id} ',
      '',
      _catalog[2].id,
      _catalog[0].id,
    ]);
    expect(await AdminApparatusFilterOrderStore.load('ADMIN-A'), [
      _catalog[2].id,
      _catalog[0].id,
    ]);
    expect(await AdminApparatusFilterOrderStore.load('ADMIN-B'), isEmpty);
    await AdminApparatusFilterOrderStore.save('ADMIN-A', const []);
    expect(await AdminApparatusFilterOrderStore.load('ADMIN-A'), isEmpty);
    expect(
      (await SharedPreferences.getInstance()).containsKey(
        AdminApparatusFilterOrderStore.preferenceKey('ADMIN-A'),
      ),
      isFalse,
    );
    expect(
      () => AdminApparatusFilterOrderStore.preferenceKey(' '),
      throwsArgumentError,
    );
  });

  test('display order handles rename, removal and new IDs without mutations',
      () {
    final renamed = _catalog[2].copyWith(name: 'Renamed C');
    final catalog = [_catalog[0], renamed, _catalog[1]];
    final savedIds = [_catalog[2].id, 'removed', _catalog[2].id];
    final result = AdminApparatusFilterOrderStore.apply(catalog, savedIds);
    expect(result, [renamed, _catalog[0], _catalog[1]]);
    expect(catalog, [_catalog[0], renamed, _catalog[1]]);
    expect(savedIds, [_catalog[2].id, 'removed', _catalog[2].id]);
    expect(identical(result.first, renamed), isTrue);
  });

  testWidgets('menu keeps editing and reset without changing selection', (
    tester,
  ) async {
    final saved = [_catalog[2].id, _catalog[0].id, _catalog[1].id];
    await AdminApparatusFilterOrderStore.save('ADMIN-A', saved);
    final selections = <String>[];
    Widget host() => _host(onSelect: (item) => selections.add(item.id));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(_displayedIds(tester), saved);
    expect(find.text('Aparat: B'), findsOneWidget);
    await tester.longPress(find.byKey(const ValueKey('admin-filter-option-C')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('apparatus-filter-order-edit')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('apparatus-filter-order-reset')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('apparatus-filter-order-top')), findsNothing);
    expect(find.byKey(const ValueKey('apparatus-filter-order-bottom')),
        findsNothing);
    await tester
        .tap(find.byKey(const ValueKey('apparatus-filter-order-reset')));
    await tester.pumpAndSettle();
    expect(_displayedIds(tester), _catalog.map((item) => item.id));
    expect(await AdminApparatusFilterOrderStore.load('ADMIN-A'), isEmpty);
    expect(selections, isEmpty);

    await tester.tap(find.byKey(const ValueKey('admin-filter-option-C')));
    await tester.pumpAndSettle();
    expect(selections, [_catalog[2].id]);
  });

  testWidgets('catalog refresh keeps saved IDs and adds new machines at end', (
    tester,
  ) async {
    await AdminApparatusFilterOrderStore.save('ADMIN-A', [
      _catalog[2].id,
      _catalog[0].id,
      _catalog[1].id,
    ]);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    const added = AdminApparatus(id: 'apparatus:test:d', name: 'D');
    await tester.pumpWidget(
      _host(catalog: [added, _catalog[0], _catalog[2].copyWith(name: 'New C')]),
    );
    await tester.pumpAndSettle();
    expect(_displayedIds(tester), [_catalog[2].id, _catalog[0].id, added.id]);
    expect(find.text('New C'), findsOneWidget);
  });

  testWidgets('editor drags upward and downward into the middle and persists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const catalog = [
      ..._catalog,
      AdminApparatus(id: 'apparatus:test:d', name: 'D'),
      AdminApparatus(id: 'apparatus:test:e', name: 'E'),
    ];
    final selections = <String>[];
    Widget host() => _host(
          catalog: catalog,
          onSelect: (item) => selections.add(item.id),
        );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await _choose(tester, 'B', 'edit');
    await _dragToRow(tester, catalog[4].id, catalog[2].id);
    expect(_editorIds(tester), [
      catalog[0].id,
      catalog[1].id,
      catalog[4].id,
      catalog[2].id,
      catalog[3].id,
    ]);
    await _dragToRow(tester, catalog[0].id, catalog[2].id);
    final expected = [
      catalog[1].id,
      catalog[4].id,
      catalog[2].id,
      catalog[0].id,
      catalog[3].id,
    ];
    expect(_editorIds(tester), expected);
    expect(await AdminApparatusFilterOrderStore.load('ADMIN-A'), isEmpty);
    await tester.tap(find.byKey(const ValueKey('apparatus-filter-order-save')));
    await tester.pumpAndSettle();
    expect(_displayedIds(tester), expected);
    expect(await AdminApparatusFilterOrderStore.load('ADMIN-A'), expected);
    expect(find.text('Aparat: B'), findsOneWidget);
    expect(selections, isEmpty);
    expect(catalog.map((item) => item.name), ['A', 'B', 'C', 'D', 'E']);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(_displayedIds(tester), expected);
  });

  testWidgets('cancelling the editor keeps the saved filter order',
      (tester) async {
    final saved = [_catalog[1].id, _catalog[2].id, _catalog[0].id];
    await AdminApparatusFilterOrderStore.save('ADMIN-A', saved);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await _choose(tester, 'B', 'edit');
    tester.widget<M3SequenceList>(find.byType(M3SequenceList)).onReorder(0, 1);
    await tester.pumpAndSettle();
    expect(_editorIds(tester), isNot(saved));
    await tester
        .tap(find.byKey(const ValueKey('apparatus-filter-order-cancel')));
    await tester.pumpAndSettle();
    expect(_displayedIds(tester), saved);
    expect(await AdminApparatusFilterOrderStore.load('ADMIN-A'), saved);
  });

  testWidgets('editor save reconciles catalog additions, removals and renames',
      (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await _choose(tester, 'B', 'edit');
    tester.widget<M3SequenceList>(find.byType(M3SequenceList)).onReorder(2, 1);
    await tester.pumpAndSettle();
    const added = AdminApparatus(id: 'apparatus:test:d', name: 'D');
    await tester.pumpWidget(_host(catalog: [
      added,
      _catalog[0],
      _catalog[2].copyWith(name: 'Renamed C'),
    ]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apparatus-filter-order-save')));
    await tester.pumpAndSettle();
    final expected = [_catalog[0].id, _catalog[2].id, added.id];
    expect(_displayedIds(tester), expected);
    expect(await AdminApparatusFilterOrderStore.load('ADMIN-A'), expected);
    expect(find.text('Renamed C'), findsOneWidget);
  });

  testWidgets('profile switch prevents saving an editor from the old profile', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await _choose(tester, 'B', 'edit');
    tester.widget<M3SequenceList>(find.byType(M3SequenceList)).onReorder(2, 1);
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(profileRef: 'ADMIN-B'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apparatus-filter-order-save')));
    await tester.pumpAndSettle();
    expect(_displayedIds(tester), _catalog.map((item) => item.id));
    expect(await AdminApparatusFilterOrderStore.load('ADMIN-A'), isEmpty);
    expect(await AdminApparatusFilterOrderStore.load('ADMIN-B'), isEmpty);
  });

  testWidgets('profile switch rejects an old menu and non-admin has no actions',
      (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('admin-filter-option-C')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(profileRef: 'ADMIN-B'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apparatus-filter-order-edit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('apparatus-filter-order-editor')),
        findsNothing);
    expect(_displayedIds(tester), _catalog.map((item) => item.id));
    expect(await AdminApparatusFilterOrderStore.load('ADMIN-A'), isEmpty);
    expect(await AdminApparatusFilterOrderStore.load('ADMIN-B'), isEmpty);

    await _choose(tester, 'C', 'edit');
    tester.widget<M3SequenceList>(find.byType(M3SequenceList)).onReorder(2, 0);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apparatus-filter-order-save')));
    await tester.pumpAndSettle();
    expect(_displayedIds(tester).first, _catalog[2].id);
    await tester.pumpWidget(_host(profileRef: null));
    await tester.pumpAndSettle();
    expect(_displayedIds(tester), _catalog.map((item) => item.id));
    await tester.longPress(find.byKey(const ValueKey('admin-filter-option-C')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('apparatus-filter-order-edit')),
        findsNothing);
    final filter = tester.widget<AdminExpandableFilterChip<String>>(
      find.byType(AdminExpandableFilterChip<String>),
    );
    expect(
        filter.options.every((option) => option.onLongPress == null), isTrue);
  });
}
