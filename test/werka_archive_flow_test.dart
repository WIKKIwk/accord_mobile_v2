import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/werka_archive_daily_calendar_screen.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/werka_archive_monthly_calendar_screen.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/werka_archive_sent_hub_screen.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/werka_archive_yearly_calendar_screen.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/werka_archive_screen.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/werka_archive_list_screen.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/werka_archive_period_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('uz'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    onGenerateRoute: AppRouter.onGenerateRoute,
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppSession.instance
      ..token = 'token'
      ..profile = const SessionProfile(
        role: UserRole.werka,
        displayName: 'Werka',
        legalName: '',
        ref: 'werka-archive-test',
        phone: '',
        avatarUrl: '',
        capabilities: ['werka.access'],
      );
  });
  tearDown(() {
    AppSession.instance
      ..token = null
      ..profile = null;
  });

  _archiveTest('monthly archive list screen builds without exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const WerkaArchiveListScreen(
          args: WerkaArchiveListArgs(
            kind: WerkaArchiveKind.sent,
            period: WerkaArchivePeriod.monthly,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });

  _archiveTest('period screen opens monthly calendar without exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const WerkaArchivePeriodScreen(kind: WerkaArchiveKind.sent)),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Oylik'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(tester.takeException(), isNull);
    expect(find.byType(WerkaArchiveMonthlyCalendarScreen), findsOneWidget);
  });

  _archiveTest('archive screen opens sent archive hub without exception', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const WerkaArchiveScreen()));

    await tester.pumpAndSettle();
    await tester.tap(find.text('Jo\'natilgan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.byType(WerkaArchiveSentHubScreen), findsOneWidget);
  });

  _archiveTest('period screen opens daily calendar without exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const WerkaArchivePeriodScreen(kind: WerkaArchiveKind.sent)),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Kunlik'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(tester.takeException(), isNull);
    expect(find.byType(WerkaArchiveDailyCalendarScreen), findsOneWidget);
  });

  _archiveTest('period screen opens yearly calendar without exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const WerkaArchivePeriodScreen(kind: WerkaArchiveKind.sent)),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Yillik'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(tester.takeException(), isNull);
    expect(find.byType(WerkaArchiveYearlyCalendarScreen), findsOneWidget);
  });

  _archiveTest('daily calendar opens list when active day is tapped', (
    tester,
  ) async {
    final today = DateTime.now();
    final activeDay = today.day == 3 ? 4 : 3;
    Future<WerkaArchiveResponse> archiveLoader({
      required WerkaArchiveKind kind,
      required WerkaArchivePeriod period,
      DateTime? from,
      DateTime? to,
    }) async {
      return WerkaArchiveResponse(
        kind: kind,
        period: period,
        from: from,
        to: to,
        summary: const WerkaArchiveSummary(
          recordCount: 1,
          totalsByUOM: [ArchiveTotalByUOM(uom: 'Kg', qty: 3)],
        ),
        items: [
          DispatchRecord(
            id: 'MAT-DN-TEST',
            supplierRef: 'CUS-001',
            supplierName: 'Customer One',
            itemCode: 'ITEM-001',
            itemName: 'Rice',
            uom: 'Kg',
            sentQty: 3,
            acceptedQty: 0,
            amount: 0,
            currency: '',
            note: '',
            eventType: '',
            highlight: '',
            status: DispatchStatus.pending,
            createdLabel: DateTime(today.year, today.month, activeDay, 10)
                .toIso8601String(),
          ),
        ],
      );
    }

    await tester.pumpWidget(
      _wrap(
        WerkaArchiveDailyCalendarScreen(
          kind: WerkaArchiveKind.sent,
          archiveLoader: archiveLoader,
        ),
      ),
    );

    await tester.pumpAndSettle();
    final day = find.descendant(
      of: find.byType(CalendarDatePicker),
      matching: find.text('$activeDay'),
    );
    await tester.ensureVisible(day);
    await tester.tap(day);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.byType(WerkaArchiveListScreen), findsOneWidget);
  });

  _archiveTest('monthly calendar opens list when month is tapped', (
    tester,
  ) async {
    Future<WerkaArchiveResponse> archiveLoader({
      required WerkaArchiveKind kind,
      required WerkaArchivePeriod period,
      DateTime? from,
      DateTime? to,
    }) async {
      return WerkaArchiveResponse(
        kind: kind,
        period: period,
        from: from,
        to: to,
        summary: const WerkaArchiveSummary(
          recordCount: 1,
          totalsByUOM: [ArchiveTotalByUOM(uom: 'Kg', qty: 3)],
        ),
        items: [
          DispatchRecord(
            id: 'MAT-DN-TEST',
            supplierRef: 'CUS-001',
            supplierName: 'Customer One',
            itemCode: 'ITEM-001',
            itemName: 'Rice',
            uom: 'Kg',
            sentQty: 3,
            acceptedQty: 0,
            amount: 0,
            currency: '',
            note: '',
            eventType: '',
            highlight: '',
            status: DispatchStatus.pending,
            createdLabel:
                DateTime(DateTime.now().year, 4, 3, 10).toIso8601String(),
          ),
        ],
      );
    }

    await tester.pumpWidget(
      _wrap(
        WerkaArchiveMonthlyCalendarScreen(
          kind: WerkaArchiveKind.sent,
          archiveLoader: archiveLoader,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('archive_month_4')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.byType(WerkaArchiveListScreen), findsOneWidget);
  });

  _archiveTest('yearly calendar opens list when year is tapped',
      (tester) async {
    final year = DateTime.now().year;
    Future<WerkaArchiveResponse> archiveLoader({
      required WerkaArchiveKind kind,
      required WerkaArchivePeriod period,
      DateTime? from,
      DateTime? to,
    }) async {
      return WerkaArchiveResponse(
        kind: kind,
        period: period,
        from: from,
        to: to,
        summary: const WerkaArchiveSummary(
          recordCount: 1,
          totalsByUOM: [ArchiveTotalByUOM(uom: 'Kg', qty: 3)],
        ),
        items: [
          DispatchRecord(
            id: 'MAT-DN-TEST',
            supplierRef: 'CUS-001',
            supplierName: 'Customer One',
            itemCode: 'ITEM-001',
            itemName: 'Rice',
            uom: 'Kg',
            sentQty: 3,
            acceptedQty: 0,
            amount: 0,
            currency: '',
            note: '',
            eventType: '',
            highlight: '',
            status: DispatchStatus.pending,
            createdLabel: DateTime(year, 4, 3, 10).toIso8601String(),
          ),
        ],
      );
    }

    await tester.pumpWidget(
      _wrap(
        WerkaArchiveYearlyCalendarScreen(
          kind: WerkaArchiveKind.sent,
          archiveLoader: archiveLoader,
        ),
      ),
    );

    await tester.pumpAndSettle();
    final yearTile = find.byKey(ValueKey('archive_year_$year'));
    await tester.ensureVisible(yearTile);
    await tester.tap(yearTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.byType(WerkaArchiveListScreen), findsOneWidget);
  });
}

void _archiveTest(String description, WidgetTesterCallback callback) {
  testWidgets(description, (tester) {
    return http.runWithClient(
      () => callback(tester),
      () => MockClient((request) async {
        expect(request.url.path, '/v1/mobile/werka/archive');
        return http.Response('{"items":[]}', 200);
      }),
    );
  });
}
