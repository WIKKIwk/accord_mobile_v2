import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../native_back_button_bridge.dart';
import 'app_update_installer.dart';
import 'app_update_models.dart';
import 'app_update_service.dart';

class AppUpdateRuntime extends StatefulWidget {
  const AppUpdateRuntime({super.key, required this.child});

  final Widget child;

  @override
  State<AppUpdateRuntime> createState() => _AppUpdateRuntimeState();
}

class _AppUpdateRuntimeState extends State<AppUpdateRuntime> {
  Timer? _startupTimer;

  @override
  void initState() {
    super.initState();
    _startupTimer = Timer(const Duration(seconds: 2), _checkForUpdate);
  }

  Future<void> _checkForUpdate() async {
    final context = NativeBackButtonBridge.instance.navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    await AppUpdateCoordinator.instance.checkAndPrompt(
      context,
      manual: false,
    );
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
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
    if (_checking || !_service.isSupported) {
      if (manual && context.mounted) {
        _showMessage(context, context.l10n.appUpdateUnsupported);
      }
      return;
    }
    _checking = true;
    try {
      final result = await _service.check();
      if (!context.mounted) {
        return;
      }
      if (!result.updateAvailable) {
        if (manual) {
          _showMessage(context, context.l10n.appUpdateCurrent);
        }
        return;
      }
      final versionCode = result.manifest!.versionCode;
      if (!manual && _shownVersionCode == versionCode) {
        return;
      }
      _shownVersionCode = versionCode;
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: !result.mandatory,
        builder: (_) => _AppUpdateDialog(
          result: result,
          service: _service,
        ),
      );
    } catch (error) {
      if (manual && context.mounted) {
        final message = error is AppUpdateException
            ? error.message
            : context.l10n.appUpdateCheckFailed;
        _showMessage(context, message);
      }
    } finally {
      _checking = false;
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
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

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  bool _downloading = false;
  int _receivedBytes = 0;
  String? _message;
  AppUpdateCancellation? _cancellation;

  AppUpdateManifest get manifest => widget.result.manifest!;

  double? get _progress {
    if (!_downloading || manifest.sizeBytes <= 0) {
      return null;
    }
    return (_receivedBytes / manifest.sizeBytes).clamp(0.0, 1.0);
  }

  Future<void> _install() async {
    final cancellation = AppUpdateCancellation();
    setState(() {
      _downloading = true;
      _receivedBytes = 0;
      _message = null;
      _cancellation = cancellation;
    });
    try {
      final result = await widget.service.downloadAndInstall(
        widget.result,
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
        Navigator.of(context).pop();
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
    final required = widget.result.mandatory;
    final progress = _progress;
    final downloadedMb = _receivedBytes / (1024 * 1024);
    final totalMb = manifest.sizeBytes / (1024 * 1024);
    return PopScope(
      canPop: !required && !_downloading,
      child: AlertDialog(
        icon: Icon(
          required
              ? Icons.system_update_alt_rounded
              : Icons.system_update_rounded,
        ),
        title: Text(
          required ? l10n.appUpdateRequiredTitle : l10n.appUpdateAvailableTitle,
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                required
                    ? l10n.appUpdateRequiredBody(manifest.versionName)
                    : l10n.appUpdateAvailableBody(manifest.versionName),
              ),
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
              ],
              if (_message != null) ...[
                const SizedBox(height: 14),
                Text(
                  _message!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (_downloading)
            TextButton(
              onPressed: _cancellation?.cancel,
              child: Text(l10n.appUpdateCancel),
            )
          else ...[
            if (!required)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.appUpdateLater),
              ),
            FilledButton.icon(
              onPressed: _install,
              icon: const Icon(Icons.download_rounded),
              label: Text(l10n.appUpdateAction),
            ),
          ],
        ],
      ),
    );
  }
}
