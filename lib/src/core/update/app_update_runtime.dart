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
  Timer? _startupTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppSession.instance.revision.addListener(_scheduleCheck);
    _startupTimer = Timer(const Duration(seconds: 2), _checkForUpdate);
  }

  void _scheduleCheck() {
    _startupTimer?.cancel();
    _startupTimer = Timer(const Duration(milliseconds: 300), _checkForUpdate);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleCheck();
  }

  Future<void> _checkForUpdate() async {
    final context = NativeBackButtonBridge.instance.navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    await (widget.coordinator ?? AppUpdateCoordinator.instance).checkAndPrompt(
      context,
      manual: false,
    );
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    AppSession.instance.revision.removeListener(_scheduleCheck);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AppUpdateCoordinator {
  AppUpdateCoordinator({AppUpdateService? service})
      : _service = service ?? AppUpdateService.instance;

  static final AppUpdateCoordinator instance = AppUpdateCoordinator();

  final AppUpdateService _service;
  bool _checking = false;
  int? _shownVersionCode;

  Future<void> checkAndPrompt(
    BuildContext context, {
    required bool manual,
  }) async {
    if (_checking) {
      return;
    }
    if (!manual && !_service.isSupported) return;
    _checking = true;
    try {
      if (manual) {
        await showDialog<void>(
          context: context,
          useRootNavigator: true,
          barrierDismissible: false,
          builder: (_) => _AppUpdateCheckDialog(
            service: _service,
            onChecked: (result) {
              if (result.updateAvailable) {
                _shownVersionCode = result.manifest!.versionCode;
              }
            },
          ),
        );
        return;
      }
      final result = await _service.check();
      if (!context.mounted) {
        return;
      }
      if (!result.updateAvailable) {
        return;
      }
      final versionCode = result.manifest!.versionCode;
      if (!result.mandatory && _shownVersionCode == versionCode) {
        return;
      }
      _shownVersionCode = versionCode;
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (_) => _AppUpdateDialog(
          result: result,
          service: _service,
        ),
      );
    } catch (_) {
      // Startup checks stay quiet; manual checks show errors in their dialog.
    } finally {
      _checking = false;
    }
  }
}

class _AppUpdateDialog extends StatefulWidget {
  const _AppUpdateDialog({
    required this.result,
    required this.service,
  });

  final AppUpdateCheckResult result;
  final AppUpdateService service;

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog>
    with WidgetsBindingObserver {
  late AppUpdateCheckResult _result;
  bool _checkingPolicy = false;
  bool _downloading = false;
  bool _installerLaunched = false;
  int _receivedBytes = 0;
  String? _message;
  AppUpdateCancellation? _cancellation;

  AppUpdateManifest get manifest => _result.manifest!;

  @override
  void initState() {
    super.initState();
    _result = widget.result;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restoreActiveDownload());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshRequirement());
  }

  Future<void> _refreshRequirement() async {
    if (_downloading || _checkingPolicy) return;
    _checkingPolicy = true;
    try {
      final result = await widget.service.check();
      if (!mounted || _downloading) return;
      if (!result.updateAvailable) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        if (result.manifest!.versionCode != manifest.versionCode) {
          _installerLaunched = false;
          _message = null;
          _receivedBytes = 0;
        }
        _result = result;
      });
    } catch (_) {
      // A failed refresh must not unlock an already-required update.
    } finally {
      _checkingPolicy = false;
    }
  }

  double? get _progress {
    if (!_downloading || manifest.sizeBytes <= 0) {
      return null;
    }
    return (_receivedBytes / manifest.sizeBytes).clamp(0.0, 1.0);
  }

  Future<void> _restoreActiveDownload() async {
    try {
      final active = await widget.service.activeDownload(_result);
      if (!mounted || _downloading || active == null) {
        return;
      }
      await _install(initialReceivedBytes: active.receivedBytes);
    } catch (error) {
      if (!mounted || _downloading) {
        return;
      }
      setState(() {
        _message = error is AppUpdateException
            ? error.message
            : context.l10n.appUpdateDownloadFailed;
      });
    }
  }

  Future<void> _install({int initialReceivedBytes = 0}) async {
    if (_downloading) {
      return;
    }
    final cancellation = AppUpdateCancellation();
    setState(() {
      _downloading = true;
      _installerLaunched = false;
      _receivedBytes = initialReceivedBytes;
      _message = null;
      _cancellation = cancellation;
    });
    try {
      final result = await widget.service.downloadAndInstall(
        _result,
        cancellation: cancellation,
        onProgress: (received, _) {
          if (!mounted) {
            return;
          }
          setState(() {
            _receivedBytes = received;
          });
        },
      );
      if (!mounted) {
        return;
      }
      if (result == AppInstallLaunchResult.installerLaunched) {
        setState(() {
          _downloading = false;
          _installerLaunched = true;
          _message = context.l10n.appUpdateInstallerLaunched;
        });
        return;
      }
      setState(() {
        _downloading = false;
        _message = context.l10n.appUpdateInstallPermission;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _downloading = false;
        _message = error is AppUpdateException
            ? error.message
            : context.l10n.appUpdateDownloadFailed;
      });
    } finally {
      _cancellation = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final required = _result.mandatory;
    final progress = _progress;
    final downloadedMb = _receivedBytes / (1024 * 1024);
    final totalMb = manifest.sizeBytes / (1024 * 1024);
    return PopScope(
      canPop: !required && !_downloading,
      child: _AppUpdateDialogFrame(
        icon: Icon(
          required
              ? Icons.system_update_alt_rounded
              : Icons.system_update_rounded,
        ),
        title: Text(
          required ? l10n.appUpdateRequiredTitle : l10n.appUpdateAvailableTitle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AppUpdateVersionDetails(
              current: _result.current,
              manifest: manifest,
            ),
            const SizedBox(height: 16),
            Text(
              required
                  ? l10n.appUpdateRequiredBody(manifest.versionName)
                  : l10n.appUpdateAvailableBody(manifest.versionName),
            ),
            const SizedBox(height: 8),
            Text('${l10n.appUpdateFileSize}: ${totalMb.toStringAsFixed(1)} MB'),
            if (manifest.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                l10n.appUpdateReleaseNotes,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Text(manifest.releaseNotes),
            ],
            if (_downloading) ...[
              const SizedBox(height: 18),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text(
                l10n.appUpdateDownloadProgress(downloadedMb, totalMb),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.appUpdateBackgroundHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 14),
              Text(
                _message!,
                style: TextStyle(
                  color: _installerLaunched
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_downloading)
            TextButton(
              onPressed: _cancellation?.cancel,
              child: Text(l10n.appUpdateCancel),
            )
          else if (_installerLaunched) ...[
            if (!required)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.closeAction),
              ),
            FilledButton.icon(
              onPressed: () => _install(),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(l10n.appUpdateOpenInstaller),
            ),
          ] else ...[
            if (!required)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.appUpdateLater),
              ),
            FilledButton.icon(
              onPressed: () => _install(),
              icon: const Icon(Icons.download_rounded),
              label: Text(l10n.appUpdateAction),
            ),
          ],
        ],
      ),
    );
  }
}
