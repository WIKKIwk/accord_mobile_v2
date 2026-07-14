import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/features/boyoqchi/models/returned_paint_models.dart';
import 'package:accord_mobile_v2/src/features/boyoqchi/presentation/boyoqchi_astatka_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Astatka page displays backend calculation fields', (
    tester,
  ) async {
    final request = ReturnedPaintRequest(
      id: 'returned-paint-1',
      orderId: 'order-1',
      orderCode: '9321',
      orderName: 'Estello',
      apparatus: '7 ta rangli bosma',
      senderRole: UserRole.aparatchi,
      senderRef: 'worker-1',
      senderDisplayName: 'Bosmachi',
      items: const [],
      createdAt: DateTime(2026, 7, 14, 12, 30),
      calculation: const ReturnedPaintCalculation(
        rasxotMixTotal: '12.5',
        astatkaMixTotal: '5',
        rasxotAlcohol: '3.75',
        astatkaAlcohol: '1.5',
        finalUsedAlcohol: '2.25',
        rasxotPurePaint: '12.25',
        astatkaPurePaint: '4.75',
        finalUsedPaint: '7.5',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: BoyoqchiAstatkaScreen(
          loader: () async => ReturnedPaintRequestPage(
            items: [request],
            hasMore: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Estello — #9321'));
    await tester.pumpAndSettle();

    expect(find.text('Order kodi'), findsOneWidget);
    expect(find.text('9321'), findsOneWidget);
    expect(find.text('Operator'), findsOneWidget);
    expect(find.text('Bosmachi'), findsOneWidget);
    expect(find.text('Rasxot jami Mix'), findsOneWidget);
    expect(find.text('12.5 kg'), findsWidgets);
    expect(find.text('Astatka jami Mix'), findsOneWidget);
    expect(find.text('5 kg'), findsOneWidget);
    expect(find.text('Yakuniy ishlatilgan spirt'), findsOneWidget);
    expect(find.text('2.25 kg'), findsOneWidget);
    expect(find.text('Rasxot sof bo‘yoq miqdori'), findsOneWidget);
    expect(find.text('Astatka sof bo‘yoq miqdori'), findsOneWidget);
    expect(find.text('Yakuniy ishlatilgan bo‘yoq'), findsOneWidget);
    expect(find.text('7.5 kg'), findsOneWidget);
  });
}
