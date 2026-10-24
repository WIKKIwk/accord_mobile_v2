import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/mobile_api.dart';
import '../network/mobile_http_client.dart';
import '../realtime/warehouse_live_client.dart';
import 'app_update_installer.dart';
import 'app_update_models.dart';

typedef AppUpdateProgress = void Function(int receivedBytes, int totalBytes);

class AppUpdateCancellation {
  AppUpdateCancellation({this.preserveDownload = false});

  final bool preserveDownload;
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
  })  : _client = client ?? createMobileHttpClient(),
        _platform = platform ?? const NativeAppUpdatePlatform(),
        _baseUriOverride = baseUri,
        _downloadPollInterval = downloadPollInterval,
        _automaticRetryDelay = automaticRetryDelay;

  static final AppUpdateService instance = AppUpdateService();
  static const int _maximumManifestBytes = 128 * 1024;
  static const int _maximumApkBytes = 512 * 1024 * 1024;
  static const int _maximumAutomaticRetries = 4;
  static const Duration _manifestReadTimeout = Duration(seconds: 15);
  static const Duration _maximumRetryDelay = Duration(seconds: 30);

  final http.Client _client;
  final AppUpdatePlatform _platform;
  final Uri? _baseUriOverride;
  final Duration _downloadPollInterval;
  final Duration _automaticRetryDelay;

  Uri get _baseUri => _baseUriOverride ?? Uri.parse(MobileApi.baseUrl);

  bool get isSupported => _platform.isSupported;

  String get endpointKey => _baseUri.origin;

  Stream<void> releaseChanges() {
    final base = _baseUri;
    return connectWarehouseLive(base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/v1/mobile/app-update/android/live',
      query: null,
    )).where((event) => event['type'] == 'android_release_changed').map((_) {});
  }

  String get _cacheKey => 'app_update_manifest_v1:$endpointKey';

  Future<void> rememberUpdate(AppUpdateCheckResult update) async {
    final key = _cacheKey;
    final prefs = await SharedPreferences.getInstance();
    final saved = update.updateAvailable
        ? await prefs.setString(key, jsonEncode(update.manifest!.toJson()))
        : await prefs.remove(key);
    if (!saved) {
      throw const AppUpdateException(
        code: 'update_storage_failed',
        message: 'Yangilanish ma’lumotini saqlab bo‘lmadi',
      );
    }
  }

  /// The manifest and native DownloadManager state survive process termination.
  /// Restoring does not need a successful request to the update server.
  Future<AppUpdateCheckResult?> restorePendingUpdate() async {
    final key = _cacheKey;
    final baseUri = _baseUri;
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(key);
    if (encoded == null) return null;
    final AppUpdateManifest manifest;
    try {
      manifest = AppUpdateManifest.fromJson(
        (jsonDecode(encoded) as Map).cast<String, dynamic>(),
        baseUri: baseUri,
      );
    } on Object {
      await prefs.remove(key);
      return null;
    }
    final update = AppUpdateCheckResult(
      current: await currentAppInfo(),
      manifest: manifest,
    );
    if (!update.updateAvailable) {
      await prefs.remove(key);
      return null;
    }
    return update;
  }

  AppInstallationInfo? _currentAppInfo;

  Future<AppInstallationInfo> currentAppInfo() async => _currentAppInfo ??=
      await _platform.currentAppInfo().timeout(_manifestReadTimeout);

  Future<AppUpdateCheckResult> check() async {
    final baseUri = _baseUri;
    final current = await currentAppInfo();
    final endpoint = baseUri.resolve('/v1/mobile/app-update/android');
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
      baseUri: baseUri,
    );
    return AppUpdateCheckResult(current: current, manifest: manifest);
  }

  Future<AppInstallLaunchResult> downloadAndInstall(
    AppUpdateCheckResult update, {
    AppUpdateProgress? onProgress,
    AppUpdateCancellation? cancellation,
  }) async {
    final prepared = await prepareUpdate(
      update,
      onProgress: onProgress,
      cancellation: cancellation,
    );
    return installPreparedUpdate(prepared);
  }

  Future<PreparedAppUpdate> prepareUpdate(
    AppUpdateCheckResult update, {
    AppUpdateProgress? onProgress,
    AppUpdateCancellation? cancellation,
  }) async {
    if (!isSupported) {
      throw const AppUpdateException(
        code: 'unsupported_platform',
        message: 'Bu qurilmada APK faylini o‘rnatib bo‘lmaydi',
      );
    }
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

    await rememberUpdate(update);
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
    await _platform.validateApk(
      path: finalFile.path,
      expectedPackageName: update.current.packageName,
      expectedVersionCode: manifest.versionCode,
    );
    return PreparedAppUpdate(update: update, path: finalFile.path);
  }

  Future<AppInstallLaunchResult> installPreparedUpdate(
    PreparedAppUpdate prepared,
  ) async {
    final update = prepared.update;
    if (!await _matchesManifest(File(prepared.path), update.manifest!)) {
      throw const AppUpdateException(
        code: 'prepared_apk_missing',
        message: 'Tayyor yangilanish qayta yuklanmoqda',
      );
    }
    return _platform.installApk(
      path: prepared.path,
      expectedPackageName: update.current.packageName,
      expectedVersionCode: update.manifest!.versionCode,
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
    if (cancellation?.isCancelled == true) {
      await _cancelDownload(manifest, cancellation);
    }
    var snapshot = await _platform.startOrAttachDownload(manifest: manifest);
    var retries = 0;
    while (true) {
      if (cancellation?.isCancelled == true) {
        await _cancelDownload(manifest, cancellation);
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
            await _waitForRetry(
              cancellation,
              manifest,
              attempt: retries,
            );
            snapshot =
                await _platform.startOrAttachDownload(manifest: manifest);
            continue;
          }
          throw _downloadFailure(snapshot);
        case AppUpdateDownloadStatus.pending:
        case AppUpdateDownloadStatus.running:
        case AppUpdateDownloadStatus.paused:
          await _waitForPoll(cancellation, manifest);
          // Android owns network retries and HTTP Range resumption. A quiet or
          // paused transfer must retain its ID and partial file, even offline.
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
      await _cancelDownload(manifest, cancellation);
    }
  }

  Future<void> _waitForRetry(
    AppUpdateCancellation? cancellation,
    AppUpdateManifest manifest, {
    required int attempt,
  }) async {
    await _waitOrCancel(_retryDelay(attempt), cancellation);
    if (cancellation?.isCancelled == true) {
      await _cancelDownload(manifest, cancellation);
    }
  }

  Duration _retryDelay(int attempt) {
    if (_automaticRetryDelay <= Duration.zero) {
      return Duration.zero;
    }
    var multiplier = 1;
    for (var index = 1; index < attempt && index < 4; index += 1) {
      multiplier *= 2;
    }
    final delayMicros = _automaticRetryDelay.inMicroseconds * multiplier;
    return delayMicros >= _maximumRetryDelay.inMicroseconds
        ? _maximumRetryDelay
        : Duration(microseconds: delayMicros);
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

  Future<Never> _cancelDownload(
    AppUpdateManifest manifest,
    AppUpdateCancellation? cancellation,
  ) async {
    if (cancellation?.preserveDownload != true) {
      await _platform.cancelDownload(manifest: manifest);
    }
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
