part of 'app_update_runtime.dart';

class _AppUpdateCheckDialog extends StatefulWidget {
  const _AppUpdateCheckDialog({
    required this.service,
    required this.onChecked,
  });

  final AppUpdateService service;
  final ValueChanged<AppUpdateCheckResult> onChecked;

  @override
  State<_AppUpdateCheckDialog> createState() => _AppUpdateCheckDialogState();
}

class _AppUpdateCheckDialogState extends State<_AppUpdateCheckDialog> {
  AppInstallationInfo? _current;
  AppUpdateCheckResult? _result;
  bool _checking = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final current = await widget.service.currentAppInfo();
      if (!mounted) return;
      setState(() => _current = current);
      final result = await widget.service.check();
      if (!mounted) return;
      setState(() {
        _result = result;
        _checking = false;
      });
      widget.onChecked(result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = error is AppUpdateException
            ? error.message
            : context.l10n.appUpdateCheckFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final result = _result;
    if (result != null &&
        result.updateAvailable &&
        widget.service.isSupported) {
      return _AppUpdateDialog(result: result, service: widget.service);
    }
    final latest = result != null && !result.updateAvailable;
    final available = result?.updateAvailable == true;
    return PopScope(
      canPop: !_checking,
      child: _AppUpdateDialogFrame(
        icon: Icon(
          _error != null
              ? Icons.cloud_off_rounded
              : latest
                  ? Icons.verified_outlined
                  : Icons.system_update_rounded,
        ),
        title: Text(
          latest
              ? l10n.appUpdateCurrentTitle
              : available
                  ? l10n.appUpdateAvailableTitle
                  : l10n.appUpdateSettingsTitle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_current != null) ...[
              _AppUpdateVersionDetails(
                  current: _current!, manifest: result?.manifest),
              const SizedBox(height: 16),
            ],
            if (_checking) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Text(l10n.checking),
            ] else if (_error != null) ...[
              Text(_error!),
              const SizedBox(height: 8),
              Text(l10n.appUpdateCheckRetryHint),
            ] else
              Text(latest ? l10n.appUpdateCurrent : l10n.appUpdateUnsupported),
            if (available && result!.manifest!.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.appUpdateReleaseNotes,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(result.manifest!.releaseNotes),
            ],
          ],
        ),
        actions: [
          if (_error != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.closeAction),
            ),
          FilledButton(
            onPressed: _checking
                ? null
                : _error != null
                    ? _check
                    : () => Navigator.of(context).pop(),
            child: Text(_error != null ? l10n.retry : l10n.closeAction),
          ),
        ],
      ),
    );
  }
}

class _AppUpdateDialogFrame extends StatelessWidget {
  const _AppUpdateDialogFrame({
    required this.icon,
    required this.title,
    required this.content,
    required this.actions,
  });

  final Widget icon;
  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      insetPadding: m3DialogInsetPadding,
      constraints: const BoxConstraints(maxWidth: m3DialogMaxWidth),
      scrollable: true,
      backgroundColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      icon: icon,
      iconColor: scheme.primary,
      title: title,
      content: SizedBox(width: double.maxFinite, child: content),
      actions: actions,
    );
  }
}

class _AppUpdateVersionDetails extends StatelessWidget {
  const _AppUpdateVersionDetails({required this.current, this.manifest});

  final AppInstallationInfo current;
  final AppUpdateManifest? manifest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppInfoRow(
            key: const ValueKey('app-update-current-version'),
            label: context.l10n.appUpdateInstalledVersion,
            value: '${current.versionName} (${current.versionCode})',
          ),
          if (manifest != null)
            AppInfoRow(
              key: const ValueKey('app-update-latest-version'),
              label: context.l10n.appUpdateLatestVersion,
              value: '${manifest!.versionName} (${manifest!.versionCode})',
            ),
        ],
      ),
    );
  }
}
