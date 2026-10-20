import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_expandable_filter_chip.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_summary_card.dart';
import 'package:accord_mobile_v2/src/features/chat/presentation/chat_directory_screen.dart';
import 'package:accord_mobile_v2/src/features/chat/state/chat_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

Future<void> _withDirectory(
  WidgetTester tester,
  FutureOr<http.Response> Function(http.Request) handler,
  Future<void> Function() body,
) async {
  await http.runWithClient(
    () async {
      try {
        await tester.pumpWidget(
          const MaterialApp(
            locale: Locale('uz'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChatDirectoryScreen(),
          ),
        );
        await tester.pumpAndSettle();
        ChatStore.instance.pauseRealtime();
        await body();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        ChatStore.instance.clearMemory();
        await tester.pumpAndSettle();
      }
    },
    () => MockClient((request) async {
      if (request.url.path.endsWith('/directory')) return handler(request);
      if (request.url.path.endsWith('/socket-ticket')) {
        return http.Response('{"error":"offline"}', 503);
      }
      return http.Response('{"items":[],"events":[],"has_more":false}', 200);
    }),
  );
}

http.Response _directoryResponse(http.Request request) {
  final roleFilter = request.url.queryParameters['role'];
  final query = request.url.queryParameters['q'] ?? '';
  return http.Response(
    jsonEncode({
      'items': [
        for (final role in UserRole.values)
          if ((roleFilter == null || roleFilter == userRoleToJson(role)) &&
              'Contact ${userRoleToJson(role)}'.contains(query))
            {
              'role': userRoleToJson(role),
              'ref': 'contact-${role.name}',
              'display_name': 'Contact ${userRoleToJson(role)}',
            },
      ],
      'has_more': false,
    }),
    200,
  );
}

Future<void> _selectRole(WidgetTester tester, String role) async {
  await tester.tap(find.byKey(const ValueKey('chat-directory-role-filter')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('chat-directory-role-option-$role')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => databaseFactory = databaseFactorySqflitePlugin);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance
      ..token = 'directory-token'
      ..profile = const SessionProfile(
        role: UserRole.admin,
        ref: 'directory-viewer',
        displayName: 'Viewer',
        legalName: 'Viewer',
        phone: '',
        avatarUrl: '',
      );
    ChatStore.instance.clearMemory();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.tekartik.sqflite'),
      (call) async => switch (call.method) {
        'getDatabasesPath' => '/chat-directory-test',
        'openDatabase' => {'id': 1, 'recovered': true},
        'query' || 'batch' => <Object?>[],
        'insert' || 'update' => 1,
        _ => null,
      },
    );
  });

  tearDown(() {
    ChatStore.instance.clearMemory();
    AppSession.instance
      ..token = null
      ..profile = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.tekartik.sqflite'), null);
  });

  testWidgets('shared directory filter supports every role and clearing it',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <Uri>[];
    await _withDirectory(tester, (request) {
      requests.add(request.url);
      return _directoryResponse(request);
    }, () async {
      expect(find.byType(AdminExpandableFilterChip<UserRole?>), findsOneWidget);
      expect(requests.last.queryParameters, isNot(contains('role')));

      for (final role in UserRole.values) {
        final code = userRoleToJson(role);
        await _selectRole(tester, code);
        expect(requests.last.queryParameters['role'], code);
        expect(find.byType(AdminSummaryCard), findsOneWidget);
        expect(find.text('Contact $code'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      await _selectRole(tester, 'all');
      expect(requests.last.queryParameters, isNot(contains('role')));
      expect(ChatStore.instance.directory, hasLength(UserRole.values.length));
    });
  });

  testWidgets('search, empty results and retry retain the selected role',
      (tester) async {
    final requests = <Uri>[];
    var fail = false;
    await _withDirectory(tester, (request) {
      requests.add(request.url);
      return fail
          ? http.Response('{"error":"offline"}', 503)
          : _directoryResponse(request);
    }, () async {
      await tester.enterText(find.byType(EditableText), 'missing');
      await _selectRole(tester, 'customer');
      expect(requests.last.queryParameters['q'], 'missing');
      expect(requests.last.queryParameters['role'], 'customer');
      expect(find.text('Foydalanuvchi topilmadi'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-directory-role-filter')),
          findsOneWidget);

      fail = true;
      await _selectRole(tester, 'qolipchi');
      expect(find.text('Qayta qidirish'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Qayta qidirish'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['q'], 'missing');
      expect(requests.last.queryParameters['role'], 'qolipchi');

      await tester.enterText(find.byType(EditableText), 'Contact');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['role'], 'qolipchi');
      expect(find.text('Contact qolipchi'), findsOneWidget);
      await _selectRole(tester, 'all');
      expect(requests.last.queryParameters['q'], 'Contact');
      expect(requests.last.queryParameters, isNot(contains('role')));
    });
  });
}
