import 'package:accord_mobile_v2/src/features/admin/presentation/admin_factory_map_screen.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'dart:async';
import 'package:accord_mobile_v2/src/features/admin/logic/factory_map_bindings.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_factory_map_viewer.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_dock.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_shell.dart';

void main() {
  testWidgets(
      'loading blocks attachment, confirmed unlink and reattach use one save each',
      (tester) async {
    Future<void> settleSheet() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
    }

    SharedPreferences.setMockInitialValues({});
    var current = const AdminApparatus(
        id: 'apparatus:test:a',
        name: 'Test machine',
        sourceRevision: 1,
        factoryMapObjectId: 'node:7');
    final loading = Completer<List<AdminApparatus>>();
    var loads = 0;
    var writes = 0;
    final bindings = FactoryMapBindings(
        load: () async {
          if (++loads == 1) return loading.future;
          return [current];
        },
        read: (_) async => current,
        write: (apparatus, objectId) async {
          writes++;
          return current = apparatus.copyWith(
              factoryMapObjectId: objectId,
              sourceRevision: apparatus.sourceRevision + 1);
        });
    late AdminFactoryMapViewer renderedViewer;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      home: AdminFactoryMapScreen(
          bindings: bindings,
          viewerBuilder: (viewer) {
            renderedViewer = viewer;
            return const SizedBox();
          }),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(tester.widget<AdminDock>(find.byType(AdminDock)).showPrimaryFab,
        isFalse);
    expect(
        find.ancestor(
            of: find.byKey(const ValueKey('factory-map-viewport')),
            matching: find.byType(ListView)),
        findsNothing);
    expect(
        tester
            .getSize(find.byKey(const ValueKey('factory-map-viewport')))
            .height,
        greaterThan(350));
    AdminFactoryMapViewer viewer() => renderedViewer;
    void tapMachine() => viewer().onObjectTap!(
        const FactoryMapObjectSelection(objectId: 'node:7', label: 'Machine'));
    tapMachine();
    await tester.pump();
    expect(find.text('Aparat ulanmagan'), findsNothing);
    expect(viewer().focusedObjectId, isEmpty);
    loading.complete([current]);
    await tester.pump();
    tapMachine();
    await tester.pump();
    expect(viewer().renderSuspended, isFalse,
        reason: 'the camera focus animation still needs rendering');
    viewer().onFocusComplete!('node:7');
    await tester.pump();
    expect(viewer().renderSuspended, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('factory-map-unlink')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('factory-map-unlink')));
    await settleSheet();
    expect(writes, 0);
    await tester.tap(find.widgetWithText(TextButton, 'Bekor qilish').last);
    await settleSheet();
    expect(writes, 0);
    await tester.tap(find.byKey(const ValueKey('factory-map-unlink')));
    await settleSheet();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await settleSheet();
    expect(writes, 1);
    expect(current.factoryMapObjectId, isEmpty);
    expect(viewer().renderSuspended, isFalse);
    tapMachine();
    await settleSheet();
    expect(viewer().renderSuspended, isTrue,
        reason: 'the unassigned sheet also freezes the background');
    await tester.tap(find.text('Aparat ulash'));
    await settleSheet();
    await tester.tap(find.text('Test machine'));
    await settleSheet();
    expect(writes, 2);
    expect(current.factoryMapObjectId, 'node:7');
    expect(viewer().focusedObjectId, 'node:7');
    expect(viewer().renderSuspended, isFalse);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox.shrink());
    bindings.dispose();
    // Page-local configuration: navigating away never leaves a global FAB flag.
    expect(
        const AdminShell(
                title: '', activeTab: AdminDockTab.home, child: SizedBox())
            .showPrimaryFab,
        isTrue);
  });

  testWidgets('factory model is deferred until after the first route frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                PageRouteBuilder<void>(
                  transitionDuration: const Duration(seconds: 1),
                  pageBuilder: (_, __, ___) => const AdminFactoryMapScreen(),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      find.byType(AdminFactoryMapScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(ModelViewer, skipOffstage: false), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ModelViewer, skipOffstage: false), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
