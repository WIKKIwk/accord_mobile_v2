import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/features/boyoqchi/models/returned_paint_models.dart';
import 'package:accord_mobile_v2/src/features/boyoqchi/presentation/boyoqchi_astatka_screen.dart';
import 'package:accord_mobile_v2/src/features/boyoqchi/state/returned_paint_draft_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    ReturnedPaintDraftStore.instance.resetMemoryForTest();
  });

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

  testWidgets('image-only report opens the shared form and becomes calculated',
      (
    tester,
  ) async {
    var request = ReturnedPaintRequest(
      id: 'returned-paint-waiting',
      orderId: 'order-image',
      orderCode: '8963',
      orderName: 'Rasmli order',
      apparatus: '7 ta rangli bosma',
      senderRole: UserRole.aparatchi,
      senderRef: 'worker-image',
      senderDisplayName: 'Bosmachi',
      items: const [],
      status: ReturnedPaintStatus.waitingForBoyoqchiInput,
      image: const ReturnedPaintImage(
        imageId: 'image-1',
        imageName: 'qoldiq.jpg',
        imageMime: 'image/jpeg',
        imageSizeBytes: 100,
        imageUrl: '',
      ),
      createdAt: DateTime(2026, 7, 15, 14, 30),
    );
    ReturnedPaintCompleteSubmission? submitted;

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
          completer: (input) async {
            submitted = input;
            request = request.copyWith(
              items: input.items,
              status: ReturnedPaintStatus.completed,
              calculation: const ReturnedPaintCalculation(
                rasxotMixTotal: '10',
                astatkaMixTotal: '1',
                rasxotAlcohol: '3',
                astatkaAlcohol: '0.3',
                finalUsedAlcohol: '2.7',
                rasxotPurePaint: '9',
                astatkaPurePaint: '0.7',
                finalUsedPaint: '8.3',
              ),
            );
            return request;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rasmli order — #8963'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Rasmdagi qiymatlarni Bo‘yoqchi to‘ldirishi kerak'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);

    await tester.ensureVisible(find.text('Qaytarilgan bo‘yoq'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qaytarilgan bo‘yoq'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Oq'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Oq'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Oq'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byKey(const ValueKey('returned-paint-fields')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), '10');
    await tester.enterText(fields.at(1), '2');
    await tester.enterText(fields.at(2), '1');
    await tester.ensureVisible(find.text('Saqlash'));
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(
      submitted!.items.fold<int>(0, (sum, item) => sum + item.values.length),
      3,
    );
    await tester.tap(find.text('Rasmli order — #8963'));
    await tester.pumpAndSettle();
    expect(find.text('Yakuniy ishlatilgan bo‘yoq'), findsOneWidget);
    expect(find.text('8.3 kg'), findsOneWidget);
  });
}
