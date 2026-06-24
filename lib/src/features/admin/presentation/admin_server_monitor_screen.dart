import 'dart:async';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import 'package:flutter/material.dart';

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
      child: AppShell(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goHomeOrPop,
        ),
        title: 'Server holati',
        subtitle: '',
        nativeTopBar: true,
        nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
        contentPadding: EdgeInsets.zero,
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
        padding: EdgeInsets.fromLTRB(8, 4, 8, bottomPadding),
        children: [
          _StatusHeroCard(
            report: report,
            liveConnected: _liveConnected,
            lastUpdated: _lastUpdated,
          ),
          const SizedBox(height: 10),
          _QuickStatusCard(
            report: report,
            liveConnected: _liveConnected,
          ),
          const SizedBox(height: 10),
          _HealthCards(report: report),
          const SizedBox(height: 10),
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

class _StatusHeroCard extends StatelessWidget {
  const _StatusHeroCard({
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
    final healthScore = _healthScore(report);
    final summary = [
      if (serverOk) 'Server ishlayapti' else 'Server to‘xtagan',
      if (dbOk) 'DB ulangan' else 'DB ulanmagan',
      if (backupOk) 'Backup bor' else 'Backup yo‘q',
    ].join(' • ');
    final heroColor = _statusColor(context, serverOk && dbOk && backupOk);
    return Card.filled(
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: heroColor.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                color: heroColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: heroColor.withValues(alpha: 0.22)),
              ),
              child: Icon(
                serverOk ? Icons.monitor_heart_rounded : Icons.warning_rounded,
                color: heroColor,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          serverOk && dbOk
                              ? 'Tizim sog‘lom'
                              : 'Tizim tekshirish kerak',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      _StatusPill(
                        label: liveConnected ? 'Live' : 'Ulanmoqda',
                        active: liveConnected && serverOk,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    summary,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _HealthScoreBar(
                          score: healthScore,
                          color: heroColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$healthScore%',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _TinyInfoLine(
                    icon: Icons.schedule_rounded,
                    text: 'Yangilandi: ${_formatLocal(lastUpdated)}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStatusCard extends StatelessWidget {
  const _QuickStatusCard({
    required this.report,
    required this.liveConnected,
  });

  final AdminServerMonitorReport report;
  final bool liveConnected;

  @override
  Widget build(BuildContext context) {
    final backup = report.backups.latest;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Tezkor holat',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const Spacer(),
                _StatusPill(
                  label: liveConnected ? 'Live' : 'Ulanmoqda',
                  active: liveConnected,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _QuickStatusRow(
              icon: Icons.bolt_rounded,
              label: 'Live aloqa',
              value: liveConnected
                  ? 'WebSocket ulangan'
                  : 'WebSocket qayta ulanmoqda',
              ok: liveConnected,
            ),
            _QuickStatusRow(
              icon: Icons.speed_rounded,
              label: 'Ma\'lumotlar bazasi',
              value: report.database.pingMs > 0
                  ? 'Ulangan, ping ${report.database.pingMs} ms'
                  : _databaseStatusLabel(report.database.status),
              ok: report.database.reachable,
            ),
            _QuickStatusRow(
              icon: Icons.timer_rounded,
              label: 'Server ishlash vaqti',
              value: _formatDuration(report.server.uptimeSeconds),
              ok: report.server.status == 'running',
            ),
            _QuickStatusRow(
              icon: Icons.inventory_2_rounded,
              label: 'Backup',
              value: backup == null
                  ? '${report.backups.fileCount} ta fayl'
                  : '${report.backups.fileCount} ta fayl, ${_backupAgeLabel(backup)}',
              ok: report.backups.exists && report.backups.fileCount > 0,
              showDivider: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStatusRow extends StatelessWidget {
  const _QuickStatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool ok;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _statusColor(context, ok);
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              ok ? Icons.check_circle_rounded : Icons.error_rounded,
              color: accent,
              size: 22,
            ),
          ],
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.fromLTRB(50, 12, 0, 12),
            child: Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.75),
            ),
          )
        else
          const SizedBox(height: 2),
      ],
    );
  }
}

class _HealthCards extends StatelessWidget {
  const _HealthCards({required this.report});

  final AdminServerMonitorReport report;

  @override
  Widget build(BuildContext context) {
    final serverOk = report.server.status == 'running';
    final dbOk = report.database.reachable;
    final backupOk = report.backups.exists && report.backups.fileCount > 0;
    return Column(
      children: [
        _HealthCard(
          icon: Icons.dns_rounded,
          title: 'Server',
          status: _serverStatusLabel(report.server.status),
          description:
              'Server ${report.server.bindAddr} da ishlab turibdi. Ishlash davomiyligi: ${_formatDuration(report.server.uptimeSeconds)}.',
          ok: serverOk,
          value: _formatDuration(report.server.uptimeSeconds),
        ),
        const SizedBox(height: 10),
        _HealthCard(
          icon: Icons.storage_rounded,
          title: 'Ma\'lumotlar bazasi',
          status: _databaseStatusLabel(report.database.status),
          description: dbOk
              ? 'DB ulanishi faol. So‘nggi ping: ${report.database.pingMs} ms.'
              : 'DB ulanishida muammo bor: ${report.database.error}',
          ok: dbOk,
          value:
              report.database.pingMs > 0 ? '${report.database.pingMs} ms' : '-',
        ),
        const SizedBox(height: 10),
        _HealthCard(
          icon: Icons.backup_rounded,
          title: 'Backup',
          status: _backupStatusLabel(report),
          description: _backupDescription(report),
          ok: backupOk,
          value: '${report.backups.fileCount} ta',
        ),
      ],
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.description,
    required this.ok,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String status;
  final String description;
  final bool ok;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _statusColor(context, ok);
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      _StatusPill(label: status, active: ok),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _HealthScoreBar(
                          score: ok ? 100 : 32,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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

class _HealthScoreBar extends StatelessWidget {
  const _HealthScoreBar({
    required this.score,
    required this.color,
  });

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        minHeight: 8,
        value: (score.clamp(0, 100) as num).toDouble() / 100,
        backgroundColor: color.withValues(alpha: 0.14),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

class _TinyInfoLine extends StatelessWidget {
  const _TinyInfoLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
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

int _healthScore(AdminServerMonitorReport report) {
  var score = 0;
  if (report.server.status == 'running') {
    score += 34;
  }
  if (report.database.reachable) {
    score += 33;
  }
  if (report.backups.exists && report.backups.fileCount > 0) {
    score += 33;
  }
  return score;
}

String _backupStatusLabel(AdminServerMonitorReport report) {
  if (!report.backups.exists) {
    return 'Topilmadi';
  }
  if (report.backups.fileCount <= 0) {
    return 'Fayl yo‘q';
  }
  return 'Backup bor';
}

String _backupDescription(AdminServerMonitorReport report) {
  final latest = report.backups.latest;
  if (!report.backups.exists) {
    final error = report.backups.error.trim();
    return error.isEmpty
        ? 'Backup papkasi topilmadi.'
        : 'Backup papkasi topilmadi: $error.';
  }
  if (latest == null) {
    return 'Backup papkasi bor, lekin ichida dump fayl topilmadi.';
  }
  return 'Oxirgi backup ${latest.name}. Hajmi ${_formatBytes(latest.sizeBytes)}, yoshi ${_formatDuration(latest.ageSeconds)}.';
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
