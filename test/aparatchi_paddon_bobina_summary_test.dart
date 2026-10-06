import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_paddon_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AdminPaddonSnapshot _snapshot(List<double?> weights,
    {List<double?> availableWeights = const []}) {
  AdminProgressBatch batch(int index, double? kg, {bool available = false}) =>
      AdminProgressBatch.fromJson({
        'batch_id': '${available ? 'available' : 'assigned'}-$index',
        'order_id': 'order-${index % 2}',
        'apparatus': 'apparatus:default:asset-010',
        'qr_payload': '40010000000${available ? 'B' : 'A'}$index',
        'produced_qty': 500,
        'uom': 'm',
        'bobina_kg': kg,
        'payload_json': {'contained_kadr_count': 9},
      });
  return AdminPaddonSnapshot(
    paddon: AdminPaddon(
      id: 'paddon-4',
      code: '00004',
      location: 'qobil oka',
      note: '',
      createdByRef: 'worker-1',
      createdByDisplayName: 'Anis',
      createdAtUnix: 1,
      updatedAtUnix: 2,
      itemCount: weights.length,
      totalGrossKg: 568,
      totalNetKg: 512,
    ),
    items: [
      for (var index = 0; index < weights.length; index++)
        batch(index, weights[index]),
    ],
    availableItems: [
      for (var index = 0; index < availableWeights.length; index++)
        batch(index, availableWeights[index], available: true),
    ],
  );
}

Widget _app(Future<AdminPaddonSnapshot> Function() loader,
    {String locale = 'uz', double textScale = 1, bool dark = false}) {
  return MaterialApp(
    locale: Locale(locale),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF384C78),
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: AparatchiPaddonDetailScreen(
      code: '00004',
      loader: loader,
      apparatusLoader: () async => const [],
    ),
  );
}

Finder _group(Object weight) =>
    find.byKey(ValueKey('paddon-bobina-group-$weight'));

void _expectGroup(Object weight, String label, String count) {
  expect(_group(weight), findsOneWidget);
  expect(find.descendant(of: _group(weight), matching: find.text(label)),
      findsOneWidget);
  expect(find.descendant(of: _group(weight), matching: find.text(count)),
      findsOneWidget);
}

Finder _wips({bool available = false}) => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith(
        available ? 'paddon-available-wip-card-' : 'paddon-wip-card-',
      );
});

Future<void> _tapGroup(WidgetTester tester, Object weight) async {
  await tester.ensureVisible(_group(weight));
  await tester.pumpAndSettle();
  await tester.tap(_group(weight));
  await tester.pumpAndSettle();
}

void _expectSelected(Object weight, bool selected) {
  expect(
    find.descendant(
      of: _group(weight),
      matching: find.byWidgetPredicate((widget) =>
          widget is Semantics &&
          widget.properties.button == true &&
          widget.properties.selected == selected),
    ),
    findsOneWidget,
  );
}

Future<void> _tapFabEditAction(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey('app-primary-navigation-button')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(RegExp(r'^(Qo‘shish|Olib tashlash)')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Anis',
      legalName: '',
      ref: 'worker-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
      assignedApparatus: ['apparatus:default:asset-010'],
    );
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('bobbin groups filter WIPs and toggle back to the full list',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var loads = 0;
    await tester.pumpWidget(_app(() async {
      loads++;
      return _snapshot([2, 2, 4, 3, 4]);
    }));
    await tester.pumpAndSettle();
    expect(_wips(), findsNWidgets(5));

    await _tapGroup(tester, 2000000);
    expect(_wips(), findsNWidgets(2));
    expect(find.byKey(const ValueKey('paddon-wip-card-assigned-0')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('paddon-wip-card-assigned-1')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('paddon-wip-card-assigned-2')),
        findsNothing);
    _expectSelected(2000000, true);
    _expectSelected(4000000, false);
    _expectGroup(2000000, '2 kg', '2 ta');
    _expectGroup(4000000, '4 kg', '2 ta');
    expect(find.text('WIP: 5'), findsOneWidget);
    final heading = find.ancestor(
      of: find.text('Paddon ichidagi WIP lar'),
      matching: find.byType(Row),
    );
    expect(find.descendant(of: heading, matching: find.text('2 ta')),
        findsOneWidget);

    await _tapGroup(tester, 4000000);
    expect(_wips(), findsNWidgets(2));
    expect(find.byKey(const ValueKey('paddon-wip-card-assigned-2')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('paddon-wip-card-assigned-4')),
        findsOneWidget);
    _expectSelected(2000000, false);
    _expectSelected(4000000, true);

    await _tapGroup(tester, 4000000);
    expect(_wips(), findsNWidgets(5));
    _expectSelected(4000000, false);
    expect(loads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter matches grouped precision and unknown bobbin weights',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(() async => _snapshot([
      0.8080001, 0.808, 0.808001, null, 0, -1,
      double.nan, double.infinity,
    ])));
    await tester.pumpAndSettle();
    await _tapGroup(tester, 808000);
    expect(_wips(), findsNWidgets(2));
    expect(find.byKey(const ValueKey('paddon-wip-card-assigned-0')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('paddon-wip-card-assigned-1')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('paddon-wip-card-assigned-2')),
        findsNothing);

    await _tapGroup(tester, 'unknown');
    expect(_wips(), findsNWidgets(5));
    for (var index = 3; index < 8; index++) {
      expect(find.byKey(ValueKey('paddon-wip-card-assigned-$index')),
          findsOneWidget);
    }
    _expectSelected('unknown', true);
    _expectSelected(808000, false);
    await _tapGroup(tester, 'unknown');
    expect(_wips(), findsNWidgets(8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh clears a filter when the pallet contents change',
      (tester) async {
    var loads = 0;
    await tester.pumpWidget(_app(
      () async => _snapshot(loads++ == 0 ? [2, 4, 4] : [4, null]),
    ));
    await tester.pumpAndSettle();
    await _tapGroup(tester, 2000000);
    expect(_wips(), findsOneWidget);
    final refresh = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();
    await refresh;
    expect(_wips(), findsNWidgets(2));
    expect(_group(2000000), findsNothing);
    _expectSelected(4000000, false);
    _expectSelected('unknown', false);
    expect(loads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters respect add and remove lists without hidden selections',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(() async => _snapshot(
      [2, 4], availableWeights: [2, 2, 4, 99],
    )));
    await tester.pumpAndSettle();
    await _tapGroup(tester, 2000000);
    expect(_wips(), findsOneWidget);
    await _tapFabEditAction(tester);
    expect(_wips(available: true), findsNWidgets(4));
    _expectSelected(2000000, false);
    await _tapGroup(tester, 4000000);
    expect(_wips(available: true), findsOneWidget);
    final availableWip = find.byKey(
      const ValueKey('paddon-available-wip-card-available-2'),
    );
    await tester.ensureVisible(availableWip);
    await tester.pumpAndSettle();
    await tester.tap(availableWip);
    await tester.pumpAndSettle();
    await _tapGroup(tester, 2000000);
    expect(_wips(available: true), findsNWidgets(2));
    // No selected hidden 4kg WIP remains: the action switches to remove mode.
    await _tapFabEditAction(tester);
    expect(_wips(), findsNWidgets(2));
    expect(_wips(available: true), findsNothing);
    _expectSelected(2000000, false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('header counts assigned physical rolls by bobbin weight',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final data = _snapshot([
      ...List.filled(6, 4.0),
      ...List.filled(8, 3.0),
      ...List.filled(2, 2.0),
      ...List.filled(4, 1.0),
    ], availableWeights: [
      99,
      4
    ]);
    await tester.pumpWidget(_app(() async => data));
    await tester.pumpAndSettle();

    _expectGroup(1000000, '1 kg', '4 ta');
    _expectGroup(2000000, '2 kg', '2 ta');
    _expectGroup(3000000, '3 kg', '8 ta');
    _expectGroup(4000000, '4 kg', '6 ta');
    expect(find.text('99 kg'), findsNothing);
    expect(_group('unknown'), findsNothing);
    expect(find.text('WIP: 20'), findsOneWidget);
    final summary = find.byKey(const ValueKey('paddon-bobina-summary'));
    expect(find.ancestor(of: summary, matching: find.byType(Card)),
        findsOneWidget);
    expect(tester.getTopLeft(_group(1000000)).dx,
        lessThan(tester.getTopLeft(_group(2000000)).dx));
    expect(tester.getTopLeft(_group(1000000)).dy,
        lessThan(tester.getTopLeft(_group(3000000)).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps fractional cores and unknown measurements distinct',
      (tester) async {
    final data = _snapshot([
      0.808,
      0.8080001,
      0.808001,
      null,
      0,
      -1,
      double.nan,
      double.infinity,
    ]);
    await tester.pumpWidget(_app(() async => data));
    await tester.pumpAndSettle();

    _expectGroup(808000, '0.808 kg', '2 ta');
    _expectGroup(808001, '0.808001 kg', '1 ta');
    _expectGroup('unknown', 'Kiritilmagan', '5 ta');
    expect(find.text('0 kg'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh replaces groups after pallet membership changes',
      (tester) async {
    var loads = 0;
    await tester.pumpWidget(
        _app(() async => _snapshot(loads++ == 0 ? [2, 2, 4] : [4, 4, null])));
    await tester.pumpAndSettle();
    _expectGroup(2000000, '2 kg', '2 ta');
    _expectGroup(4000000, '4 kg', '1 ta');

    final refresh = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();
    await refresh;

    expect(_group(2000000), findsNothing);
    _expectGroup(4000000, '4 kg', '2 ta');
    _expectGroup('unknown', 'Kiritilmagan', '1 ta');
    expect(loads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty pallet has no bobbin groups', (tester) async {
    await tester.pumpWidget(_app(() async => _snapshot([])));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paddon-bobina-summary')), findsNothing);
  });

  for (final locale in ['uz', 'en', 'ru', 'ur']) {
    testWidgets('narrow $locale card accommodates large text', (tester) async {
      await tester.binding.setSurfaceSize(const Size(280, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(
        () async => _snapshot([0.808001, 2, 2, null]),
        locale: locale,
        textScale: 1.8,
        dark: true,
      ));
      await tester.pumpAndSettle();
      expect(_group(808001), findsOneWidget);
      expect(_group('unknown'), findsOneWidget);
      expect(tester.getTopLeft(_group(808001)).dx,
          tester.getTopLeft(_group(2000000)).dx);
      expect(tester.getTopLeft(_group(808001)).dy,
          lessThan(tester.getTopLeft(_group(2000000)).dy));
      expect(find.text('worker.paddon.bobina_summary'), findsNothing);
      expect(find.text('worker.paddon.bobina_unknown'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
