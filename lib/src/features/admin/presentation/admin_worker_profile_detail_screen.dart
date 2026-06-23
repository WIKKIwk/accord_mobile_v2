import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';

class AdminWorkerProfileDetailScreen extends StatefulWidget {
  const AdminWorkerProfileDetailScreen({super.key, required this.entry});

  final AdminUserListEntry entry;

  @override
  State<AdminWorkerProfileDetailScreen> createState() =>
      _AdminWorkerProfileDetailScreenState();
}

class _AdminWorkerProfileDetailScreenState
    extends State<AdminWorkerProfileDetailScreen> {
  late Future<AdminWorkerProfileDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AdminWorkerProfileDetail> _load() {
    return MobileApi.instance.adminWorkerProfileDetail(widget.entry.id);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Worker detail',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      contentPadding: EdgeInsets.zero,
      bottom: const AdminDock(activeTab: AdminDockTab.suppliers),
      child: FutureBuilder<AdminWorkerProfileDetail>(
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
            child: _WorkerProfileBody(detail: snapshot.data!),
          );
        },
      ),
    );
  }
}

class _WorkerProfileBody extends StatelessWidget {
  const _WorkerProfileBody({required this.detail});

  final AdminWorkerProfileDetail detail;

  @override
  Widget build(BuildContext context) {
    final worker = detail.worker;
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 116),
      children: [
        _InfoCard(
          title: worker.name,
          rows: [
            _InfoRow('Ref', worker.id),
            _InfoRow('Telefon', worker.phone),
            _InfoRow('Daraja', worker.level),
            _InfoRow('Code', worker.code),
          ],
        ),
        _WorkerGroupsCard(groups: detail.assignedGroups),
        _ActiveSessionsCard(sessions: detail.activeSessions),
        _ProgressBatchesCard(batches: detail.recentBatches),
        _RecentLogsCard(logs: detail.recentLogs),
      ],
    );
  }
}

class _WorkerGroupsCard extends StatelessWidget {
  const _WorkerGroupsCard({required this.groups});

  final List<AdminWorkerGroup> groups;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const _InfoCard(
        title: 'Assign qilingan guruhlar',
        rows: [_InfoRow('Holat', 'Assign yo‘q')],
      );
    }
    return _InfoCard(
      title: 'Assign qilingan guruhlar',
      rows: [
        for (final group in groups)
          _InfoRow(
            group.apparatus,
            [
              group.groupCode,
              group.shift,
              '${group.startTime}-${group.endTime}',
              '${group.workDaysPerWeek} kun',
            ].where((item) => item.trim().isNotEmpty).join(' • '),
          ),
      ],
    );
  }
}

class _ActiveSessionsCard extends StatelessWidget {
  const _ActiveSessionsCard({required this.sessions});

  final List<AdminWorkerRunSession> sessions;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const _InfoCard(
        title: 'Aktiv ishlar',
        rows: [_InfoRow('Holat', 'Aktiv ish yo‘q')],
      );
    }
    return _InfoCard(
      title: 'Aktiv ishlar',
      rows: [
        for (final session in sessions)
          _InfoRow(
            session.apparatus,
            '${session.orderId} • ${session.status}',
          ),
      ],
    );
  }
}

class _ProgressBatchesCard extends StatelessWidget {
  const _ProgressBatchesCard({required this.batches});

  final List<AdminProgressBatch> batches;

  @override
  Widget build(BuildContext context) {
    if (batches.isEmpty) {
      return const _InfoCard(
        title: 'Progress batchlar',
        rows: [_InfoRow('Holat', 'Batch yo‘q')],
      );
    }
    return _InfoCard(
      title: 'Progress batchlar',
      rows: [
        for (final batch in batches)
          _InfoRow(
            batch.orderId,
            [
              batch.apparatus,
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
  const _RecentLogsCard({required this.logs});

  final List<AdminProductionOrderLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const _InfoCard(
        title: 'Loglar',
        rows: [_InfoRow('Holat', 'Log yo‘q')],
      );
    }
    return _InfoCard(
      title: 'Loglar',
      rows: [
        for (final log in logs)
          _InfoRow(
            '${_actionLabel(log.action)} • ${log.apparatus}',
            [
              log.orderId,
              '${log.fromState} → ${log.toState}',
              if (log.completedWithIssue) 'Muammo bilan yopilgan',
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
    final value = row.value.trim().isEmpty ? 'Kiritilmagan' : row.value.trim();
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
        child: const Text('Qayta yuklash'),
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;
}

String _actionLabel(String action) {
  return switch (action.trim()) {
    'start' => 'Boshladi',
    'pause' => 'Pauza',
    'resume' => 'Davom etdi',
    'complete' => 'Tugatdi',
    final value when value.isNotEmpty => value,
    _ => 'Harakat',
  };
}

String _formatNumber(double value) => formatQuantity(value);
