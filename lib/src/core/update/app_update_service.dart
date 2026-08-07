import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../api/mobile_api.dart';
import 'app_update_installer.dart';
import 'app_update_models.dart';

typedef AppUpdateProgress = void Function(int receivedBytes, int totalBytes);

class AppUpdateCancellation {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
  }
}

class AppUpdateService {
  AppUpdateService({
    http.Client? client,
    AppUpdatePlatform? platform,
    Uri? baseUri,
    Duration downloadPollInterval = const Duration(milliseconds: 750),
    Duration automaticRetryDelay = const Duration(seconds: 2),
  })  : _client = client ?? http.Client(),
        _platform = platform ?? const NativeAppUpdatePlatform(),
        _baseUriOverride = baseUri,
        _downloadPollInterval = downloadPollInterval,
        _automaticRetryDelay = automaticRetryDelay;

  static final AppUpdateService instance = AppUpdateService();
  static const int _maximumManifestBytes = 128 * 1024;
  static const int _maximumApkBytes = 512 * 1024 * 1024;
  static const int _maximumAutomaticRetries = 2;
  static const Duration _manifestReadTimeout = Duration(seconds: 15);

  final http.Client _client;
  final AppUpdatePlatform _platform;
  final Uri? _baseUriOverride;
  final Duration _downloadPollInterval;
  final Duration _automaticRetryDelay;

  Uri get _baseUri => _baseUriOverride ?? Uri.parse(MobileApi.baseUrl);

  bool get isSupported => _platform.isSupported;

  Future<AppUpdateCheckResult> check() async {
    if (!isSupported) {
      throw const AppUpdateException(
        code: 'unsupported_platform',
        message: 'Bu platformada APK update ishlamaydi',
      );
    }
    final current = await _platform.currentAppInfo();
    final endpoint = _baseUri.resolve('/v1/mobile/app-update/android');
    final http.StreamedResponse response;
    try {
      response = await _client
          .send(http.Request('GET', endpoint))
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const AppUpdateException(
        code: 'update_check_timeout',
        message: 'Yangilanish serveri javob bermadi',
      );
    } on SocketException {
      throw const AppUpdateException(
        code: 'update_check_network',
        message: 'Yangilanish serveriga ulanib bo‘lmadi',
      );
    } on http.ClientException {
      throw const AppUpdateException(
        code: 'update_check_network',
        message: 'Yangilanish serveriga ulanib bo‘lmadi',
      );
    }
    if (response.statusCode == HttpStatus.noContent) {
      return AppUpdateCheckResult(current: current, manifest: null);
    }
    if (response.statusCode != HttpStatus.ok) {
      throw AppUpdateException(
        code: 'update_check_failed',
        message: 'Yangilanish tekshirilmadi (${response.statusCode})',
      );
    }
    final List<int> body;
    try {
      body = await _readLimited(
        response.stream.timeout(_manifestReadTimeout),
        maximumBytes: _maximumManifestBytes,
        tooLargeCode: 'manifest_too_large',
      );
    } on TimeoutException {
      throw const AppUpdateException(
        code: 'update_check_timeout',
        message: 'Yangilanish serveri javobi tugamadi',
      );
    } on SocketException {
      throw const AppUpdateException(
        code: 'update_check_network',
        message: 'Yangilanish serveri bilan aloqa uzildi',
      );
    } on http.ClientException {
      throw const AppUpdateException(
        code: 'update_check_network',
        message: 'Yangilanish serveri bilan aloqa uzildi',
      );
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(body));
    } on FormatException {
      throw const AppUpdateException(
        code: 'invalid_manifest',
        message: 'Update ma’lumoti noto‘g‘ri',
      );
    }
    if (decoded is! Map) {
      throw const AppUpdateException(
        code: 'invalid_manifest',
        message: 'Update ma’lumoti noto‘g‘ri',
      );
    }
    final manifest = AppUpdateManifest.fromJson(
      decoded.cast<String, dynamic>(),
      baseUri: _baseUri,
    );
    return AppUpdateCheckResult(current: current, manifest: manifest);
  }

  Future<AppInstallLaunchResult> downloadAndInstall(
    AppUpdateCheckResult update, {
    AppUpdateProgress? onProgress,
    AppUpdateCancellation? cancellation,
  }) async {
    final manifest = update.manifest;
    if (manifest == null || !update.updateAvailable) {
      throw const AppUpdateException(
        code: 'no_update',
        message: 'Yangi versiya mavjud emas',
      );
    }
    if (manifest.sizeBytes > _maximumApkBytes) {
      throw const AppUpdateException(
        code: 'apk_too_large',
        message: 'APK hajmi ruxsat etilgan chegaradan katta',
      );
    }

    final path = await _download(
      manifest,
      onProgress: onProgress,
      cancellation: cancellation,
    );
    final finalFile = File(path);
    final fileExists = await finalFile.exists();
    final sizeMatches =
        fileExists && await finalFile.length() == manifest.sizeBytes;
    if (!sizeMatches) {
      await _platform.cancelDownload(manifest: manifest);
      throw const AppUpdateException(
        code: 'apk_size_mismatch',
        message: 'APK to‘liq yuklanmadi',
      );
    }
    if (!await _matchesManifest(finalFile, manifest)) {
      await _platform.cancelDownload(manifest: manifest);
      throw const AppUpdateException(
        code: 'apk_checksum_mismatch',
        message: 'APK xavfsizlik tekshiruvidan o‘tmadi',
      );
    }
    onProgress?.call(manifest.sizeBytes, manifest.sizeBytes);
    return _platform.installApk(
      path: finalFile.path,
      expectedPackageName: update.current.packageName,
      expectedVersionCode: manifest.versionCode,
    );
  }

  Future<AppUpdateDownloadSnapshot?> activeDownload(
    AppUpdateCheckResult update,
  ) async {
    final manifest = update.manifest;
    if (manifest == null || !update.updateAvailable) {
      return null;
    }
    final snapshot = await _platform.queryDownload(manifest: manifest);
    return switch (snapshot.status) {
      AppUpdateDownloadStatus.pending ||
      AppUpdateDownloadStatus.running ||
      AppUpdateDownloadStatus.paused ||
      AppUpdateDownloadStatus.successful =>
        snapshot,
      AppUpdateDownloadStatus.missing || AppUpdateDownloadStatus.failed => null,
    };
  }

  Future<String> _download(
    AppUpdateManifest manifest, {
    AppUpdateProgress? onProgress,
    AppUpdateCancellation? cancellation,
  }) async {
    var snapshot = await _platform.startOrAttachDownload(manifest: manifest);
    var retries = 0;
    while (true) {
      if (cancellation?.isCancelled == true) {
        await _cancelDownload(manifest);
      }
      final received = snapshot.receivedBytes.clamp(0, manifest.sizeBytes);
      onProgress?.call(received, manifest.sizeBytes);
      switch (snapshot.status) {
        case AppUpdateDownloadStatus.successful:
          if (snapshot.path.isEmpty) {
            throw const AppUpdateException(
              code: 'download_file_missing',
              message: 'Yuklangan APK fayli topilmadi',
            );
          }
          return snapshot.path;
        case AppUpdateDownloadStatus.failed:
        case AppUpdateDownloadStatus.missing:
          if (retries < _maximumAutomaticRetries &&
              (snapshot.status == AppUpdateDownloadStatus.missing ||
                  snapshot.retryable)) {
            retries += 1;
            await _platform.cancelDownload(manifest: manifest);
            await _waitForRetry(cancellation, manifest);
            snapshot =
                await _platform.startOrAttachDownload(manifest: manifest);
            continue;
          }
          throw _downloadFailure(snapshot);
        case AppUpdateDownloadStatus.pending:
        case AppUpdateDownloadStatus.running:
        case AppUpdateDownloadStatus.paused:
          await _waitForPoll(cancellation, manifest);
          snapshot = await _platform.queryDownload(manifest: manifest);
      }
    }
  }

  Future<bool> _matchesManifest(
    File file,
    AppUpdateManifest manifest,
  ) async {
    try {
      if (!await file.exists()) {
        return false;
      }
      if (await file.length() != manifest.sizeBytes) {
        return false;
      }
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString().toLowerCase() == manifest.sha256;
    } on FileSystemException {
      throw const AppUpdateException(
        code: 'update_storage_failed',
        message: 'Yuklangan APK faylini o‘qib bo‘lmadi',
      );
    }
  }

  Future<void> _waitForPoll(
    AppUpdateCancellation? cancellation,
    AppUpdateManifest manifest,
  ) async {
    await _waitOrCancel(_downloadPollInterval, cancellation);
    if (cancellation?.isCancelled == true) {
      await _cancelDownload(manifest);
    }
  }

  Future<void> _waitForRetry(
    AppUpdateCancellation? cancellation,
    AppUpdateManifest manifest,
  ) async {
    await _waitOrCancel(_automaticRetryDelay, cancellation);
    if (cancellation?.isCancelled == true) {
      await _cancelDownload(manifest);
    }
  }

  Future<void> _waitOrCancel(
    Duration duration,
    AppUpdateCancellation? cancellation,
  ) async {
    if (cancellation == null) {
      await Future<void>.delayed(duration);
      return;
    }
    if (cancellation.isCancelled) {
      return;
    }
    await Future.any<void>([
      Future<void>.delayed(duration),
      cancellation.whenCancelled,
    ]);
  }

  Future<Never> _cancelDownload(AppUpdateManifest manifest) async {
    await _platform.cancelDownload(manifest: manifest);
    throw const AppUpdateException(
      code: 'cancelled',
      message: 'Yangilanish bekor qilindi',
    );
  }

  AppUpdateException _downloadFailure(AppUpdateDownloadSnapshot snapshot) {
    if (snapshot.reason == 1006) {
      return const AppUpdateException(
        code: 'insufficient_storage',
        message: 'Yangilanish uchun qurilmada bo‘sh joy yetarli emas',
      );
    }
    if (snapshot.reason == HttpStatus.notFound) {
      return const AppUpdateException(
        code: 'apk_not_found',
        message: 'Yangilanish APK fayli serverda topilmadi',
      );
    }
    return AppUpdateException(
      code: 'apk_download_failed',
      message: snapshot.reason > 0
          ? 'APK yuklanmadi (${snapshot.reason})'
          : 'APK yuklanmadi',
    );
  }

  Future<List<int>> _readLimited(
    Stream<List<int>> stream, {
    required int maximumBytes,
    required String tooLargeCode,
  }) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (builder.length + chunk.length > maximumBytes) {
        throw AppUpdateException(
          code: tooLargeCode,
          message: 'Server javobi juda katta',
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}
