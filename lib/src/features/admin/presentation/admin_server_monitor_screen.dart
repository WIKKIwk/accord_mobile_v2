import 'dart:async';
import 'dart:math' as math;

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
    final score = _healthScore(
      liveConnected: liveConnected,
      serverOk: serverOk,
      dbOk: dbOk,
      backupOk: backupOk,
      cpuPercent: report.runtime.cpuPercent,
      memoryPercent: report.runtime.memoryPercent,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _HealthDial(
                  value: score,
                  active: allOk,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allOk ? 'Tizim barqaror' : 'Tekshiruv kerak',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(
                  label: liveConnected ? 'Live' : 'Ulanmoqda',
                  active: liveConnected,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _RuntimeStrip(report: report),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CompactStatusChip(
                    label: 'Server',
                    value: _serverStatusLabel(report.server.status),
                    ok: serverOk,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactStatusChip(
                    label: 'Baza',
                    value: report.database.pingMs > 0
                        ? '${report.database.pingMs} ms'
                        : _databaseStatusLabel(report.database.status),
                    ok: dbOk,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactStatusChip(
                    label: 'Backup',
                    value: '${report.backups.fileCount} fayl',
                    ok: backupOk,
                  ),
                ),
              ],
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

class _HealthDial extends StatelessWidget {
  const _HealthDial({
    required this.value,
    required this.active,
  });

  final int value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : const Color(0xFFB56B20);
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(92),
            painter: _HealthDialPainter(
              value: value,
              color: color,
              trackColor: scheme.outlineVariant.withValues(alpha: 0.68),
            ),
          ),
          Text(
            '$value%',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
          ),
        ],
      ),
    );
  }
}

class _HealthDialPainter extends CustomPainter {
  const _HealthDialPainter({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  final int value;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 7;
    final activeTicks = ((value.clamp(0, 100) / 100) * 28).round();
    for (var i = 0; i < 28; i++) {
      final angle = -math.pi * 0.78 + i * (math.pi * 1.56 / 27);
      final start = Offset(
        center.dx + math.cos(angle) * (radius - 8),
        center.dy + math.sin(angle) * (radius - 8),
      );
      final end = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      final paint = Paint()
        ..color = i < activeTicks ? color : trackColor
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HealthDialPainter oldDelegate) {
    return value != oldDelegate.value ||
        color != oldDelegate.color ||
        trackColor != oldDelegate.trackColor;
  }
}

class _RuntimeStrip extends StatelessWidget {
  const _RuntimeStrip({required this.report});

  final AdminServerMonitorReport report;

  @override
  Widget build(BuildContext context) {
    final runtime = report.runtime;
    return Row(
      children: [
        Expanded(
          child: _MetricBar(
            label: 'CPU bosim',
            value: runtime.cpuPercent,
            caption: _formatLoad(runtime.loadAverage),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricBar(
            label: 'Xotira',
            value: runtime.memoryPercent,
            caption: runtime.memoryTotalMb > 0
                ? '${runtime.memoryUsedMb}/${runtime.memoryTotalMb} MB'
                : 'aniqlanmadi',
          ),
        ),
      ],
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final int value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final normalized = value.clamp(0, 100).toDouble() / 100;
    final color = value >= 85
        ? scheme.error
        : value >= 70
            ? const Color(0xFFB56B20)
            : scheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  '$value%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: normalized,
                minHeight: 7,
                backgroundColor: scheme.surface.withValues(alpha: 0.75),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactStatusChip extends StatelessWidget {
  const _CompactStatusChip({
    required this.label,
    required this.value,
    required this.ok,
  });

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _statusColor(context, ok);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
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
            _MonitorRow(
              label: 'CPU bosim',
              value: '${report.runtime.cpuPercent.clamp(0, 100)}%',
            ),
            _MonitorRow(
              label: 'Xotira',
              value: report.runtime.memoryTotalMb > 0
                  ? '${report.runtime.memoryUsedMb} / ${report.runtime.memoryTotalMb} MB (${report.runtime.memoryPercent.clamp(0, 100)}%)'
                  : 'Aniqlanmadi',
            ),
            _MonitorRow(
              label: 'Load average',
              value: _formatLoad(report.runtime.loadAverage),
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

int _healthScore({
  required bool liveConnected,
  required bool serverOk,
  required bool dbOk,
  required bool backupOk,
  required int cpuPercent,
  required int memoryPercent,
}) {
  var score = 0;
  if (liveConnected) {
    score += 16;
  }
  if (serverOk) {
    score += 22;
  }
  if (dbOk) {
    score += 22;
  }
  if (backupOk) {
    score += 16;
  }
  score += _resourceScore(cpuPercent, 12);
  score += _resourceScore(memoryPercent, 12);
  return score.clamp(0, 100);
}

int _resourceScore(int percent, int weight) {
  if (percent <= 0) {
    return weight;
  }
  if (percent >= 95) {
    return 0;
  }
  if (percent >= 85) {
    return (weight * 0.35).round();
  }
  if (percent >= 70) {
    return (weight * 0.7).round();
  }
  return weight;
}

String _formatLoad(double value) {
  if (value <= 0) {
    return 'load 0.00';
  }
  return 'load ${value.toStringAsFixed(2)}';
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
