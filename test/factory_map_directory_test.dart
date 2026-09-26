import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/factory_map_bindings.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/factory_map_live.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/factory_map_directory.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'phone directory searches, filters and returns a machine using existing snapshots',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var reads = 0;
    const machines = [
      AdminApparatus(
          id: 'a', name: 'Bosma 8 rang', factoryMapObjectId: 'node:7'),
      AdminApparatus(id: 'b', name: 'Rezka 2', factoryMapObjectId: 'node:20'),
    ];
    final bindings = FactoryMapBindings(load: () async => machines);
    final live = FactoryMapLive(load: () async {
      reads++;
      return const AdminApparatusQueueSnapshot(
        sequences: {
          'a': ['one'],
          'b': ['two']
        },
        visibleOrderIds: {
          'a': ['one'],
          'b': ['two']
        },
        queueStates: {
          'a': {'one': 'in_progress'},
          'b': {'two': 'paused'}
        },
        queuePolicies: {},
        orderControls: {},
        epoch: 'test',
        revision: 1,
      );
    });
    addTearDown(bindings.dispose);
    addTearDown(live.dispose);
    await bindings.refresh();
    live.start();
    AdminApparatus? selected;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      home: Builder(
          builder: (context) => Scaffold(
                  body: TextButton(
                onPressed: () async {
                  selected = await showModalBottomSheet<AdminApparatus>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => SizedBox(
                          height: 660,
                          child: FactoryMapDirectory(
                              bindings: bindings, live: live)));
                },
                child: const Text('Open'),
              ))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Bosma 8 rang'), findsOneWidget);
    expect(find.text('Rezka 2'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('factory-map-search')), 'REZKA');
    await tester.pump();
    expect(find.text('Bosma 8 rang'), findsNothing);
    expect(find.text('Rezka 2'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('factory-map-search')), '');
    await tester
        .tap(find.byKey(const ValueKey('factory-map-machine-filter-working')));
    await tester.pumpAndSettle();
    expect(find.text('Bosma 8 rang'), findsOneWidget);
    expect(find.text('Rezka 2'), findsNothing);
    expect(reads, 1, reason: 'search/filter must not fetch again');
    expect(tester.takeException(), isNull, reason: 'phone layout must fit');
    await tester.tap(find.byKey(const ValueKey('factory-map-machine-a')));
    await tester.pumpAndSettle();
    expect(selected?.id, 'a');
    await tester.pumpWidget(const SizedBox.shrink());
    live.stop();
  });
}
