import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../models/raw_material_split_models.dart';

String _rawSplitTitle(RawSplitResult result) =>
    '${rawSplitDisplay(result.sourceKg)} → ${rawSplitDisplay(result.outputKg)} kg';

String _rawSplitSubtitle(RawSplitResult result) {
  final parts = <String>[
    if (result.source.warehouse.trim().isNotEmpty)
      result.source.warehouse.trim(),
    '${result.outputs.length} rulon',
    '${rawSplitDisplay(result.wasteKg)} kg chiqindi',
  ];
  return parts.join(' • ');
}

String _rawSplitTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return '';
  }
  DateTime? time;
  try {
    time = DateTime.parse(raw.trim()).toLocal();
  } catch (_) {
    return raw.trim();
  }
  final now = DateTime.now();
  final clock =
      '${_two(time.hour)}:${_two(time.minute)}';
  if (time.year == now.year &&
      time.month == now.month &&
      time.day == now.day) {
    return clock;
  }
  return '${_two(time.day)}.${_two(time.month)} $clock';
}

String _two(int value) => value.toString().padLeft(2, '0');

/// Tarix ro'yxatidagi bitta bo'lish kartochkasi.
///
/// Material ta'minotchisi tarixi (`_MaterialHistoryCard`) bilan bir xil
/// M3 segment uslubi: icon + title + subtitle + vaqt + chevron.
class RawSplitHistoryCard extends StatelessWidget {
  const RawSplitHistoryCard({
    required this.slot,
    required this.result,
    required this.onTap,
    super.key,
  });

  final M3SegmentVerticalSlot slot;
  final RawSplitResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final backgroundColor = theme.brightness == Brightness.dark
        ? AppTheme.actionSurface(context)
        : scheme.surfaceContainerLowest;
    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: slot == M3SegmentVerticalSlot.middle
          ? M3SegmentedListGeometry.cornerMiddle
          : M3SegmentedListGeometry.cornerLarge,
      backgroundColor: backgroundColor,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.content_cut,
              size: 22,
              color: scheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _rawSplitTitle(result),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _rawSplitSubtitle(result),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _rawSplitTime(result.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Muammo kartochkasi — tarix kartochkasi bilan bir xil uslubda.
class RawSplitIssueCard extends StatelessWidget {
  const RawSplitIssueCard({
    required this.slot,
    required this.issue,
    required this.hasResult,
    required this.onTap,
    super.key,
  });

  final M3SegmentVerticalSlot slot;
  final RawSplitIssue issue;
  final bool hasResult;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final backgroundColor = theme.brightness == Brightness.dark
        ? AppTheme.actionSurface(context)
        : scheme.surfaceContainerLowest;
    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: slot == M3SegmentVerticalSlot.middle
          ? M3SegmentedListGeometry.cornerMiddle
          : M3SegmentedListGeometry.cornerLarge,
      backgroundColor: backgroundColor,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 22,
              color: scheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    issue.source.itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    issue.check.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_two(issue.createdAt.toLocal().day)}.'
                  '${_two(issue.createdAt.toLocal().month)} '
                  '${_two(issue.createdAt.toLocal().hour)}:'
                  '${_two(issue.createdAt.toLocal().minute)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bo'lish tafsilotlari pastki varag'i.
///
/// Material tarixi tafsilotlar varag'i bilan bir xil tuzilma; ichida
/// har bir rulon uchun alohida qayta chop etish va barchasini qayta
/// chop etish amallari bor.
class RawSplitDetailsSheet extends StatefulWidget {
  const RawSplitDetailsSheet({
    required this.result,
    required this.printerLabel,
    required this.showWifiSelector,
    required this.wifiPrinter,
    required this.onReprint,
    required this.onReprintAll,
    required this.onSelectPrinter,
    required this.onWifiChanged,
    super.key,
  });

  final RawSplitResult result;
  final String? printerLabel;
  final bool showWifiSelector;
  final String wifiPrinter;
  final ValueChanged<RawSplitRoll> onReprint;
  final VoidCallback onReprintAll;
  final VoidCallback onSelectPrinter;
  final ValueChanged<String> onWifiChanged;

  @override
  State<RawSplitDetailsSheet> createState() => _RawSplitDetailsSheetState();
}

class _RawSplitDetailsSheetState extends State<RawSplitDetailsSheet> {
  late String _wifi = widget.wifiPrinter;
  bool _printing = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final result = widget.result;
    return Material(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewPaddingOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.content_cut,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _rawSplitTitle(result),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _rawSplitSubtitle(result),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _RawSplitDetailLine(
              label: 'Manba QR',
              value: result.source.barcode,
            ),
            _RawSplitDetailLine(
              label: 'Ombor',
              value: result.source.warehouse,
            ),
            if (result.createdAt != null)
              _RawSplitDetailLine(
                label: 'Vaqti',
                value: result.createdAt!,
              ),
            if (result.issueId != null) ...[
              _RawSplitDetailLine(
                label: 'Farq',
                value: result.differenceLabel,
              ),
              _RawSplitDetailLine(
                label: 'Sabab',
                value: result.issueNote ?? '',
              ),
            ],
            const SizedBox(height: 8),
            for (final output in result.outputs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${rawSplitDisplay(output.kg)} kg · '
                            '${rawSplitDisplay(output.widthMm)} mm · '
                            '${rawSplitDisplay(output.micron)} mkm'
                            '${output.lengthM != null && output.lengthM!.isNotEmpty ? ' · ${rawSplitDisplay(output.lengthM!)} m' : ''}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(output.labelName),
                          if (output.grossKg != null)
                            Text('Brutto: ${rawSplitDisplay(output.grossKg!)} kg · '
                                'Babina: ${rawSplitDisplay(output.bobinaKg!)} kg'),
                          if (output.lengthM != null &&
                              output.lengthM!.isNotEmpty)
                            Text('Metri: ${rawSplitDisplay(output.lengthM!)} m'),
                          SelectableText(output.barcode),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Shu rulonni qayta chop etish',
                      onPressed: _printing
                          ? null
                          : () => _run(() async =>
                              widget.onReprint(output)),
                      icon: const Icon(Icons.print_outlined),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            if (widget.printerLabel == null)
              OutlinedButton.icon(
                onPressed: _printing ? null : widget.onSelectPrinter,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Printer tanlash'),
              )
            else
              Row(
                children: [
                  const Icon(Icons.print_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Printer: ${widget.printerLabel}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (widget.showWifiSelector)
                    DropdownButton<String>(
                      value: _wifi,
                      onChanged: _printing
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() => _wifi = value);
                              widget.onWifiChanged(value);
                            },
                      items: const [
                        DropdownMenuItem(
                            value: 'godex', child: Text('GoDEX')),
                        DropdownMenuItem(
                            value: 'zebra', child: Text('Zebra')),
                      ],
                    ),
                ],
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  _printing ? null : () => _run(() async => widget.onReprintAll()),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Barchasini qayta chop etish'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Muammo tafsilotlari pastki varag'i — bir xil uslubda.
class RawSplitIssueDetailsSheet extends StatelessWidget {
  const RawSplitIssueDetailsSheet({
    required this.issue,
    required this.hasResult,
    super.key,
  });

  final RawSplitIssue issue;
  final bool hasResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewPaddingOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.source.itemName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        issue.check.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _RawSplitDetailLine(
              label: 'QR',
              value: issue.source.barcode,
            ),
            _RawSplitDetailLine(
              label: 'Asl',
              value: '${rawSplitDisplay(issue.source.kg)} kg · '
                  'Atxot: ${issue.enteredWaste.isEmpty ? 'kiritilmagan' : issue.enteredWaste} kg',
            ),
            for (var i = 0; i < issue.outputs.length; i++)
              _RawSplitDetailLine(
                label: '${i + 1}-rulon',
                value:
                    '${rawSplitDisplay(issue.outputs[i]['width_mm'] as String)} mm · '
                    'Og‘irlik: ${rawSplitDisplay(issue.outputs[i]['gross_kg'] as String)} kg · '
                    'Babina: ${rawSplitDisplay(issue.outputs[i]['bobina_kg'] as String)} kg · '
                    'Netto: ${rawSplitDisplay(issue.outputs[i]['kg'] as String)} kg',
              ),
            const SizedBox(height: 8),
            Text('Sabab: ${issue.note}'),
            Text('${issue.actorName} · ${issue.createdAt.toLocal()}',
                style: theme.textTheme.bodySmall),
            Text(hasResult
                ? 'Muammo bo‘yicha rulonlar saqlangan.'
                : 'Muammo sababi qayd etilgan.'),
          ],
        ),
      ),
    );
  }
}

class _RawSplitDetailLine extends StatelessWidget {
  const _RawSplitDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Yuklanish holati — material tarixi bilan bir xil.
class RawSplitHistoryLoading extends StatelessWidget {
  const RawSplitHistoryLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// Bo'sh/xato holati xabari — material tarixi bilan bir xil.
class RawSplitHistoryMessage extends StatelessWidget {
  const RawSplitHistoryMessage({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return M3SegmentFilledSurface(
      slot: M3SegmentVerticalSlot.top,
      cornerRadius: M3SegmentedListGeometry.cornerLarge,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.actionSurface(context)
          : scheme.surfaceContainerLowest,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  if (subtitle?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!.trim(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
