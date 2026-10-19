import 'dart:async';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/native_back_button_bridge.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/update/app_update_installer.dart';
import 'package:accord_mobile_v2/src/core/update/app_update_models.dart';
import 'package:accord_mobile_v2/src/core/update/app_update_runtime.dart';
import 'package:accord_mobile_v2/src/core/update/app_update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final sessionChange in [true, false]) {
    testWidgets(
        'runtime checks startup and ${sessionChange ? 'login' : 'app resume'} for mandatory updates',
        (tester) async {
      final service = _FakeUpdateService(
        result: _result(currentVersionCode: 5, releaseVersionCode: 6),
      );
      await _pumpHarness(tester, AppUpdateCoordinator(service: service),
          withRuntime: true);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(service.checkCalls, 1);
      await tester.tap(find.text('Keyinroq'));
      await tester.pumpAndSettle();
      service.result = _result(
          currentVersionCode: 5, releaseVersionCode: 6, mandatory: true);
      if (sessionChange) {
        AppSession.instance.revision.value++;
      } else {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(service.checkCalls, 2);
      expect(find.text('Yangilanish talab qilinadi'), findsOneWidget);
      await _expectCannotDismiss(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('mandatory update cannot close before or after installer launch',
      (tester) async {
    final service = _FakeUpdateService(
      result: _result(
          currentVersionCode: 5, releaseVersionCode: 6, mandatory: true),
    );
    await _pumpHarness(tester, AppUpdateCoordinator(service: service));
    await tester.tap(find.text('Check automatically'));
    await tester.pumpAndSettle();
    expect(find.text('Yangilanish talab qilinadi'), findsOneWidget);
    await _expectCannotDismiss(tester);
    await tester.tap(find.text('Yangilash'));
    await tester.pumpAndSettle();
    expect(find.text('O‘rnatuvchini qayta ochish'), findsOneWidget);
    await _expectCannotDismiss(tester);
    await tester.tap(find.text('O‘rnatuvchini qayta ochish'));
    await tester.pumpAndSettle();
    expect(service.installCalls, 2);
    await _expectCannotDismiss(tester);
  });

  testWidgets('canceling a mandatory download leaves the update gate locked',
      (tester) async {
    final service = _FakeUpdateService(
      result: _result(
          currentVersionCode: 5, releaseVersionCode: 6, mandatory: true),
      pendingInstall: Completer<AppInstallLaunchResult>(),
    );
    await _pumpHarness(tester, AppUpdateCoordinator(service: service));
    await tester.tap(find.text('Check directly'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yangilash'));
    await tester.pumpAndSettle();
    expect(find.text('Bekor qilish'), findsOneWidget);
    await _expectCannotDismiss(tester);
    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    expect(find.text('Yangilash'), findsOneWidget);
    await _expectCannotDismiss(tester);
  });

  for (final failure in [false, true]) {
    testWidgets(
        'mandatory gate stays locked after ${failure ? 'download failure' : 'permission request'}',
        (tester) async {
      final service = _FakeUpdateService(
        result: _result(
            currentVersionCode: 5, releaseVersionCode: 6, mandatory: true),
        installFailuresRemaining: failure ? 1 : 0,
        installResult: AppInstallLaunchResult.permissionRequired,
      );
      await _pumpHarness(tester, AppUpdateCoordinator(service: service));
      await tester.tap(find.text('Check directly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yangilash'));
      await tester.pumpAndSettle();
      expect(find.text('Yangilash'), findsOneWidget);
      await _expectCannotDismiss(tester);
    });
  }

  testWidgets('required update is shown even if this release was postponed',
      (tester) async {
    final service = _FakeUpdateService(
      result: _result(currentVersionCode: 5, releaseVersionCode: 6),
    );
    await _pumpHarness(tester, AppUpdateCoordinator(service: service));
    await tester.tap(find.text('Check automatically'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keyinroq'));
    await tester.pumpAndSettle();
    service.result =
        _result(currentVersionCode: 5, releaseVersionCode: 6, mandatory: true);
    await tester.tap(find.text('Check automatically'));
    await tester.pumpAndSettle();
    expect(find.text('Yangilanish talab qilinadi'), findsOneWidget);
    await _expectCannotDismiss(tester);
  });

  testWidgets('open update gate rereads the admin switch on app resume',
      (tester) async {
    final service = _FakeUpdateService(
      result: _result(currentVersionCode: 5, releaseVersionCode: 6),
    );
    await _pumpHarness(tester, AppUpdateCoordinator(service: service));
    await tester.tap(find.text('Check automatically'));
    await tester.pumpAndSettle();
    service.result =
        _result(currentVersionCode: 5, releaseVersionCode: 6, mandatory: true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await _expectCannotDismiss(tester);
    service.failuresRemaining = 1;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await _expectCannotDismiss(tester);
    service.result = _result(currentVersionCode: 5, releaseVersionCode: 6);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keyinroq'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('mandatory flag never blocks users already on the latest version',
      (tester) async {
    final service = _FakeUpdateService(
      result: _result(
          currentVersionCode: 6, releaseVersionCode: 6, mandatory: true),
    );
    await _pumpHarness(tester, AppUpdateCoordinator(service: service));
    await tester.tap(find.text('Check automatically'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('Check directly'));
    await tester.pumpAndSettle();
    expect(find.text('Siz so‘nggi versiyadasiz'), findsOneWidget);
    await tester.tap(find.text('Yopish'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('APK policy does not lock devices unable to install APKs',
      (tester) async {
    final service = _FakeUpdateService(
      result: _result(
          currentVersionCode: 5, releaseVersionCode: 6, mandatory: true),
      supported: false,
    );
    await _pumpHarness(tester, AppUpdateCoordinator(service: service));
    await tester.tap(find.text('Check automatically'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('Check directly'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('APK faylini o‘rnatib bo‘lmaydi'), findsOneWidget);
    await tester.tap(find.text('Yopish'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
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
    expect(find.text('0.2.0 (5)'), findsOneWidget);
    expect(find.text('0.2.1 (6)'), findsOneWidget);
    expect(service.installCalls, 0);

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

  testWidgets('active background download resumes when dialog is recreated', (
    tester,
  ) async {
    final service = _FakeUpdateService(
      result: _result(currentVersionCode: 5, releaseVersionCode: 6),
      hasActiveDownload: true,
    );
    final coordinator = AppUpdateCoordinator(service: service);
    await _pumpHarness(tester, coordinator);

    await tester.tap(find.text('Check directly'));
    await tester.pumpAndSettle();

    expect(service.installCalls, 1);
    expect(
      find.text(
        'APK tayyor. Android o‘rnatuvchisi ochildi — '
        'o‘rnatishni tizim oynasida tasdiqlang.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('latest version is shown on devices that cannot install APKs',
      (tester) async {
    final service = _FakeUpdateService(
      result: _result(currentVersionCode: 6, releaseVersionCode: 6),
      supported: false,
    );
    await _pumpHarness(tester, AppUpdateCoordinator(service: service));
    await tester.tap(find.text('Check directly'));
    await tester.pumpAndSettle();
    expect(find.text('Siz so‘nggi versiyadasiz'), findsOneWidget);
    expect(find.text('Sizda eng so‘nggi versiya o‘rnatilgan.'), findsOneWidget);
    expect(find.text('0.2.1 (6)'), findsNWidgets(2));
    expect(find.textContaining('APK faylini o‘rnatib bo‘lmaydi'), findsNothing);
    expect(find.text('Yangilash'), findsNothing);
    expect(service.activeDownloadCalls, 0);
    expect(service.installCalls, 0);
  });

  testWidgets('newer APK shows versions and a clear device restriction',
      (tester) async {
    final service = _FakeUpdateService(
      result: _result(currentVersionCode: 5, releaseVersionCode: 6),
      supported: false,
    );
    await _pumpHarness(tester, AppUpdateCoordinator(service: service));
    await tester.tap(find.text('Check directly'));
    await tester.pumpAndSettle();
    expect(find.text('Yangi versiya mavjud'), findsOneWidget);
    expect(find.text('0.2.0 (5)'), findsOneWidget);
    expect(find.text('0.2.1 (6)'), findsOneWidget);
    expect(find.textContaining('bu qurilmada APK faylini o‘rnatib bo‘lmaydi'),
        findsOneWidget);
    expect(find.text('Yangilash'), findsNothing);
    expect(service.activeDownloadCalls, 0);
    expect(service.installCalls, 0);
    await tester.tap(find.text('Yopish'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('check displays installed version while waiting for the server',
      (tester) async {
    final pending = Completer<AppUpdateCheckResult>();
    final service = _FakeUpdateService(
      result: _result(currentVersionCode: 5, releaseVersionCode: 6),
      pendingCheck: pending,
    );
    await _pumpHarness(tester, AppUpdateCoordinator(service: service));
    await tester.tap(find.text('Check directly'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('0.2.0 (5)'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Yangilash'), findsNothing);
    pending.complete(service.result);
    await tester.pumpAndSettle();
    expect(find.text('Yangi versiya mavjud'), findsOneWidget);
    expect(find.text('0.2.1 (6)'), findsOneWidget);
  });

  testWidgets(
      'failed check retains version and retries without claiming latest',
      (tester) async {
    final service = _FakeUpdateService(
      result: _result(currentVersionCode: 5, releaseVersionCode: 6),
      failuresRemaining: 1,
    );
    await _pumpHarness(tester, AppUpdateCoordinator(service: service));
    await tester.tap(find.text('Check directly'));
    await tester.pumpAndSettle();
    expect(find.text('0.2.0 (5)'), findsOneWidget);
    expect(find.text('Yangilanish serveriga ulanib bo‘lmadi'), findsOneWidget);
    expect(find.text('Siz so‘nggi versiyadasiz'), findsNothing);
    await tester.tap(find.text('Qayta urinish'));
    await tester.pumpAndSettle();
    expect(service.checkCalls, 2);
    expect(find.text('Yangi versiya mavjud'), findsOneWidget);
  });

  testWidgets(
      'no published update retains current version on unsupported devices',
      (tester) async {
    final current =
        _result(currentVersionCode: 6, releaseVersionCode: 6).current;
    final service = _FakeUpdateService(
      result: AppUpdateCheckResult(current: current, manifest: null),
      supported: false,
    );
    await _pumpHarness(tester, AppUpdateCoordinator(service: service));
    await tester.tap(find.text('Check directly'));
    await tester.pumpAndSettle();
    expect(find.text('0.2.1 (6)'), findsOneWidget);
    expect(find.text('Siz so‘nggi versiyadasiz'), findsOneWidget);
    expect(find.text('Yangilash'), findsNothing);
  });

  for (final width in [375.0, 800.0]) {
    testWidgets('update dialog uses standard width on $width px screen',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpHarness(
          tester,
          AppUpdateCoordinator(
              service: _FakeUpdateService(
            result: _result(currentVersionCode: 6, releaseVersionCode: 6),
          )));
      await tester.tap(find.text('Check directly'));
      await tester.pumpAndSettle();
      final dialog = find
          .descendant(
              of: find.byType(AlertDialog), matching: find.byType(Material))
          .first;
      expect(tester.getSize(dialog).width, width == 375 ? 327 : 420);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpHarness(
  WidgetTester tester,
  AppUpdateCoordinator coordinator, {
  bool withRuntime = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey:
          withRuntime ? NativeBackButtonBridge.instance.navigatorKey : null,
      builder: withRuntime
          ? (context, child) =>
              AppUpdateRuntime(coordinator: coordinator, child: child!)
          : null,
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
                onPressed: () =>
                    coordinator.checkAndPrompt(context, manual: false),
                child: const Text('Check automatically'),
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
  bool mandatory = false,
}) {
  return AppUpdateCheckResult(
    current: AppInstallationInfo(
      packageName: 'com.example.accord_mobile_v2',
      versionCode: currentVersionCode,
      versionName: currentVersionCode == releaseVersionCode ? '0.2.1' : '0.2.0',
      signerSha256: 'signer',
    ),
    manifest: AppUpdateManifest(
      versionCode: releaseVersionCode,
      versionName: '0.2.1',
      minimumSupportedVersionCode: 0,
      mandatory: mandatory,
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
  _FakeUpdateService({
    required this.result,
    this.hasActiveDownload = false,
    this.supported = true,
    this.pendingCheck,
    this.failuresRemaining = 0,
    this.pendingInstall,
    this.installFailuresRemaining = 0,
    this.installResult = AppInstallLaunchResult.installerLaunched,
  });

  AppUpdateCheckResult result;
  final Completer<AppInstallLaunchResult>? pendingInstall;
  int installFailuresRemaining;
  final AppInstallLaunchResult installResult;
  final bool hasActiveDownload;
  final bool supported;
  final Completer<AppUpdateCheckResult>? pendingCheck;
  int failuresRemaining;
  int installCalls = 0;
  int checkCalls = 0;
  int activeDownloadCalls = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<AppInstallationInfo> currentAppInfo() async => result.current;

  @override
  Future<AppUpdateCheckResult> check() async {
    checkCalls++;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw const AppUpdateException(
          code: 'update_check_network',
          message: 'Yangilanish serveriga ulanib bo‘lmadi');
    }
    if (pendingCheck != null) return pendingCheck!.future;
    return result;
  }

  @override
  Future<AppUpdateDownloadSnapshot?> activeDownload(
    AppUpdateCheckResult update,
  ) async {
    activeDownloadCalls++;
    if (!hasActiveDownload) {
      return null;
    }
    return AppUpdateDownloadSnapshot(
      status: AppUpdateDownloadStatus.running,
      receivedBytes: update.manifest!.sizeBytes ~/ 2,
      totalBytes: update.manifest!.sizeBytes,
      path: '',
      reason: 0,
      retryable: false,
    );
  }

  @override
  Future<AppInstallLaunchResult> downloadAndInstall(
    AppUpdateCheckResult update, {
    AppUpdateProgress? onProgress,
    AppUpdateCancellation? cancellation,
  }) async {
    installCalls += 1;
    if (installFailuresRemaining > 0) {
      installFailuresRemaining--;
      throw const AppUpdateException(
          code: 'download_failed', message: 'Yuklanmadi');
    }
    onProgress?.call(update.manifest!.sizeBytes, update.manifest!.sizeBytes);
    if (pendingInstall != null) {
      return Future.any([
        pendingInstall!.future,
        cancellation!.whenCancelled.then<AppInstallLaunchResult>((_) =>
            throw const AppUpdateException(
                code: 'cancelled', message: 'Bekor qilindi')),
      ]);
    }
    return installResult;
  }
}

Future<void> _expectCannotDismiss(WidgetTester tester) async {
  expect(find.text('Keyinroq'), findsNothing);
  expect(find.text('Yopish'), findsNothing);
  await tester.tapAt(const Offset(4, 4));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
}
