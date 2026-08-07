import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_update_models.dart';

enum AppInstallLaunchResult { installerLaunched, permissionRequired }

enum AppUpdateDownloadStatus {
  missing,
  pending,
  running,
  paused,
  successful,
  failed,
}

class AppUpdateDownloadSnapshot {
  const AppUpdateDownloadSnapshot({
    required this.status,
    required this.receivedBytes,
    required this.totalBytes,
    required this.path,
    required this.reason,
    required this.retryable,
  });

  final AppUpdateDownloadStatus status;
  final int receivedBytes;
  final int totalBytes;
  final String path;
  final int reason;
  final bool retryable;

  factory AppUpdateDownloadSnapshot.fromMap(Map<Object?, Object?> map) {
    final status = switch (map['status']?.toString()) {
      'missing' => AppUpdateDownloadStatus.missing,
      'pending' => AppUpdateDownloadStatus.pending,
      'running' => AppUpdateDownloadStatus.running,
      'paused' => AppUpdateDownloadStatus.paused,
      'successful' => AppUpdateDownloadStatus.successful,
      'failed' => AppUpdateDownloadStatus.failed,
      _ => throw const AppUpdateException(
          code: 'invalid_download_state',
          message: 'Yangilanish yuklash holati noto‘g‘ri',
        ),
    };
    final receivedBytes = (map['receivedBytes'] as num?)?.toInt() ?? 0;
    final totalBytes = (map['totalBytes'] as num?)?.toInt() ?? 0;
    if (receivedBytes < 0 || totalBytes < 0) {
      throw const AppUpdateException(
        code: 'invalid_download_state',
        message: 'Yangilanish yuklash holati noto‘g‘ri',
      );
    }
    return AppUpdateDownloadSnapshot(
      status: status,
      receivedBytes: receivedBytes,
      totalBytes: totalBytes,
      path: map['path']?.toString().trim() ?? '',
      reason: (map['reason'] as num?)?.toInt() ?? 0,
      retryable: map['retryable'] == true,
    );
  }
}

abstract class AppUpdatePlatform {
  bool get isSupported;

  Future<AppInstallationInfo> currentAppInfo();

  Future<AppUpdateDownloadSnapshot> startOrAttachDownload({
    required AppUpdateManifest manifest,
  });

  Future<AppUpdateDownloadSnapshot> queryDownload({
    required AppUpdateManifest manifest,
  });

  Future<void> cancelDownload({required AppUpdateManifest manifest});

  Future<AppInstallLaunchResult> installApk({
    required String path,
    required String expectedPackageName,
    required int expectedVersionCode,
  });
}

class NativeAppUpdatePlatform implements AppUpdatePlatform {
  const NativeAppUpdatePlatform();

  static const MethodChannel _channel = MethodChannel('accord/app_update');

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<AppInstallationInfo> currentAppInfo() async {
    if (!isSupported) {
      throw const AppUpdateException(
        code: 'unsupported_platform',
        message: 'Bu platformada APK update ishlamaydi',
      );
    }
    final Map<Object?, Object?>? result;
    try {
      result = await _channel.invokeMapMethod<Object?, Object?>(
        'getCurrentAppInfo',
      );
    } on PlatformException catch (error) {
      throw AppUpdateException(
        code: error.code,
        message: error.message ?? 'Ilova versiyasi aniqlanmadi',
      );
    }
    if (result == null) {
      throw const AppUpdateException(
        code: 'app_info_failed',
        message: 'Ilova versiyasi aniqlanmadi',
      );
    }
    final info = AppInstallationInfo.fromMap(result);
    if (info.packageName.isEmpty || info.versionCode <= 0) {
      throw const AppUpdateException(
        code: 'app_info_failed',
        message: 'Ilova versiyasi aniqlanmadi',
      );
    }
    return info;
  }

  @override
  Future<AppUpdateDownloadSnapshot> startOrAttachDownload({
    required AppUpdateManifest manifest,
  }) {
    return _downloadSnapshot('startOrAttachUpdateDownload', manifest);
  }

  @override
  Future<AppUpdateDownloadSnapshot> queryDownload({
    required AppUpdateManifest manifest,
  }) {
    return _downloadSnapshot('queryUpdateDownload', manifest);
  }

  @override
  Future<void> cancelDownload({required AppUpdateManifest manifest}) async {
    try {
      await _channel.invokeMethod<void>(
        'cancelUpdateDownload',
        _downloadArguments(manifest),
      );
    } on PlatformException catch (error) {
      throw AppUpdateException(
        code: error.code,
        message: error.message ?? 'Yangilanish yuklashi bekor qilinmadi',
      );
    }
  }

  @override
  Future<AppInstallLaunchResult> installApk({
    required String path,
    required String expectedPackageName,
    required int expectedVersionCode,
  }) async {
    final Map<Object?, Object?>? result;
    try {
      result = await _channel.invokeMapMethod<Object?, Object?>(
        'installApk',
        {
          'path': path,
          'expectedPackageName': expectedPackageName,
          'expectedVersionCode': expectedVersionCode,
        },
      );
    } on PlatformException catch (error) {
      throw AppUpdateException(
        code: error.code,
        message: error.message ?? 'APK o‘rnatilmadi',
      );
    }
    return switch (result?['status']?.toString()) {
      'installer_launched' => AppInstallLaunchResult.installerLaunched,
      'permission_required' => AppInstallLaunchResult.permissionRequired,
      _ => throw const AppUpdateException(
          code: 'installer_failed',
          message: 'Android o‘rnatuvchisi ochilmadi',
        ),
    };
  }

  Future<AppUpdateDownloadSnapshot> _downloadSnapshot(
    String method,
    AppUpdateManifest manifest,
  ) async {
    final Map<Object?, Object?>? result;
    try {
      result = await _channel.invokeMapMethod<Object?, Object?>(
        method,
        _downloadArguments(manifest),
      );
    } on PlatformException catch (error) {
      throw AppUpdateException(
        code: error.code,
        message: error.message ?? 'Yangilanish yuklash xizmati ishlamadi',
      );
    }
    if (result == null) {
      throw const AppUpdateException(
        code: 'download_state_failed',
        message: 'Yangilanish yuklash holati olinmadi',
      );
    }
    return AppUpdateDownloadSnapshot.fromMap(result);
  }

  Map<String, Object> _downloadArguments(AppUpdateManifest manifest) {
    return <String, Object>{
      'url': manifest.apkUri.toString(),
      'versionCode': manifest.versionCode,
      'versionName': manifest.versionName,
      'sha256': manifest.sha256,
      'sizeBytes': manifest.sizeBytes,
    };
  }
}
