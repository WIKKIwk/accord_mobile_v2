import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/formatters/date_time_formatters.dart';
import '../../../../core/formatters/quantity_formatters.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../models/app_models.dart';
import '../../../admin/logic/canonical_apparatus_display.dart';

class WorkerWipDetails extends StatelessWidget {
  const WorkerWipDetails({
    super.key,
    required this.batch,
    required this.apparatusCatalog,
    this.statusLabel,
    this.viewer,
  });

  final AdminProgressBatch batch;
  final List<AdminApparatus> apparatusCatalog;
  final String? statusLabel;
  final SessionProfile? viewer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final missing = l10n.productionText('worker.paddon.bobina_unknown');
    final rawGross = batch.payloadJson['gross_qty'];
    // Use the same measured gross and unknown-tare semantics as the backend.
    final gross = _weightUnits(rawGross == null
        ? batch.finishedGoodsKg
        : rawGross is num
            ? rawGross.toDouble()
            : null);
    final bobina = _weightUnits(batch.bobinaKg);
    final net = gross != null && gross > 0 && bobina != null && bobina <= gross
        ? gross - bobina
        : null;
    String weight(int? units) =>
        units == null ? missing : _quantity(units / 1000000, 'kg');
    final source = _apparatusName([batch.apparatus]);
    final current = _apparatusName([
      batch.currentApparatus,
      batch.currentLocation,
    ]);
    final hasQuantity = batch.producedQty.isFinite &&
        batch.producedQty > 0 &&
        batch.uom.trim().isNotEmpty;
    final lengthM = batch.finishedGoodsMeter;
    final hasLength = lengthM != null && lengthM.isFinite && lengthM > 0;
    final metadata = <(String, String)>[
      (
        l10n.productionText('worker.wip.info.quantity'),
        hasQuantity
            ? _quantity(batch.producedQty, batch.uom)
            : hasLength
                ? _quantity(lengthM, 'm')
                : missing,
      ),
      if (hasLength &&
          hasQuantity &&
          (batch.uom.trim().toLowerCase() != 'm' ||
              batch.finishedGoodsMeter != batch.producedQty))
        (
          l10n.productionText('worker.daily.field.length'),
          _quantity(lengthM, 'm'),
        ),
      (
        l10n.productionText('worker.wip.info.gross_weight'),
        weight(gross != null && gross > 0 ? gross : null),
      ),
      (l10n.productionText('worker.wip.info.net_weight'), weight(net)),
      (l10n.productionText('worker.qr.passport.bobbin_weight'), weight(bobina)),
      (l10n.productionText('worker.wip.info.produced_by'), _producerName(l10n)),
      (
        l10n.productionText('worker.daily.status'),
        statusLabel ?? statusLabelFor(batch, l10n)
      ),
      (
        l10n.productionText('worker.wip.info.source'),
        source.isEmpty
            ? l10n.productionText('worker.qr.history.machine_missing')
            : source,
      ),
      if (current.isNotEmpty && current != source)
        (l10n.productionText('worker.wip.info.location'), current),
      if (_apparatusName([batch.nextApparatus]).isNotEmpty)
        (
          l10n.productionText('worker.wip.info.next_machine'),
          _apparatusName([batch.nextApparatus]),
        ),
      if (batch.completedAtUnix > 0)
        (
          l10n.productionText('worker.wip.info.finished'),
          formatUnixSecondsLocalDateTime(batch.completedAtUnix),
        ),
      if (batch.completedAtUnix <= 0 && batch.startedAtUnix > 0)
        (
          l10n.productionText('worker.wip.info.started'),
          formatUnixSecondsLocalDateTime(batch.startedAtUnix),
        ),
      if (batch.diameter != null &&
          batch.diameter!.isFinite &&
          batch.diameter! > 0)
        (
          l10n.productionText('worker.qr.passport.diameter'),
          _quantity(batch.diameter!, ''),
        ),
      if (batch.description.trim().isNotEmpty)
        (l10n.productionText('worker.wip.info.note'), batch.description.trim()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final detail in metadata)
          _WipDetailLine(label: detail.$1, value: detail.$2),
        _WipDetailLine(
          label: l10n.productionText('worker.wip.info.epc'),
          value: _readableEpc(batch.qrPayload),
          selectable: true,
        ),
      ],
    );
  }

  static String statusLabelFor(
      AdminProgressBatch batch, AppLocalizations l10n) {
    final flow = batch.statusDetail.flowStatus.trim();
    final flowKey = switch (flow) {
      'free_wip' => 'worker.wip.status.free',
      'accepted_to_stock' => 'worker.wip.status.accepted',
      'waiting_next_stage' => 'worker.wip.status.waiting_next',
      'consumed_by_next_stage' => 'worker.wip.status.consumed_next',
      'in_progress' => 'worker.wip.status.in_progress',
      _ => '',
    };
    if (flowKey.isNotEmpty) return l10n.productionText(flowKey);
    return l10n.productionText(switch (batch.wipStatus.trim()) {
      'waiting' => 'worker.wip.status.waiting',
      'in_use' => 'worker.wip.status.in_progress',
      'processed' => 'worker.wip.status.used',
      _ => switch (batch.statusDetail.workStatus.trim().isNotEmpty
            ? batch.statusDetail.workStatus.trim()
            : batch.status.trim()) {
          'paused' => 'worker.wip.status.paused',
          'resumed' || 'in_progress' => 'worker.wip.status.in_progress',
          'completed' || 'complete' => 'worker.wip.status.finished',
          _ => 'worker.daily.wip',
        },
    });
  }

  String _apparatusName(Iterable<String> candidates) {
    for (final candidate in candidates) {
      final label = canonicalApparatusDisplayLabel(candidate, apparatusCatalog);
      if (label.trim().isNotEmpty && !label.contains('apparatus:')) {
        return label.trim();
      }
    }
    return '';
  }

  String _producerName(AppLocalizations l10n) {
    final workerRef = batch.workerRef.trim();
    final candidates = [
      batch.workerDisplayName,
      batch.executorName,
      if (workerRef.isNotEmpty && viewer?.ref.trim() == workerRef)
        viewer!.displayName,
    ];
    for (final candidate in candidates) {
      final name = candidate.trim();
      if (name.isEmpty || name == workerRef) continue;
      if (RegExp(r'^(?:worker|user|system-user)[_:=-]', caseSensitive: false)
              .hasMatch(name) ||
          RegExp(r'^(?:worker|user)\S*\d{6,}\S*$', caseSensitive: false)
              .hasMatch(name) ||
          RegExp(r'^[0-9a-f]{24,}$', caseSensitive: false).hasMatch(name) ||
          RegExp(r'^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
                  caseSensitive: false)
              .hasMatch(name)) {
        continue;
      }
      return name;
    }
    return l10n.productionText('worker.qr.history.worker_missing');
  }
}

int? _weightUnits(double? value) {
  if (value == null || !value.isFinite || value < 0 || value >= 1e12) {
    return null;
  }
  return (value * 1000000).round();
}

String _quantity(double value, String unit) {
  final parts = formatQuantity(value, decimalPlaces: 3, trimTrailingZeros: true)
      .split('.');
  parts[0] = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (match) => '${match[1]} ',
  );
  return [parts.join('.'), if (unit.trim().isNotEmpty) unit.trim()].join(' ');
}

String _readableEpc(String value) {
  final code = value.trim();
  if (code.isEmpty) return '—';
  if (!RegExp(r'^[0-9a-f]{24}$', caseSensitive: false).hasMatch(code)) {
    return code;
  }
  return [
    for (var index = 0; index < code.length; index += 4)
      code.substring(index, index + 4).toUpperCase(),
  ].join(' ');
}

class _WipDetailLine extends StatelessWidget {
  const _WipDetailLine({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: selectable
                ? SelectableText(
                    value,
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  )
                : Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
