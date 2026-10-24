import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../native_back_button_bridge.dart';
import '../session/session.dart';
import '../widgets/display/app_info_row.dart';
import '../widgets/feedback/m3_confirm_dialog.dart';
import 'app_update_installer.dart';
import 'app_update_models.dart';
import 'app_update_service.dart';

part 'app_update_check_dialog.dart';

class AppUpdateRuntime extends StatefulWidget {
  const AppUpdateRuntime({super.key, required this.child, this.coordinator});

  final Widget child;
  final AppUpdateCoordinator? coordinator;

  @override
  State<AppUpdateRuntime> createState() => _AppUpdateRuntimeState();
}

class _AppUpdateRuntimeState extends State<AppUpdateRuntime>
    with WidgetsBindingObserver {
  Timer? _checkTimer;
  Timer? _fallbackTimer;
  Timer? _reconnectTimer;
  StreamSubscription<void>? _releaseSubscription;
  String? _watchEndpoint;

  AppUpdateCoordinator get coordinator =>
      widget.coordinator ?? AppUpdateCoordinator.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppSession.instance.revision.addListener(_scheduleCheck);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        coordinator.setForeground(true);
        _checkForUpdate();
      }
    });
    // Reconnection and a small metadata read also cover older servers without
    // the live route. They never restart an existing system download.
    _fallbackTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkForUpdate(),
    );
  }

  void _scheduleCheck() {
    _checkTimer?.cancel();
    _checkTimer = Timer(const Duration(milliseconds: 300), _checkForUpdate);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    coordinator.setForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) _scheduleCheck();
  }

  void _watchReleases() {
    if (!coordinator.isSupported) return;
    final endpoint = coordinator.endpointKey;
    if (_releaseSubscription != null && _watchEndpoint == endpoint) return;
    _reconnectTimer?.cancel();
    unawaited(_releaseSubscription?.cancel());
    _watchEndpoint = endpoint;
    void reconnect() {
      _releaseSubscription = null;
      _reconnectTimer?.cancel();
      if (mounted) {
        _reconnectTimer = Timer(const Duration(seconds: 3), _watchReleases);
      }
    }

    _releaseSubscription = coordinator.releaseChanges().listen(
          (_) => _checkForUpdate(),
          onError: (Object _, StackTrace __) => reconnect(),
          onDone: reconnect,
          cancelOnError: true,
        );
  }

  void _checkForUpdate() {
    if (!mounted) return;
    _watchReleases();
    final context = NativeBackButtonBridge.instance.navigatorKey.currentContext;
    if (context != null) {
      unawaited(coordinator.checkAndPrompt(context, manual: false));
    }
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _fallbackTimer?.cancel();
    _reconnectTimer?.cancel();
    unawaited(_releaseSubscription?.cancel());
    coordinator.setForeground(false);
    AppSession.instance.revision.removeListener(_scheduleCheck);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AppUpdateCoordinator extends ChangeNotifier {
  AppUpdateCoordinator({AppUpdateService? service})
      : _service = service ?? AppUpdateService.instance;

  static final AppUpdateCoordinator instance = AppUpdateCoordinator();

  final AppUpdateService _service;
  BuildContext? _context;
  String? _endpoint;
  int _scope = 0;
  bool _restored = false;
  bool _remoteKnown = false;
  bool _foreground = true;
  bool _disposed = false;
  bool _dialogOpen = false;
  bool _manualOpen = false;
  String? _shownOptionalArtifact;
  Future<void>? _refreshInFlight;
  bool _refreshAgain = false;
  AppUpdateCancellation? _preparation;
  String? _preparingArtifact;

  AppInstallationInfo? current;
  AppUpdateCheckResult? latest;
  PreparedAppUpdate? ready;
  bool checking = false;
  int receivedBytes = 0;
  String? error;

  bool get preparing => _preparingArtifact != null;
  bool get isSupported => _service.isSupported;
  String get endpointKey => _service.endpointKey;
  Stream<void> releaseChanges() => _service.releaseChanges();

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (foreground) _promptReady();
  }

  void _syncEndpoint() {
    if (_endpoint == endpointKey) return;
    _endpoint = endpointKey;
    _scope++;
    _preparation?.cancel();
    _preparation = null;
    _preparingArtifact = null;
    _refreshInFlight = null;
    _restored = false;
    _remoteKnown = false;
    _refreshAgain = false;
    _shownOptionalArtifact = null;
    ready = null;
    latest = null;
    current = null;
    error = null;
  }

  Future<void> checkAndPrompt(
    BuildContext context, {
    required bool manual,
  }) async {
    if (_disposed || (!manual && !isSupported)) return;
    _context = Navigator.of(context, rootNavigator: true).context;
    _syncEndpoint();
    if (!manual) {
      _promptReady();
      await refresh();
      return;
    }
    if (_manualOpen || _dialogOpen) return;
    _manualOpen = true;
    if (ready != null) {
      _shownOptionalArtifact = ready!.update.manifest!.artifactKey;
    }
    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (_) => _AppUpdateCheckDialog(coordinator: this),
      );
    } finally {
      _manualOpen = false;
      _promptReady();
    }
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    _syncEndpoint();
    if (_refreshInFlight != null) {
      _refreshAgain = true;
      return _refreshInFlight!;
    }
    final scope = _scope;
    return _refreshInFlight = _refresh(scope).whenComplete(() {
      if (scope != _scope) return;
      _refreshInFlight = null;
      if (_refreshAgain && !_disposed) {
        _refreshAgain = false;
        unawaited(refresh());
      }
    });
  }

  Future<void> _restore(int scope) async {
    try {
      final restored = await _service.restorePendingUpdate();
      if (_isCurrent(scope) && !_remoteKnown && restored != null) {
        _accept(restored);
      }
    } catch (_) {
      // Missing or corrupt local state cannot interrupt ordinary work.
    }
  }

  Future<void> _refresh(int scope) async {
    checking = true;
    error = null;
    _notify();
    if (isSupported && !_restored) {
      _restored = true;
      unawaited(_restore(scope));
    }
    try {
      final installed = await _service.currentAppInfo();
      if (!_isCurrent(scope)) return;
      current = installed;
      _notify();
      final result = await _service.check();
      if (!_isCurrent(scope)) return;
      _remoteKnown = true;
      _accept(result);
    } catch (failure) {
      if (_isCurrent(scope)) {
        error = failure is AppUpdateException
            ? failure.message
            : 'Yangilanish tekshirilmadi';
      }
    } finally {
      if (_isCurrent(scope)) {
        checking = false;
        _notify();
      }
    }
  }

  void _accept(AppUpdateCheckResult result) {
    latest = result;
    current = result.current;
    error = null;
    if (!result.updateAvailable || !isSupported) {
      _preparation?.cancel();
      _preparation = null;
      _preparingArtifact = null;
      ready = null;
      if (isSupported) unawaited(_remember(result));
      _notify();
      return;
    }
    final key = result.manifest!.artifactKey;
    if (ready?.update.manifest!.artifactKey == key) {
      ready = PreparedAppUpdate(update: result, path: ready!.path);
      unawaited(_remember(result));
      _notify();
      _promptReady();
      return;
    }
    if (_preparingArtifact == key) {
      unawaited(_remember(result));
      _notify();
      return;
    }
    _preparation?.cancel();
    final cancellation = AppUpdateCancellation(preserveDownload: true);
    _preparation = cancellation;
    _preparingArtifact = key;
    ready = null;
    receivedBytes = 0;
    _notify();
    unawaited(_prepare(result, cancellation, _scope));
  }

  Future<void> _remember(AppUpdateCheckResult result) async {
    try {
      await _service.rememberUpdate(result);
    } catch (_) {
      // The native download is still durable if preferences are unavailable.
    }
  }

  Future<void> _prepare(AppUpdateCheckResult result,
      AppUpdateCancellation cancellation, int scope) async {
    bool active() =>
        _isCurrent(scope) &&
        identical(_preparation, cancellation) &&
        !cancellation.isCancelled;
    try {
      final prepared = await _service.prepareUpdate(
        result,
        cancellation: cancellation,
        onProgress: (received, _) {
          if (active()) {
            receivedBytes = received;
            _notify();
          }
        },
      );
      if (!active()) return;
      // A policy change during the download applies without downloading again.
      ready = PreparedAppUpdate(update: latest!, path: prepared.path);
      _preparingArtifact = null;
      _preparation = null;
      error = null;
      _notify();
      _promptReady();
    } catch (failure) {
      if (!active()) return;
      _preparingArtifact = null;
      _preparation = null;
      error = failure is AppUpdateException
          ? failure.message
          : 'Yangilanishni tayyorlab bo‘lmadi';
      _notify();
    }
  }

  Future<AppInstallLaunchResult> installReady() async {
    final prepared = ready;
    if (prepared == null) {
      throw const AppUpdateException(
          code: 'no_update', message: 'APK hali tayyor emas');
    }
    try {
      return await _service.installPreparedUpdate(prepared);
    } on AppUpdateException catch (failure) {
      if (failure.code == 'prepared_apk_missing') {
        ready = null;
        _accept(prepared.update);
      }
      rethrow;
    }
  }

  void _promptReady() {
    final prepared = ready;
    final context = _context;
    if (_disposed ||
        prepared == null ||
        context == null ||
        !context.mounted ||
        !_foreground ||
        _dialogOpen) {
      return;
    }
    final key = prepared.update.manifest!.artifactKey;
    if (_manualOpen) {
      _shownOptionalArtifact = key;
      return;
    }
    if (!prepared.update.mandatory && _shownOptionalArtifact == key) return;
    _shownOptionalArtifact = key;
    _dialogOpen = true;
    unawaited(showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => _AppUpdateDialog(coordinator: this),
    ).whenComplete(() {
      _dialogOpen = false;
      _promptReady();
    }));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _isCurrent(int scope) =>
      !_disposed && scope == _scope && _endpoint == endpointKey;

  @override
  void dispose() {
    _disposed = true;
    _preparation?.cancel();
    super.dispose();
  }
}

class _AppUpdateDialog extends StatefulWidget {
  const _AppUpdateDialog({required this.coordinator});

  final AppUpdateCoordinator coordinator;

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog>
    with WidgetsBindingObserver {
  late PreparedAppUpdate _prepared;
  bool _installing = false;
  bool _closing = false;
  bool _installerLaunched = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _prepared = widget.coordinator.ready!;
    widget.coordinator.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
  }

  void _changed() {
    final prepared = widget.coordinator.ready;
    if (prepared == null && !_closing) {
      _closing = true;
      Navigator.of(context).pop();
    } else if (prepared != null && !_closing) {
      setState(() => _prepared = prepared);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.coordinator.refresh());
    }
  }

  @override
  void dispose() {
    widget.coordinator.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _install() async {
    if (_installing) return;
    setState(() {
      _installing = true;
      _message = null;
    });
    try {
      final result = await widget.coordinator.installReady();
      if (!mounted) return;
      setState(() {
        _installerLaunched = result == AppInstallLaunchResult.installerLaunched;
        _message = _installerLaunched
            ? context.l10n.appUpdateInstallerLaunched
            : context.l10n.appUpdateInstallPermission;
      });
    } catch (failure) {
      if (!mounted) return;
      setState(() => _message = failure is AppUpdateException
          ? failure.message
          : context.l10n.appUpdateDownloadFailed);
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final update = _prepared.update;
    final manifest = update.manifest!;
    final required = update.mandatory;
    return PopScope(
      canPop: !required && !_installing,
      child: _AppUpdateDialogFrame(
        icon: Icon(required
            ? Icons.system_update_alt_rounded
            : Icons.system_update_rounded),
        title: Text(required
            ? l10n.appUpdateRequiredTitle
            : l10n.appUpdateAvailableTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AppUpdateVersionDetails(
                current: update.current, manifest: manifest),
            const SizedBox(height: 16),
            Text(required
                ? l10n.appUpdateRequiredBody(manifest.versionName)
                : l10n.appUpdateAvailableBody(manifest.versionName)),
            const SizedBox(height: 8),
            Text(
                '${l10n.appUpdateFileSize}: ${(manifest.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB'),
            if (manifest.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.appUpdateReleaseNotes,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(manifest.releaseNotes),
            ],
            if (_installing) ...[
              const SizedBox(height: 18),
              const LinearProgressIndicator(),
            ],
            if (_message != null) ...[
              const SizedBox(height: 14),
              Text(_message!,
                  style: TextStyle(
                      color: _installerLaunched
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
        actions: [
          if (!required)
            TextButton(
                onPressed:
                    _installing ? null : () => Navigator.of(context).pop(),
                child: Text(l10n.appUpdateLater)),
          FilledButton.icon(
            onPressed: _installing ? null : _install,
            icon: Icon(_installerLaunched
                ? Icons.open_in_new_rounded
                : Icons.system_update_alt_rounded),
            label: Text(_installerLaunched
                ? l10n.appUpdateOpenInstaller
                : l10n.appUpdateAction),
          ),
        ],
      ),
    );
  }
}
