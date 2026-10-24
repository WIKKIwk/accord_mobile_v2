part of 'app_update_runtime.dart';

class _AppUpdateCheckDialog extends StatefulWidget {
  const _AppUpdateCheckDialog({required this.coordinator});

  final AppUpdateCoordinator coordinator;

  @override
  State<_AppUpdateCheckDialog> createState() => _AppUpdateCheckDialogState();
}

class _AppUpdateCheckDialogState extends State<_AppUpdateCheckDialog> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.coordinator.refresh());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.coordinator,
      builder: (context, _) {
        final coordinator = widget.coordinator;
        if (coordinator.ready != null) {
          return _AppUpdateDialog(coordinator: coordinator);
        }
        final l10n = context.l10n;
        final result = coordinator.latest;
        final latest = result != null && !result.updateAvailable;
        final manifest = result?.manifest;
        final progress = manifest == null
            ? null
            : (coordinator.receivedBytes / manifest.sizeBytes)
                .clamp(0.0, 1.0)
                .toDouble();
        return _AppUpdateDialogFrame(
          icon: Icon(coordinator.error != null
              ? Icons.cloud_off_rounded
              : latest
                  ? Icons.verified_outlined
                  : Icons.system_update_rounded),
          title: Text(latest
              ? l10n.appUpdateCurrentTitle
              : result?.updateAvailable == true && !coordinator.preparing
                  ? l10n.appUpdateAvailableTitle
                  : l10n.appUpdateSettingsTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (coordinator.current != null) ...[
                _AppUpdateVersionDetails(
                    current: coordinator.current!, manifest: manifest),
                const SizedBox(height: 16),
              ],
              if (coordinator.preparing) ...[
                if (progress == null)
                  const LinearProgressIndicator()
                else
                  TweenAnimationBuilder<double>(
                    key: ValueKey(manifest!.artifactKey),
                    tween: Tween<double>(begin: progress, end: progress),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) =>
                        LinearProgressIndicator(value: value),
                  ),
                const SizedBox(height: 12),
                Text(l10n.appUpdateBackgroundHint),
              ] else if (coordinator.checking) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Text(l10n.checking),
              ] else if (coordinator.error != null) ...[
                Text(coordinator.error!),
                const SizedBox(height: 8),
                Text(l10n.appUpdateCheckRetryHint),
              ] else
                Text(
                    latest ? l10n.appUpdateCurrent : l10n.appUpdateUnsupported),
            ],
          ),
          actions: [
            if (coordinator.error != null)
              TextButton(
                  onPressed: () => coordinator.refresh(),
                  child: Text(l10n.retry)),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.closeAction)),
          ],
        );
      },
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
