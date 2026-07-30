import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/update/app_update_installer.dart';
import 'package:accord_mobile_v2/src/core/update/app_update_models.dart';
import 'package:accord_mobile_v2/src/core/update/app_update_runtime.dart';
import 'package:accord_mobile_v2/src/core/update/app_update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('manual check shows latest-version result above an open sheet', (
    tester,
  ) async {
    final coordinator = AppUpdateCoordinator(
      service: _FakeUpdateService(
        result: _result(currentVersionCode: 6, releaseVersionCode: 6),
      ),
    );
    await _pumpHarness(tester, coordinator);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings sheet'), findsOneWidget);

    await tester.tap(find.text('Check update'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Sizda eng so‘nggi versiya o‘rnatilgan.'), findsOneWidget);
    expect(find.text('Settings sheet'), findsOneWidget);
  });

  testWidgets('installer launch keeps a visible completion state', (
    tester,
  ) async {
    final service = _FakeUpdateService(
      result: _result(currentVersionCode: 5, releaseVersionCode: 6),
    );
    final coordinator = AppUpdateCoordinator(service: service);
    await _pumpHarness(tester, coordinator);

    await tester.tap(find.text('Check directly'));
    await tester.pumpAndSettle();
    expect(find.text('Yangi versiya mavjud'), findsOneWidget);

    await tester.tap(find.text('Yangilash'));
    await tester.pumpAndSettle();

    expect(service.installCalls, 1);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text(
        'APK tayyor. Android o‘rnatuvchisi ochildi — '
        'o‘rnatishni tizim oynasida tasdiqlang.',
      ),
      findsOneWidget,
    );
    expect(find.text('O‘rnatuvchini qayta ochish'), findsOneWidget);
  });
}

Future<void> _pumpHarness(
  WidgetTester tester,
  AppUpdateCoordinator coordinator,
) async {
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
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              FilledButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (sheetContext) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Settings sheet'),
                        FilledButton(
                          onPressed: () => coordinator.checkAndPrompt(
                            context,
                            manual: true,
                          ),
                          child: const Text('Check update'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open settings'),
              ),
              FilledButton(
                onPressed: () => coordinator.checkAndPrompt(
                  context,
                  manual: true,
                ),
                child: const Text('Check directly'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AppUpdateCheckResult _result({
  required int currentVersionCode,
  required int releaseVersionCode,
}) {
  return AppUpdateCheckResult(
    current: AppInstallationInfo(
      packageName: 'com.example.accord_mobile_v2',
      versionCode: currentVersionCode,
      versionName: '0.2.0',
      signerSha256: 'signer',
    ),
    manifest: AppUpdateManifest(
      versionCode: releaseVersionCode,
      versionName: '0.2.1',
      minimumSupportedVersionCode: 0,
      mandatory: false,
      apkUri: Uri.parse('https://erp.example/accord.apk'),
      sha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      sizeBytes: 1024,
      releaseNotes: 'Updater UX',
      publishedAt: '2026-07-30T00:00:00Z',
    ),
  );
}

class _FakeUpdateService extends AppUpdateService {
  _FakeUpdateService({required this.result});

  final AppUpdateCheckResult result;
  int installCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<AppUpdateCheckResult> check() async => result;

  @override
  Future<AppInstallLaunchResult> downloadAndInstall(
    AppUpdateCheckResult update, {
    AppUpdateProgress? onProgress,
    AppUpdateCancellation? cancellation,
  }) async {
    installCalls += 1;
    onProgress?.call(update.manifest!.sizeBytes, update.manifest!.sizeBytes);
    return AppInstallLaunchResult.installerLaunched;
  }
}
