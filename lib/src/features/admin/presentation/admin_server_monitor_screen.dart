import 'dart:async';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import 'package:flutter/material.dart';
import 'widgets/admin_shell.dart';

class AdminServerMonitorScreen extends StatefulWidget {
  const AdminServerMonitorScreen({super.key});

  @override
  State<AdminServerMonitorScreen> createState() =>
      _AdminServerMonitorScreenState();
}

class _AdminServerMonitorScreenState extends State<AdminServerMonitorScreen> {
  AdminServerMonitorReport? _report;
  Object? _error;
  bool _loading = true;
  bool _liveConnected = false;
  DateTime? _lastUpdated;
  StreamSubscription<AdminServerMonitorReport>? _liveSubscription;
  int _liveGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSnapshot());
    _startLiveStream();
  }

  @override
  void dispose() {
    _liveGeneration++;
    unawaited(_liveSubscription?.cancel());
    super.dispose();
  }

  Future<void> _reload() async {
    await _loadSnapshot();
    _startLiveStream();
  }

  Future<void> _loadSnapshot() async {
    try {
      final report = await MobileApi.instance.adminServerMonitor();
      if (!mounted) {
        return;
      }
      setState(() {
        _report = report;
        _lastUpdated = DateTime.now();
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _startLiveStream() {
    _liveGeneration++;
    unawaited(_runLiveStream(_liveGeneration));
  }

  Future<void> _runLiveStream(int generation) async {
    while (mounted && generation == _liveGeneration) {
      try {
        await _connectLiveStreamOnce(generation);
      } catch (error) {
        if (!mounted || generation != _liveGeneration) {
          return;
        }
        setState(() {
          _liveConnected = false;
          _error = _report == null ? error : null;
        });
      }
      if (!mounted || generation != _liveGeneration) {
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _connectLiveStreamOnce(int generation) async {
    final completer = Completer<void>();

    await _liveSubscription?.cancel();
    _liveSubscription =
        MobileApi.instance.adminServerMonitorLiveEvents().listen(
      (report) {
        if (!mounted || generation != _liveGeneration) {
          return;
        }
        setState(() {
          _report = report;
          _lastUpdated = DateTime.now();
          _loading = false;
          _liveConnected = true;
          _error = null;
        });
      },
      onError: (error, _) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      cancelOnError: true,
    );
    await completer.future;
  }

  void _goHomeOrPop() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    nav.pushNamedAndRemoveUntil(AppRoutes.adminHome, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _goHomeOrPop();
        }
      },
      child: AdminShell(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goHomeOrPop,
        ),
        title: 'Server holati',
        selectedRouteName: AppRoutes.adminServerMonitor,
        activeTab: null,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final report = _report;
    if (_loading && report == null) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_error != null && report == null) {
      return AppRetryState(onRetry: _reload);
    }
    if (report == null) {
      return AppRetryState(onRetry: _reload);
    }

    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 128;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
        children: [
          _StatusSummaryPanel(
            report: report,
            liveConnected: _liveConnected,
            lastUpdated: _lastUpdated,
          ),
          const SizedBox(height: 12),
          _MetricGrid(
            report: report,
            liveConnected: _liveConnected,
          ),
          const SizedBox(height: 12),
          _TechnicalDetailsCard(
            report: report,
            initiallyExpanded: _error != null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            _InlineWarning(message: _error.toString()),
          ],
          const SizedBox(height: 10),
          _LastUpdatedCard(
            liveConnected: _liveConnected,
            lastUpdated: _lastUpdated,
          ),
        ],
      ),
    );
  }
}

class _StatusSummaryPanel extends StatelessWidget {
  const _StatusSummaryPanel({
    required this.report,
    required this.liveConnected,
    required this.lastUpdated,
  });

  final AdminServerMonitorReport report;
  final bool liveConnected;
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final serverOk = report.server.status == 'running';
    final dbOk = report.database.reachable;
    final backupOk = report.backups.exists && report.backups.fileCount > 0;
    final allOk = liveConnected && serverOk && dbOk && backupOk;
    final accent = _statusColor(context, allOk);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  allOk ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: accent,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    allOk ? 'Barqaror' : 'Diqqat kerak',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _StatusPill(
                  label: liveConnected ? 'Live' : 'Ulanmoqda',
                  active: liveConnected,
                ),
              ],
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    _InlineStateDot(ok: serverOk),
                    const SizedBox(width: 6),
                    const Text('Server'),
                    const SizedBox(width: 14),
                    _InlineStateDot(ok: dbOk),
                    const SizedBox(width: 6),
                    const Text('DB'),
                    const SizedBox(width: 14),
                    _InlineStateDot(ok: backupOk),
                    const SizedBox(width: 6),
                    const Text('Backup'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _KeyValueLine(
                label: 'Oxirgi update', value: _formatLocal(lastUpdated)),
            _KeyValueLine(
              label: 'Uptime',
              value: _formatDuration(report.server.uptimeSeconds),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.report,
    required this.liveConnected,
  });

  final AdminServerMonitorReport report;
  final bool liveConnected;

  @override
  Widget build(BuildContext context) {
    final backup = report.backups.latest;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.22,
      children: [
        _MetricTile(
          label: 'Live',
          value: liveConnected ? 'Ulangan' : 'Qayta ulanish',
          detail: 'WebSocket',
          ok: liveConnected,
          icon: Icons.bolt_rounded,
        ),
        _MetricTile(
          label: 'Database',
          value: report.database.reachable ? 'Online' : 'Offline',
          detail: report.database.pingMs > 0
              ? '${report.database.pingMs} ms'
              : _databaseStatusLabel(report.database.status),
          ok: report.database.reachable,
          icon: Icons.storage_rounded,
        ),
        _MetricTile(
          label: 'Server',
          value: _serverStatusLabel(report.server.status),
          detail: _formatDuration(report.server.uptimeSeconds),
          ok: report.server.status == 'running',
          icon: Icons.dns_rounded,
        ),
        _MetricTile(
          label: 'Backup',
          value: '${report.backups.fileCount} ta fayl',
          detail: backup == null ? 'Oxirgi fayl yo‘q' : _backupAgeLabel(backup),
          ok: report.backups.exists && report.backups.fileCount > 0,
          icon: Icons.inventory_2_rounded,
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.detail,
    required this.ok,
    required this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final bool ok;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _statusColor(context, ok);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: accent),
                const Spacer(),
                _InlineStateDot(ok: ok),
              ],
            ),
            const Spacer(),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineStateDot extends StatelessWidget {
  const _InlineStateDot({required this.ok});

  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, ok);
    return Container(
      height: 9,
      width: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _KeyValueLine extends StatelessWidget {
  const _KeyValueLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _TechnicalDetailsCard extends StatelessWidget {
  const _TechnicalDetailsCard({
    required this.report,
    required this.initiallyExpanded,
  });

  final AdminServerMonitorReport report;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: const Icon(Icons.tune_rounded),
          title: Text(
            'Texnik tafsilotlar',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: const Text('Bind, backup papkasi va xato matnlari'),
          children: [
            _MonitorRow(
                label: 'Server',
                value: _serverStatusLabel(report.server.status)),
            _MonitorRow(label: 'Bind', value: report.server.bindAddr),
            _MonitorRow(
              label: 'Boshlangan vaqt',
              value: _formatUnix(report.server.startedAtUnix),
            ),
            _MonitorRow(
              label: 'DB holati',
              value: _databaseStatusLabel(report.database.status),
            ),
            _MonitorRow(
              label: 'DB ping',
              value: report.database.pingMs > 0
                  ? '${report.database.pingMs} ms'
                  : 'Aniqlanmadi',
            ),
            if (report.database.error.trim().isNotEmpty)
              _MonitorRow(label: 'DB xato', value: report.database.error),
            _MonitorRow(
                label: 'Backup papkasi', value: report.backups.directory),
            _MonitorRow(
              label: 'Backup fayllar',
              value: '${report.backups.fileCount} ta',
            ),
            if (report.backups.latest != null) ...[
              _MonitorRow(
                label: 'Oxirgi backup',
                value: report.backups.latest!.name,
              ),
              _MonitorRow(
                label: 'Yangilangan',
                value: _formatUnix(report.backups.latest!.modifiedAtUnix),
              ),
              _MonitorRow(
                label: 'Hajm',
                value: _formatBytes(report.backups.latest!.sizeBytes),
              ),
            ],
            if (report.backups.error.trim().isNotEmpty)
              _MonitorRow(label: 'Backup xato', value: report.backups.error),
          ],
        ),
      ),
    );
  }
}

class _LastUpdatedCard extends StatelessWidget {
  const _LastUpdatedCard({
    required this.liveConnected,
    required this.lastUpdated,
  });

  final bool liveConnected;
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              liveConnected ? Icons.wifi_tethering_rounded : Icons.sync_rounded,
              color: _statusColor(context, liveConnected),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                liveConnected
                    ? 'Live WebSocket ulangan. Yangilandi: ${_formatLocal(lastUpdated)}'
                    : 'Live aloqa qayta ulanmoqda. Oxirgi ma\'lumot: ${_formatLocal(lastUpdated)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitorRow extends StatelessWidget {
  const _MonitorRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 42,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.25,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 58,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? scheme.primary.withValues(alpha: 0.15)
            : scheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: active ? scheme.onPrimaryContainer : scheme.error,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

Color _statusColor(BuildContext context, bool ok) {
  final scheme = Theme.of(context).colorScheme;
  return ok ? scheme.primary : scheme.error;
}

String _backupAgeLabel(AdminServerMonitorBackupFile backup) {
  return '${_formatDuration(backup.ageSeconds)} oldin';
}

String _serverStatusLabel(String status) {
  switch (status.trim()) {
    case 'running':
      return 'Faol';
    default:
      return 'To‘xtagan';
  }
}

String _databaseStatusLabel(String status) {
  switch (status.trim()) {
    case 'online':
      return 'Ulangan';
    case 'offline':
      return 'Ulanmadi';
    case 'unavailable':
      return 'Mavjud emas';
    default:
      return status.trim().isEmpty ? 'Noma\'lum' : status.trim();
  }
}

String _formatUnix(int unixSeconds) {
  if (unixSeconds <= 0) {
    return 'Aniqlanmadi';
  }
  return formatUnixSecondsLocalDateTime(unixSeconds);
}

String _formatLocal(DateTime? value) {
  if (value == null) {
    return 'Kutilmoqda';
  }
  return formatLocalDateTime(value);
}

String _formatDuration(int seconds) {
  if (seconds <= 0) {
    return '0 soniya';
  }
  final days = seconds ~/ 86400;
  final hours = (seconds % 86400) ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final parts = <String>[];
  if (days > 0) {
    parts.add('$days kun');
  }
  if (hours > 0) {
    parts.add('$hours soat');
  }
  if (minutes > 0) {
    parts.add('$minutes daqiqa');
  }
  if (parts.isEmpty) {
    parts.add('$seconds soniya');
  }
  return parts.join(' ');
}

String _formatBytes(int value) {
  if (value <= 0) {
    return '0 B';
  }
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = value.toDouble();
  var unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }
  if (unitIndex == 0) {
    return '${size.toStringAsFixed(0)} ${units[unitIndex]}';
  }
  return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[unitIndex]}';
}
