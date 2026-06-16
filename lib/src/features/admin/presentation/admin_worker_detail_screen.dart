import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';

const double _workerDetailPanelGap = 4;
const double _workerDetailCardRadius = 18;
const double _workerDetailFieldRadius = 14;

class AdminWorkerDetailScreen extends StatelessWidget {
  const AdminWorkerDetailScreen({super.key, required this.entry});

  final AdminUserListEntry entry;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Worker',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      contentPadding: EdgeInsets.zero,
      bottom: const AdminDock(activeTab: AdminDockTab.suppliers),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          _workerDetailPanelGap,
          _workerDetailPanelGap,
          _workerDetailPanelGap,
          116,
        ),
        children: [
          _WorkerDetailCard(entry: entry),
        ],
      ),
    );
  }
}

class _WorkerDetailCard extends StatelessWidget {
  const _WorkerDetailCard({required this.entry});

  final AdminUserListEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_workerDetailCardRadius),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.name,
                    style: theme.textTheme.headlineMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const _WorkerStatusChip(label: 'Tayyor'),
              ],
            ),
            const SizedBox(height: 18),
            const _WorkerDetailLabel('Ref'),
            const SizedBox(height: 6),
            _WorkerDetailField(value: entry.id),
            const SizedBox(height: 14),
            const _WorkerDetailLabel('User ismi'),
            const SizedBox(height: 6),
            _WorkerDetailField(value: entry.name),
            const SizedBox(height: 14),
            const _WorkerDetailLabel('Telefon'),
            const SizedBox(height: 6),
            _WorkerDetailField(value: entry.phone),
            const SizedBox(height: 14),
            const _WorkerDetailLabel('Daraja'),
            const SizedBox(height: 6),
            _WorkerDetailField(value: entry.roleLabel),
          ],
        ),
      ),
    );
  }
}

class _WorkerDetailLabel extends StatelessWidget {
  const _WorkerDetailLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.bodySmall);
  }
}

class _WorkerDetailField extends StatelessWidget {
  const _WorkerDetailField({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final resolved = value.trim().isEmpty ? 'Kiritilmagan' : value.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(_workerDetailFieldRadius),
      ),
      child: Text(
        resolved,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _WorkerStatusChip extends StatelessWidget {
  const _WorkerStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
