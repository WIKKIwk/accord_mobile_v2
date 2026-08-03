import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_work_instructions_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('shows instructions only for the worker assigned apparatus', (
    tester,
  ) async {
    AppSession.instance.token = 'worker-token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Aparatchi',
      legalName: '',
      ref: 'aparatchi-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
      assignedApparatus: [
        '7 ta rangli bosma aparat',
        'Laminatsiya 1',
        'Rezka 1',
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AparatchiWorkInstructionsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kuzatishdan zakazni ochish'), findsOneWidget);
    expect(find.textContaining('drawerdagi Kuzatish'), findsOneWidget);
    expect(find.textContaining('Zakaz yo‘q'), findsOneWidget);
    expect(find.text('Ekrandagi holatlar va tugmalar'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('7 ta rangli bosma aparat'), 300);
    expect(find.text('7 ta rangli bosma aparat'), findsOneWidget);
    expect(
      find.textContaining('Qoliplar qatorini oching'),
      findsOneWidget,
    );
    expect(find.textContaining('Pauza miqdori oynasi'), findsOneWidget);
    expect(find.textContaining('Rasxot va Astatka'), findsOneWidget);
    expect(
      find.textContaining(
        'Pauzada Jami chiqindi va kraska astatkasi kiritilmaydi',
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(find.text('Laminatsiya 1'), 300);
    expect(find.text('Laminatsiya 1'), findsOneWidget);
    expect(find.textContaining('Plyonkadan ortgan rulon'), findsWidgets);
    await tester.scrollUntilVisible(
      find.textContaining(
        'Pauzada Plyonkadan ortgan rulon ham, Jami chiqindi (atxot) ham kiritilmaydi',
      ),
      300,
    );
    expect(
      find.textContaining(
        'Pauzada Plyonkadan ortgan rulon ham, Jami chiqindi (atxot) ham kiritilmaydi',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.textContaining('order bo‘yicha jami atxot miqdorini'),
      300,
    );
    expect(find.textContaining('order bo‘yicha jami atxot miqdorini'),
        findsOneWidget);

    await tester.scrollUntilVisible(find.text('Rezka 1'), 300);
    expect(find.text('Rezka 1'), findsOneWidget);
    expect(
      find.textContaining('Tayyor mahsulot chetidan chiqqan chiqindi'),
      findsWidgets,
    );
    expect(find.text('Godex aparat - DEMO'), findsNothing);
  });
}
