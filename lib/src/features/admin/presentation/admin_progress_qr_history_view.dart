import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import 'admin_progress_qr_passport.dart';

/// A roll's proven manufacturing occurrences. Numbers identify actual outputs,
/// including repeated apparatus visits; link rows describe branches explicitly.
class AdminProgressQrHistoryView extends StatelessWidget {
  const AdminProgressQrHistoryView({
    super.key,
    required this.report,
    required this.apparatusNamesById,
    required this.onScanAgain,
    required this.onShare,
    required this.sharing,
  });

  final AdminProgressQrReport report;
  final Map<String, String> apparatusNamesById;
  final VoidCallback onScanAgain;
  final VoidCallback onShare;
  final bool sharing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    String text(String key) => l10n.productionText(key);
    final passport = buildProgressQrPassport(report,
        l10n: l10n, apparatusNamesById: apparatusNamesById);
    final qr = report.scannedBatch.qrPayload.trim();
    final showQr = qr.isNotEmpty &&
        qr != report.scannedBatch.batchId.trim() &&
        !qr.contains('progress-batch:') &&
        !qr.contains('apparatus:');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Card.filled(
          color: scheme.surfaceContainerLowest,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    passport.productName.isEmpty
                        ? text('worker.qr.report.product')
                        : passport.productName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 6),
                Text(
                    [
                      if (passport.orderNumber.isNotEmpty)
                        '${text('worker.qr.report.order')} ${passport.orderNumber}',
                      passport.orderStatus,
                    ].join(' • '),
                    key: const ValueKey('qr-passport-order-status')),
                const SizedBox(height: 12),
                Text(
                    '${text('worker.qr.passport.scanned_batch')}: ${passport.scannedBatchStatus}',
                    key: const ValueKey('qr-passport-scanned-batch-status')),
                if (showQr) ...[
                  const SizedBox(height: 6),
                  Text('${text('worker.qr.report.epc')}: $qr',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      )),
                ],
                if (passport.currentBatchStatus case final status?) ...[
                  const SizedBox(height: 6),
                  Text('${text('worker.qr.passport.current_batch')}: $status',
                      key: const ValueKey('qr-passport-current-batch-status')),
                ],
                if (report.hasScopedHistory &&
                    report.currentBatches.length > 1) ...[
                  const SizedBox(height: 6),
                  Text(l10n.productionText('worker.qr.history.outputs',
                      values: {'count': report.currentBatches.length})),
                ],
                if (passport.isOldQr) ...[
                  const SizedBox(height: 10),
                  Text(text('worker.qr.history.old_qr_notice'),
                      style: theme.textTheme.bodySmall),
                ],
                if (passport.historyNotice.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(passport.historyNotice,
                      key: const ValueKey('qr-history-notice'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      )),
                ],
                if (passport.plan.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: Text(text('worker.qr.report.share_plan')),
                    children: [
                      for (final line in passport.plan)
                        _HistoryFact(label: line.label, value: line.value),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card.filled(
          key: const ValueKey('qr-history-timeline'),
          color: scheme.surfaceContainerLowest,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text('worker.qr.history.title'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 20),
                for (final line in passport.resourceLines)
                  _HistoryFact(label: line.label, value: line.value),
                if (passport.resourceLines.isNotEmpty)
                  const Divider(height: 32),
                for (var index = 0;
                    index < passport.stages.length;
                    index++) ...[
                  if (index > 0) const Divider(height: 32),
                  _HistoryOccurrence(
                      stage: passport.stages[index], index: index + 1),
                ],
                if (passport.corrections.isNotEmpty) ...[
                  const Divider(height: 32),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    title: Text(text('worker.qr.report.corrections')),
                    children: [
                      for (final correction in passport.corrections)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(correction.stage,
                                  style: theme.textTheme.titleSmall),
                              Text('${correction.editor} • ${correction.time}'),
                              Text(correction.reason),
                              for (final change in correction.changes)
                                _HistoryFact(
                                    label: change.label,
                                    stacked: true,
                                    value:
                                        '${change.before} → ${change.after}'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
                if (passport.issues.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text(text('worker.qr.report.issues'),
                      style: theme.textTheme.titleMedium),
                  for (final issue in passport.issues)
                    _HistoryFact(
                        label: issue.title,
                        value: [issue.description, issue.time]
                            .where((value) => value.isNotEmpty)
                            .join(' • ')),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: sharing ? null : onShare,
          icon: sharing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.ios_share_rounded),
          label: Text(text(sharing
              ? 'worker.scanner.pdf_preparing'
              : 'worker.scanner.share_pdf')),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
            onPressed: onScanAgain,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: Text(text('worker.scanner.scan_again'))),
      ],
    );
  }
}

class _HistoryOccurrence extends StatelessWidget {
  const _HistoryOccurrence({required this.stage, required this.index});
  final ProgressQrPassportStage stage;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final workerLabel = l10n.productionText('worker.wip.info.worker');
    return Column(
      key: ValueKey('qr-history-step-$index'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
              radius: 16,
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: Text('$index')),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(stage.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 4),
                Text(
                    stage.workerNames.isEmpty
                        ? l10n
                            .productionText('worker.qr.history.worker_missing')
                        : stage.workerNames.join(' · '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    )),
              ])),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (stage.isScanned)
            _HistoryBadge(
                text: l10n.productionText('worker.qr.history.scanned')),
          if (stage.isCurrent)
            _HistoryBadge(
                text: l10n.productionText('worker.qr.history.current')),
        ]),
        const SizedBox(height: 8),
        Text(stage.displayStatus,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 8),
        for (final line in stage.lines)
          if (line.label != workerLabel)
            _HistoryFact(label: line.label, value: line.value),
      ],
    );
  }
}

class _HistoryBadge extends StatelessWidget {
  const _HistoryBadge({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                )),
      );
}

class _HistoryFact extends StatelessWidget {
  const _HistoryFact(
      {required this.label, required this.value, this.stacked = false});
  final String label;
  final String value;
  final bool stacked;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: stacked
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              Text(value,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ])
          : Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '$label: ',
                    style:
                        TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                TextSpan(
                    text: value,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
              style: theme.textTheme.bodyMedium),
    );
  }
}
