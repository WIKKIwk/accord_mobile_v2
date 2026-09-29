import 'dart:convert';
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_push_config_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final account = {
  'type': 'service_account',
  'project_id': 'demo-project',
  'client_email': 'push@demo-project.iam.gserviceaccount.com',
  'private_key': 'private-test-key'
};

class JsonFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    expect(type, FileType.custom);
    expect(allowedExtensions, ['json']);
    expect(withData, isTrue);
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(account)));
    return FilePickerResult([
      PlatformFile(
          name: 'service-account.json', size: bytes.length, bytes: bytes)
    ]);
  }
}

Map<String, Object?> status(bool ready) => {
      'configured': ready,
      'project_id': ready ? 'demo-project' : '',
      'client_email': ready ? account['client_email'] : '',
      'last_verified_at': ready ? 1 : null
    };
SessionProfile profile(UserRole role) => SessionProfile(
    role: role,
    ref: 'admin-test',
    displayName: 'Admin',
    legalName: '',
    phone: '',
    avatarUrl: '',
    capabilities: const ['admin.settings.read', 'admin.settings.manage']);
Widget app() => MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      home: AdminPushConfigScreen(
          deviceTokenProvider: () async => 'this-phone-token'),
    );

Future<void> tap(WidgetTester tester, String key) async {
  final button = find.byKey(ValueKey(key));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'admin-token';
    AppSession.instance.profile = profile(UserRole.admin);
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets(
      'admin saves JSON, sees only metadata, checks and tests current device',
      (tester) async {
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Firebase hali sozlanmagan'), findsOneWidget);
      expect(
          tester
              .widget<OutlinedButton>(
                  find.byKey(const ValueKey('push-config-test')))
              .onPressed,
          isNull);
      await tester.enterText(
          find.byKey(const ValueKey('push-config-json')), jsonEncode(account));
      await tap(tester, 'push-config-save');
      expect(find.text('Firebase kaliti saqlangan'), findsOneWidget);
      expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('push-config-json')))
              .controller!
              .text,
          isEmpty);
      expect(find.textContaining('Serverga darhol qo‘llandi'), findsOneWidget);
      await tap(tester, 'push-config-check');
      await tap(tester, 'push-config-test');
      expect(
          find.textContaining('FCM tomonidan qabul qilindi'), findsOneWidget);
      final saved = requests.singleWhere((r) => r.method == 'PUT');
      expect(jsonDecode(saved.body)['service_account'], account);
      final test = requests.singleWhere((r) => r.url.path.endsWith('/test'));
      expect(jsonDecode(test.body), {'token': 'this-phone-token'});
      expect(
          requests
              .every((r) => r.headers['authorization'] == 'Bearer admin-token'),
          isTrue);
    },
        () => MockClient((r) async {
              requests.add(r);
              if (r.url.path.endsWith('/test')) {
                return http.Response('{"ok":true,"accepted_by_fcm":true}', 200);
              }
              return http.Response(jsonEncode(status(r.method != 'GET')), 200);
            }));
  });

  testWidgets('a device token cannot be saved as service-account JSON',
      (tester) async {
    var mutations = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('push-config-json')), 'fcm-device-token');
      await tap(tester, 'push-config-save');
      expect(
          find.textContaining('To‘g‘ri service-account JSON'), findsOneWidget);
      expect(mutations, 0);
    },
        () => MockClient((r) async {
              if (r.method != 'GET') mutations++;
              return http.Response(jsonEncode(status(false)), 200);
            }));
  });

  testWidgets('admin uploads a JSON file and saves its credentials',
      (tester) async {
    FilePicker.platform = JsonFilePicker();
    Map<String, dynamic>? uploaded;
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('JSON faylni tanlash'));
      await tester.pumpAndSettle();
      expect(find.text('service-account.json'), findsOneWidget);
      expect(uploaded, isNull);
      await tap(tester, 'push-config-save');
      expect(uploaded?['service_account'], account);
      expect(find.text('service-account.json'), findsNothing);
      expect(find.textContaining('Serverga darhol qo‘llandi'), findsOneWidget);
    },
        () => MockClient((request) async {
              if (request.method == 'PUT') {
                uploaded = jsonDecode(request.body) as Map<String, dynamic>;
              }
              return http.Response(
                  jsonEncode(status(request.method == 'PUT')), 200);
            }));
  });

  testWidgets('a failed save keeps the previous status and lets admin retry',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('push-config-json')), jsonEncode(account));
      await tap(tester, 'push-config-save');
      expect(find.byKey(const ValueKey('push-config-error')), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, 900));
      await tester.pumpAndSettle();
      expect(find.text('Firebase kaliti saqlangan'), findsOneWidget);
      expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('push-config-json')))
              .controller!
              .text,
          contains('private-test-key'));
      expect(find.textContaining('Serverga darhol qo‘llandi'), findsNothing);
    },
        () => MockClient((r) async => r.method == 'GET'
            ? http.Response(jsonEncode(status(true)), 200)
            : http.Response('{"error":"push_config_google_rejected"}', 502)));
  });

  testWidgets('non-admin cannot open configuration or fetch secrets',
      (tester) async {
    AppSession.instance.profile = profile(UserRole.aparatchi);
    expect(AppRouter.canOpenRoute(AppRoutes.adminPushConfig), isFalse);
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Bu sahifa faqat admin uchun'), findsOneWidget);
      expect(find.byKey(const ValueKey('push-config-json')), findsNothing);
    },
        () => MockClient(
            (_) async => throw StateError('must not request configuration')));
  });

  test('test mode cannot upload credentials or send a real test', () async {
    await TestModeController.instance.setEnabled(true);
    await http.runWithClient(() async {
      for (final action in <Future<dynamic> Function()>[
        () => MobileApi.instance.adminPushConfig(),
        () => MobileApi.instance.saveAdminPushConfig(account),
        () => MobileApi.instance.checkAdminPushConfig(),
        () => MobileApi.instance.testAdminPushConfig('token'),
      ]) {
        await expectLater(
            action(),
            throwsA(isA<MobileApiException>()
                .having((e) => e.code, 'code', 'push_config_test_mode')));
      }
    }, () => MockClient((_) async => throw StateError('must not send')));
  });
}
