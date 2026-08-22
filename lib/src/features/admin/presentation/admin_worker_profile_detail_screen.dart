import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../logic/canonical_apparatus_display.dart';
import 'widgets/admin_dock.dart';

typedef AdminWorkerProfileLoader = Future<AdminWorkerProfileDetail> Function();
typedef AdminWorkerProfileApparatusLoader = Future<List<AdminApparatus>>
    Function();

class AdminWorkerProfileDetailScreen extends StatefulWidget {
  const AdminWorkerProfileDetailScreen({
    super.key,
    required this.entry,
    this.detailLoader,
    this.apparatusLoader,
  });

  final AdminUserListEntry entry;
  final AdminWorkerProfileLoader? detailLoader;
  final AdminWorkerProfileApparatusLoader? apparatusLoader;

  @override
  State<AdminWorkerProfileDetailScreen> createState() =>
      _AdminWorkerProfileDetailScreenState();
}

class _AdminWorkerProfileDetailScreenState
    extends State<AdminWorkerProfileDetailScreen> {
  late Future<_WorkerProfileViewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_WorkerProfileViewData> _load() async {
    final results = await Future.wait<Object>([
      widget.detailLoader?.call() ??
          MobileApi.instance.adminWorkerProfileDetail(widget.entry.id),
      widget.apparatusLoader?.call() ??
          MobileApi.instance.adminApparatus(limit: 10000),
    ]);
    return _WorkerProfileViewData(
      detail: results[0] as AdminWorkerProfileDetail,
      apparatus: results[1] as List<AdminApparatus>,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: context.l10n.adminText('detail.worker_title'),
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      contentPadding: EdgeInsets.zero,
      bottom: const AdminDock(activeTab: AdminDockTab.user),
      child: FutureBuilder<_WorkerProfileViewData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _WorkerProfileError(onRetry: () => unawaited(_refresh()));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _WorkerProfileBody(
              detail: snapshot.data!.detail,
              apparatus: snapshot.data!.apparatus,
            ),
          );
        },
      ),
    );
  }
}

class _WorkerProfileViewData {
  const _WorkerProfileViewData({
    required this.detail,
    required this.apparatus,
  });

  final AdminWorkerProfileDetail detail;
  final List<AdminApparatus> apparatus;
}

class _WorkerProfileBody extends StatelessWidget {
  const _WorkerProfileBody({
    required this.detail,
    required this.apparatus,
  });

  final AdminWorkerProfileDetail detail;
  final List<AdminApparatus> apparatus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final worker = detail.worker;
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 116),
      children: [
        _InfoCard(
          title: worker.name,
          rows: [
            _InfoRow(l10n.adminText('detail.ref'), worker.id),
            _InfoRow(l10n.adminText('profile.phone'), worker.phone),
            _InfoRow(l10n.adminText('detail.level'), worker.level),
            _InfoRow(l10n.adminText('detail.item_code'), worker.code),
          ],
        ),
        _WorkerApparatusCard(
          apparatusIds: detail.assignedApparatus,
          apparatus: apparatus,
        ),
        _WorkerGroupsCard(
          groups: detail.assignedGroups,
          apparatus: apparatus,
        ),
        _ActiveSessionsCard(
          sessions: detail.activeSessions,
          apparatus: apparatus,
        ),
        _ProgressBatchesCard(
          batches: detail.recentBatches,
          apparatus: apparatus,
        ),
        _RecentLogsCard(
          logs: detail.recentLogs,
          apparatus: apparatus,
        ),
      ],
    );
  }
}

class _WorkerApparatusCard extends StatelessWidget {
  const _WorkerApparatusCard({
    required this.apparatusIds,
    required this.apparatus,
  });

  final List<String> apparatusIds;
  final List<AdminApparatus> apparatus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final names = canonicalApparatusDisplayLabels(apparatusIds, apparatus);
    return _InfoCard(
      title: l10n.adminText('label.apparatus'),
      rows: [
        _InfoRow(
          l10n.adminText('label.status'),
          names.isEmpty
              ? l10n.adminText('detail.assigned_none')
              : names.join(', '),
        ),
      ],
    );
  }
}

class _WorkerGroupsCard extends StatelessWidget {
  const _WorkerGroupsCard({
    required this.groups,
    required this.apparatus,
  });

  final List<AdminWorkerGroup> groups;
  final List<AdminApparatus> apparatus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (groups.isEmpty) {
      return _InfoCard(
        title: l10n.adminText('detail.worker_groups'),
        rows: [
          _InfoRow(l10n.adminText('label.status'),
              l10n.adminText('detail.assigned_none')),
        ],
      );
    }
    return _InfoCard(
      title: l10n.adminText('detail.worker_groups'),
      rows: [
        for (final group in groups)
          _InfoRow(
            canonicalApparatusDisplayLabel(group.apparatusId, apparatus),
            [
              group.groupCode,
              group.shift,
              '${group.startTime}-${group.endTime}',
              '${group.workDaysPerWeek} ${l10n.adminText('worker.day_count')}',
            ].where((item) => item.trim().isNotEmpty).join(' • '),
          ),
      ],
    );
  }
}

class _ActiveSessionsCard extends StatelessWidget {
  const _ActiveSessionsCard({
    required this.sessions,
    required this.apparatus,
  });

  final List<AdminWorkerRunSession> sessions;
  final List<AdminApparatus> apparatus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (sessions.isEmpty) {
      return _InfoCard(
        title: l10n.adminText('detail.active_jobs'),
        rows: [
          _InfoRow(l10n.adminText('label.status'),
              l10n.adminText('detail.active_none')),
        ],
      );
    }
    return _InfoCard(
      title: l10n.adminText('detail.active_jobs'),
      rows: [
        for (final session in sessions)
          _InfoRow(
            canonicalApparatusDisplayLabel(session.apparatus, apparatus),
            '${session.orderId} • ${session.status}',
          ),
      ],
    );
  }
}

class _ProgressBatchesCard extends StatelessWidget {
  const _ProgressBatchesCard({
    required this.batches,
    required this.apparatus,
  });

  final List<AdminProgressBatch> batches;
  final List<AdminApparatus> apparatus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (batches.isEmpty) {
      return _InfoCard(
        title: l10n.adminText('detail.progress_batches'),
        rows: [
          _InfoRow(l10n.adminText('label.status'),
              l10n.adminText('detail.batch_none')),
        ],
      );
    }
    return _InfoCard(
      title: l10n.adminText('detail.progress_batches'),
      rows: [
        for (final batch in batches)
          _InfoRow(
            batch.orderId,
            [
              canonicalApparatusDisplayLabel(batch.apparatus, apparatus),
              batch.status,
              '${_formatNumber(batch.producedQty)} ${batch.uom}'.trim(),
              if (batch.finishedGoodsKg != null)
                'kg ${_formatNumber(batch.finishedGoodsKg!)}',
              if (batch.finishedGoodsMeter != null)
                'm ${_formatNumber(batch.finishedGoodsMeter!)}',
            ].where((item) => item.trim().isNotEmpty).join(' • '),
          ),
      ],
    );
  }
}

class _RecentLogsCard extends StatelessWidget {
  const _RecentLogsCard({
    required this.logs,
    required this.apparatus,
  });

  final List<AdminProductionOrderLogEntry> logs;
  final List<AdminApparatus> apparatus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (logs.isEmpty) {
      return _InfoCard(
        title: l10n.adminText('detail.logs'),
        rows: [
          _InfoRow(l10n.adminText('label.status'),
              l10n.adminText('detail.log_none')),
        ],
      );
    }
    return _InfoCard(
      title: l10n.adminText('detail.logs'),
      rows: [
        for (final log in logs)
          _InfoRow(
            '${_actionLabel(l10n, log.action)} • '
            '${canonicalApparatusDisplayLabel(log.apparatus, apparatus)}',
            [
              log.orderId,
              '${log.fromState} → ${log.toState}',
              if (log.completedWithIssue)
                l10n.adminText('detail.problem_closed'),
            ].where((item) => item.trim().isNotEmpty).join(' • '),
          ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card.filled(
      margin: const EdgeInsets.only(bottom: 8),
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0) const Divider(height: 18),
              _InfoLine(row: rows[index]),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.row});

  final _InfoRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = row.value.trim().isEmpty
        ? context.l10n.adminText('profile.entered')
        : row.value.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _WorkerProfileError extends StatelessWidget {
  const _WorkerProfileError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton(
        onPressed: onRetry,
        child: Text(context.l10n.adminText('detail.reload')),
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;
}

String _actionLabel(AppLocalizations l10n, String action) {
  return switch (action.trim()) {
    'start' => l10n.adminText('detail.action_start'),
    'pause' => l10n.adminText('detail.action_pause'),
    'detach_roll' => l10n.adminText('detail.action_detach_roll'),
    'resume' => l10n.adminText('detail.action_resume'),
    'roll_complete' => l10n.adminText('detail.action_roll_complete'),
    'complete' => l10n.adminText('detail.action_complete'),
    final value when value.isNotEmpty => value,
    _ => l10n.adminText('detail.action_generic'),
  };
}

String _formatNumber(double value) => formatQuantity(value);
