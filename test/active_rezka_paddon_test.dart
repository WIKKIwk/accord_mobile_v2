import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/production/active_rezka_paddon_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/widgets/active_rezka_paddon_action.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const apparatus = 'apparatus:default:asset-010';

SessionProfile profile(String ref) => SessionProfile(
    role: UserRole.aparatchi,
    ref: ref,
    displayName: ref,
    legalName: '',
    phone: '',
    avatarUrl: '',
    capabilities: const ['apparatus.queue.read', 'apparatus.queue.manage'],
    assignedApparatus: const [apparatus]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ServerEndpointStore.instance.clearOverride();
    AppSession.instance.profile = profile('worker-1');
  });
  tearDown(() async {
    AppSession.instance.profile = null;
    await ServerEndpointStore.instance.clearOverride();
  });

  test(
      'active pallet survives reload and is isolated by server account and apparatus',
      () async {
    await ActiveRezkaPaddonStore.save(apparatus, '00001');
    expect(await ActiveRezkaPaddonStore.load(apparatus), '00001');
    expect(await ActiveRezkaPaddonStore.load('apparatus:default:asset-007'),
        isNull);
    AppSession.instance.profile = profile('worker-2');
    expect(await ActiveRezkaPaddonStore.load(apparatus), isNull);
    await ActiveRezkaPaddonStore.save(apparatus, '00002');
    AppSession.instance.profile = profile('worker-1');
    expect(await ActiveRezkaPaddonStore.load(apparatus), '00001');
    await ServerEndpointStore.instance.setBaseUrl('http://127.0.0.1:9999');
    expect(await ActiveRezkaPaddonStore.load(apparatus), isNull);
    await ServerEndpointStore.instance.clearOverride();
    expect(await ActiveRezkaPaddonStore.load(apparatus), '00001');
    await ActiveRezkaPaddonStore.save(apparatus, null);
    expect(await ActiveRezkaPaddonStore.load(apparatus), isNull);
  });

  testWidgets(
      'small active pallet icon selects restores changes and clears the pallet',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Future<List<AdminPaddon>> load() async => [
          for (final code in ['00001', '00002'])
            AdminPaddon(
              id: code,
              code: code,
              location: '',
              note: '',
              createdByRef: 'worker-1',
              createdByDisplayName: 'Rezka',
              createdAtUnix: 1,
              updatedAtUnix: 1,
              itemCount: 2,
            )
        ];
    Widget app() => MaterialApp(
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
              appBar: AppBar(actions: [
            ActiveRezkaPaddonAction(apparatusId: apparatus, loader: load)
          ])),
        );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byTooltip('Faol paddonni tanlang'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rezka-active-paddon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rezka-paddon-00001')));
    await tester.pumpAndSettle();
    expect(await ActiveRezkaPaddonStore.load(apparatus), '00001');
    expect(find.byTooltip('Faol paddon: 00001'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byTooltip('Faol paddon: 00001'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rezka-active-paddon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rezka-paddon-00002')));
    await tester.pumpAndSettle();
    expect(await ActiveRezkaPaddonStore.load(apparatus), '00002');
    await tester.tap(find.byKey(const ValueKey('rezka-active-paddon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rezka-paddon-none')));
    await tester.pumpAndSettle();
    expect(await ActiveRezkaPaddonStore.load(apparatus), isNull);
    expect(find.byTooltip('Faol paddonni tanlang'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
