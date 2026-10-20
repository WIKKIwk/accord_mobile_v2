import 'dart:async';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const request = AdminCompletionRequestNotification(
  eventId: 'request-1', apparatus: 'apparatus:default:bosma_8', orderId: 'order-1',
  orderNumber: '1', orderTitle: 'Old notification', productCode: '',
  workerRole: 'aparatchi', workerRef: 'w', workerDisplayName: 'Worker',
  description: 'Old notification detail', createdAtUnix: 1,
);
Widget app(AdminNotificationsScreen screen) => MaterialApp(
  locale: const Locale('uz'), localizationsDelegates: const [
    AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
  supportedLocales: AppLocalizations.supportedLocales, home: screen,
);
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'test_mode_enabled': true});
    AppSession.instance.token = 'notifications-test';
  });
  tearDown(() { AppSession.instance.token = null; });
  testWidgets('notification live wins over old HTTP, is quiet and stops in background', (tester) async {
    final http = Completer<List<AdminCompletionRequestNotification>>();
    final events = StreamController<List<AdminCompletionRequestNotification>>.broadcast();
    addTearDown(events.close);
    var catalogs = 0;
    var reads = 0;
    var connects = 0;
    await tester.pumpWidget(app(AdminNotificationsScreen(
      requestsLoader: () { reads++; return http.future; },
      apparatusLoader: () async { catalogs++; return []; },
      liveEventsLoader: () { connects++; return events.stream; },
    )));
    await tester.pump();
    events.add([]);
    await tester.pump();
    http.complete([request]);
    await tester.pumpAndSettle();
    expect(find.textContaining('Old notification'), findsNothing);
    await tester.pump(const Duration(seconds: 30));
    expect(reads, 1);
    expect(catalogs, 1);
    expect(connects, 1);
    for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(const Duration(seconds: 60));
    expect(events.hasListener, isFalse);
    expect(reads, 1);
    for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(connects, 2);
    events.add([]);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(seconds: 60));
    expect(connects, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('notification retries back off and do not refetch apparatus', (tester) async {
    final events = StreamController<List<AdminCompletionRequestNotification>>.broadcast();
    addTearDown(events.close);
    var connects = 0;
    var catalogs = 0;
    var reads = 0;
    await tester.pumpWidget(app(AdminNotificationsScreen(
      requestsLoader: () async { reads++; return []; },
      apparatusLoader: () async { catalogs++; return []; },
      liveEventsLoader: () { connects++; return events.stream; },
    )));
    await tester.pumpAndSettle();
    events.addError(Exception('offline'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    expect(connects, 2);
    expect(reads, 2);
    expect(catalogs, 1);
    events.addError(Exception('offline again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(connects, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 35));
    expect(connects, 2);
    expect(tester.takeException(), isNull);
  });
}
