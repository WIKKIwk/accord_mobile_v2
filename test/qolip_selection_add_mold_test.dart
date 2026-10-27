import 'dart:async';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_management_dialogs.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_products_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _target = QolipProduct(
  code: 'DEMO-HOTLUNCH',
  name: 'Hotlunch',
  itemGroup: 'Demo tayyor mahsulotlar',
  warehouse: 'Qolip ombori',
);
const _donor = QolipProduct(
  code: 'DEMO-SALAD',
  name: 'Salat set',
  itemGroup: 'Demo tayyor mahsulotlar',
  warehouse: 'Qolip ombori',
);

Finder _field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label);

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: home,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = MobileApi.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    resetMobileApiTestModeData();
    QolipCatalogStore.instance.reset();
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'selected-add-test';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Qolipchi',
      legalName: '',
      ref: 'selected-add-test',
      phone: '',
      avatarUrl: '',
      capabilities: ['qolip.manage'],
    );
    await api.qolipSaveProductSpecsBatch(
      product: _target,
      warehouse: _target.warehouse,
      specs: const [
        QolipProductSpecBatchItem(qolipCode: 'TARGET-1', size: 800),
        QolipProductSpecBatchItem(qolipCode: 'TARGET-2', size: 800),
      ],
    );
    await api.qolipSaveProductSpecsBatch(
      product: _donor,
      warehouse: _donor.warehouse,
      specs: const [QolipProductSpecBatchItem(qolipCode: 'DONOR-1', size: 420)],
    );
  });
  tearDown(() async {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    resetMobileApiTestModeData();
    QolipCatalogStore.instance.reset();
    await TestModeController.instance.setEnabled(false);
  });

  for (final existing in [false, true]) {
    testWidgets(
        '${existing ? 'mold' : 'container'} selection opens scoped add dialog and saves ${existing ? 'existing' : 'new'} code',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(const QolipProductsScreen()));
      await tester.pumpAndSettle();
      if (existing) {
        await tester.tap(find.text(_target.name));
        await tester.pumpAndSettle();
        final mold = find.widgetWithText(QolipCodeRow, 'TARGET-1');
        await tester
            .longPressAt(tester.getTopLeft(mold) + const Offset(16, 16));
      } else {
        await tester.longPress(find.text(_target.name));
      }
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('app-primary-navigation-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Qolip qo‘shish'));
      await tester.pumpAndSettle();

      expect(find.text('Qolip kodi qo‘shish'), findsOneWidget);
      expect(find.textContaining('${_target.name}\n'), findsOneWidget);
      expect(find.text('Yangi kod'), findsOneWidget);
      expect(find.text('Mavjud kod'), findsOneWidget);
      expect(find.text('Qolipni omborga biriktirish'), findsNothing);
      expect(
          tester.widget<TextField>(_field('Razmer')).controller!.text, '800');
      final save = find.widgetWithText(FilledButton, 'Saqlash');
      final cancel = find.widgetWithText(TextButton, 'Bekor qilish');
      bool saveEnabled() => tester.widget<FilledButton>(save).onPressed != null;
      expect(saveEnabled(), isFalse);
      expect(tester.getBottomLeft(save).dy,
          lessThanOrEqualTo(tester.getTopLeft(cancel).dy));

      if (existing) {
        await tester.enterText(_field('Razmer'), '0');
        await tester.pump();
        await tester.tap(find.text('Mavjud kod'));
        await tester.pumpAndSettle();
        expect(_field('Razmer'), findsNothing);
        expect(saveEnabled(), isFalse);
      }
      final code = existing ? 'DONOR-1' : 'TARGET-NEW';
      await tester.enterText(_field('Qolip code'), code);
      await tester.pump();
      expect(saveEnabled(), existing);
      if (!existing) {
        await tester.ensureVisible(find.text('Qizil'));
        await tester.tap(find.text('Qizil'));
        await tester.pumpAndSettle();
        expect(saveEnabled(), isTrue);
        for (final size in ['', '0', '-1', '2147483648', 'invalid']) {
          await tester.enterText(_field('Razmer'), size);
          await tester.pump();
          expect(saveEnabled(), isFalse, reason: 'Invalid size: $size');
        }
        await tester.enterText(_field('Razmer'), '800');
        await tester.pump();
        expect(saveEnabled(), isTrue);
      } else {
        await tester.tap(find.text('Yangi kod'));
        await tester.pumpAndSettle();
        expect(saveEnabled(), isFalse);
        await tester.tap(find.text('Mavjud kod'));
        await tester.pumpAndSettle();
        expect(saveEnabled(), isTrue);
      }
      for (final emptyCode in ['', '   ']) {
        await tester.enterText(_field('Qolip code'), emptyCode);
        await tester.pump();
        expect(saveEnabled(), isFalse);
      }
      await tester.enterText(_field('Qolip code'), code);
      await tester.pump();
      expect(saveEnabled(), isTrue);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Qolip kodi qo‘shish'), findsNothing);
      final products =
          await api.qolipProducts(limit: 20000, withQolipOnly: true);
      final saved = products.where((mold) => mold.qolipCode == code).toList();
      expect(saved.map((mold) => mold.code).toSet(),
          existing ? {_target.code, _donor.code} : {_target.code});
      expect(saved.every((mold) => mold.qolipSize == (existing ? 420 : 800)),
          isTrue);
      if (!existing) {
        expect(saved.single.qolipColor, '#E53935');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('saving disables actions and prevents a duplicate submission',
      (tester) async {
    final pending = Completer<void>();
    var submissions = 0;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () => unawaited(showQolipMoldAddDialog(
          context,
          scope: _target.name,
          allowExisting: true,
          onSave: (draft) {
            submissions++;
            expectSync(draft.code, 'DONOR-1');
            expectSync(draft.existingOnly, isTrue);
            return pending.future;
          },
        )),
        child: const Text('Open dialog'),
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mavjud kod'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Qolip code'), ' DONOR-1 ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
    await tester.pump();
    expect(submissions, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Bekor qilish'))
            .onPressed,
        isNull);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(submissions, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Qolip kodi qo‘shish'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
