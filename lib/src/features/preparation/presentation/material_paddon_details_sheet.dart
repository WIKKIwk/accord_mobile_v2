import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/urdu_aware_text.dart';
import '../../../core/session/session.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../admin/presentation/progress_printer_picker.dart';
import '../../admin/presentation/widgets/admin_catalog_list_row.dart';
import '../../shared/models/app_models.dart';
import '../models/preparation_models.dart';
import 'material_paddon_issue_dialog.dart';
import 'material_paddon_print.dart';

String materialPaddonBalance(PreparationMaterialPaddon paddon) {
  final kg = preparationDisplay(paddon.remainingKg);
  if (paddon.unweighedCount == 0) return 'Qoldiq: $kg kg';
  if (paddon.unweighedCount == paddon.remainingCount) {
    return 'Qoldiq: ${paddon.remainingCount} ta birlik • Vazni tortilmagan';
  }
  return [
    'Qoldiq: ${paddon.remainingCount} ta birlik',
    if (kg != '0') '$kg kg tortilgan',
    '${paddon.unweighedCount} ta tortilmagan',
  ].join(' • ');
}

String? materialPaddonCodeFromQr(String scanned) {
  final value = scanned.trim().toUpperCase();
  final code = value.replaceFirst(RegExp(r'^RAW-MATERIAL-PADDON:'), '');
  return RegExp(r'^XP-[0-9A-F]{16}$').hasMatch(code) ? code : null;
}

Future<void> showMaterialPaddonDetails(
  BuildContext context,
  PreparationMaterialPaddon paddon, {
  required VoidCallback onChanged,
}) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _MaterialPaddonDetailsSheet(paddon, onChanged),
    );

class _MaterialPaddonDetailsSheet extends StatefulWidget {
  const _MaterialPaddonDetailsSheet(this.initialPaddon, this.onChanged);

  final PreparationMaterialPaddon initialPaddon;
  final VoidCallback onChanged;

  @override
  State<_MaterialPaddonDetailsSheet> createState() =>
      _MaterialPaddonDetailsState();
}

class _MaterialPaddonDetailsState extends State<_MaterialPaddonDetailsSheet> {
  final _api = MobileApi.instance;
  final _scope = currentSessionReadScope();
  late var _paddon = widget.initialPaddon;
  late var _pending = _canIssue
      ? _api.pendingMaterialPaddonIssue()
      : Future<PreparationPendingCommand?>.value(null);
  var _busy = false;

  bool get _canIssue {
    final session = AppSession.instance;
    return session.profile?.role == UserRole.tayyorlovMasteri
        ? session.can('preparation.access')
        : session.can('gscale.print');
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: UrduAwareText(text)));
  }

  Future<void> _printParent() async {
    if (_busy || _scope != currentSessionReadScope()) return;
    setState(() => _busy = true);
    try {
      final printer = await pickProgressPrinter(context);
      if (!mounted || printer == null || _scope != currentSessionReadScope()) {
        return;
      }
      await printMaterialPaddonQr(
          printer, materialPaddonPrintRequest(_paddon, printer));
      if (!mounted || _scope != currentSessionReadScope()) return;
      _message('Paddon yorlig‘i chop etildi');
    } catch (_) {
      if (mounted && _scope == currentSessionReadScope()) {
        _message('Paddon yorlig‘i chop etilmadi');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    try {
      final current = await _api.materialPaddonByCode(_paddon.code);
      if (!mounted || _scope != currentSessionReadScope() || current == null) {
        return;
      }
      setState(() => _paddon = current);
    } catch (_) {
      if (mounted && _scope == currentSessionReadScope()) {
        _message('Paddon qoldig‘i yuklanmadi');
      }
    }
  }

  Future<void> _issue() async {
    if (_busy || !_canIssue || _scope != currentSessionReadScope()) return;
    setState(() => _busy = true);
    try {
      final pending = await _api.pendingMaterialPaddonIssue();
      if (!mounted || _scope != currentSessionReadScope()) return;
      final issue = await showMaterialPaddonIssue(context, _paddon, pending);
      if (!mounted || _scope != currentSessionReadScope()) return;
      final nextPending = _api.pendingMaterialPaddonIssue();
      setState(() {
        _pending = nextPending;
      });
      if (issue == null) {
        await _refresh();
        return;
      }
      widget.onChanged();
      unawaited(_refresh());
      if (issue.existingQr) {
        _message('Rulon paddondan yechildi');
      } else {
        await _showIssueLabels(context, issue, printOnOpen: true);
      }
    } catch (error) {
      if (!mounted || _scope != currentSessionReadScope()) return;
      _message(error is MobileApiException
          ? error.message
          : 'Chiqimni ochib bo‘lmadi');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showHistory() {
    if (_busy || _scope != currentSessionReadScope()) return;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _MaterialPaddonIssueHistory(_paddon.code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        children: [
          UrduAwareText(_paddon.title, style: textTheme.titleLarge),
          const SizedBox(height: 12),
          _PaddonOverview(_paddon),
          const SizedBox(height: 16),
          if (_canIssue)
            FutureBuilder<PreparationPendingCommand?>(
              future: _pending,
              builder: (context, snapshot) {
                final recover = snapshot.data?.payload['code'] == _paddon.code;
                final hasUnits = _paddon.contents.any(
                  (item) => item.lineNo != null && item.availableCount > 0,
                );
                if (!hasUnits && !recover) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FilledButton.icon(
                    key: const ValueKey('paddon-open-issue'),
                    onPressed: _busy ? null : _issue,
                    icon: const Icon(Icons.outbox_outlined),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    label: UrduAwareText(
                      recover
                          ? 'Chiqim natijasini tekshirish'
                          : 'Paddondan yechib olish',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          OutlinedButton.icon(
            key: const ValueKey('paddon-print-qr'),
            onPressed: _busy ? null : _printParent,
            icon: const Icon(Icons.print_outlined),
            label: const UrduAwareText('Paddon QR chiqarish'),
          ),
          if (_paddon.contents.isNotEmpty) ...[
            const SizedBox(height: 20),
            UrduAwareText('Xomashyo', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final (index, item) in _paddon.contents.indexed) ...[
              if (index > 0)
                const SizedBox(height: M3SegmentedListGeometry.gap),
              _PaddonContentRow(
                item,
                slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                  index,
                  _paddon.contents.length,
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          TextButton.icon(
            key: const ValueKey('paddon-issue-history'),
            onPressed: _busy ? null : _showHistory,
            icon: const Icon(Icons.history_rounded),
            label: const UrduAwareText('Chiqimlar va yorliqlar'),
          ),
        ],
      ),
    );
  }
}

class _PaddonOverview extends StatelessWidget {
  const _PaddonOverview(this.paddon);

  final PreparationMaterialPaddon paddon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final qr = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: QrImageView(
        data: paddon.qrPayload,
        size: 144,
        backgroundColor: Colors.white,
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        UrduAwareText(
          materialPaddonBalance(paddon),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        UrduAwareText(
          paddon.warehouse,
          style: theme.textTheme.bodyMedium,
        ),
        if (paddon.name.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            paddon.code,
            textDirection: TextDirection.ltr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 288;
            return Flex(
              direction: horizontal ? Axis.horizontal : Axis.vertical,
              mainAxisSize: MainAxisSize.min,
              children: [
                qr,
                const SizedBox(width: 14, height: 12),
                if (horizontal) Expanded(child: details) else details,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PaddonContentRow extends StatelessWidget {
  const _PaddonContentRow(this.item, {required this.slot});

  final PreparationPaddonContent item;
  final M3SegmentVerticalSlot slot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final specifications = [
      if (item.preparedBarcode case final barcode?) barcode,
      if (item.lotNumber.isNotEmpty) 'Partiya: ${item.lotNumber}',
      if (item.widthMm case final width?) '${preparationDisplay(width)} mm',
      if (item.micron case final micron?) '${preparationDisplay(micron)} mkm',
    ];
    final count = item.remainingCount;
    final stock = [
      if (item.openUnitNo case final number?) 'Ochilgan ${item.unit} №$number',
      if (count != null) '$count ta ${item.unit}',
      if (item.openUnitNo == null && item.unitKg != null)
        '${preparationDisplay(item.unitKg!)} kg dan',
      if (count != null && item.availableCount < count)
        'Band: ${count - item.availableCount} ta',
    ];
    final balance = item.unweighedCount > 0
        ? 'Vazni tortilmagan'
        : 'Jami ${preparationDisplay(item.remainingKg)} kg';
    return AdminCatalogListRow(
      slot: slot,
      icon: Icons.category_outlined,
      title: l10n.uiText(item.itemName),
      titleMaxLines: 2,
      subtitle: [
        if (specifications.isNotEmpty) l10n.uiText(specifications.join(' • ')),
        if (stock.isNotEmpty) l10n.uiText(stock.join(' • ')),
      ].join('\n'),
      subtitleMaxLines: 8,
      value: l10n.uiText(balance),
    );
  }
}

class _MaterialPaddonIssueHistory extends StatefulWidget {
  const _MaterialPaddonIssueHistory(this.code);

  final String code;

  @override
  State<_MaterialPaddonIssueHistory> createState() =>
      _MaterialPaddonIssueHistoryState();
}

class _MaterialPaddonIssueHistoryState
    extends State<_MaterialPaddonIssueHistory> {
  final _scope = currentSessionReadScope();
  late var _history = MobileApi.instance.materialPaddonIssues(widget.code);

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: FutureBuilder<List<PreparationPaddonIssue>>(
          future: _history,
          builder: (context, snapshot) => ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: UrduAwareText('Chiqimlar va yorliqlar',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              if (snapshot.connectionState != ConnectionState.done)
                const Center(child: AppLoadingIndicator())
              else if (snapshot.hasError)
                TextButton.icon(
                  onPressed: () {
                    if (_scope != currentSessionReadScope()) return;
                    final next =
                        MobileApi.instance.materialPaddonIssues(widget.code);
                    setState(() {
                      _history = next;
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const UrduAwareText(
                      'Chiqimlar yuklanmadi. Qayta urinish'),
                )
              else if (snapshot.data?.isEmpty ?? true)
                const ListTile(title: UrduAwareText('Hali chiqim yo‘q'))
              else
                for (final issue in snapshot.data!)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: UrduAwareText(issue.destinationTitle),
                    subtitle: UrduAwareText(
                        '${issue.labels.first.itemName} • ${_issueQuantity(issue)}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      if (_scope != currentSessionReadScope()) return;
                      await _showIssueLabels(context, issue);
                      if (!mounted || _scope != currentSessionReadScope()) {
                        return;
                      }
                      final next =
                          MobileApi.instance.materialPaddonIssues(widget.code);
                      setState(() {
                        _history = next;
                      });
                    },
                  ),
            ],
          ),
        ),
      );
}

Future<void> _showIssueLabels(
  BuildContext context,
  PreparationPaddonIssue issue, {
  bool printOnOpen = false,
}) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _PaddonIssueLabels(issue, printOnOpen),
    );

class _PaddonIssueLabels extends StatefulWidget {
  const _PaddonIssueLabels(this.issue, this.printOnOpen);

  final PreparationPaddonIssue issue;
  final bool printOnOpen;

  @override
  State<_PaddonIssueLabels> createState() => _PaddonIssueLabelsState();
}

String _issueQuantity(PreparationPaddonIssue issue) {
  final total = issue.labels.fold(
    BigInt.zero,
    (sum, label) => sum + preparationDecimal(label.kg),
  );
  return '${issue.labels.length} ta birlik • ${preparationDisplay(preparationDecimalText(total))} kg';
}

class _PaddonIssueLabelsState extends State<_PaddonIssueLabels> {
  final _scope = currentSessionReadScope();
  final _api = MobileApi.instance;
  late Map<String, PreparationPaddonPrintState> _states;
  bool _busy = false;
  bool _ready = false;
  String? _failure;
  bool get _current => mounted && _scope == currentSessionReadScope();
  List<PreparationPaddonLabel> get _pending => widget.issue.labels
      .where((label) =>
          !widget.issue.legacyPrint && !_states.containsKey(label.barcode))
      .toList();

  @override
  void initState() {
    super.initState();
    _states = Map.of(widget.issue.printStates);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool refresh = false}) async {
    if (!_current) return;
    try {
      var states = widget.issue.printStates;
      if (!widget.issue.tracksPrint) {
        states = await _api.localPaddonPrintStates(widget.issue.id);
      } else if (refresh) {
        final issues = await _api.materialPaddonIssues(widget.issue.paddonCode);
        states = issues.firstWhere((i) => i.id == widget.issue.id).printStates;
      }
      if (!_current) return;
      setState(() {
        _states = Map.of(states);
        _ready = true;
      });
      if (!refresh && widget.printOnOpen && _pending.isNotEmpty) {
        await _print(_pending);
      }
    } catch (_) {
      if (_current) {
        setState(() {
          _ready = false;
          _failure = 'Yorliqlar holatini yangilang';
        });
      }
    }
  }

  Future<void> _confirm(PreparationPaddonLabel label) async {
    if (!_current || _busy) return;
    setState(() => _busy = true);
    try {
      final state = await _api.trackPaddonLabel(widget.issue, label.barcode,
          attempt: _states[label.barcode]!.attempt, confirm: true);
      if (_current) {
        setState(() {
          _states[label.barcode] = state;
          _failure = null;
        });
      }
    } catch (_) {
      if (_current) setState(() => _failure = 'Chop tasdig‘ini yangilang');
      await _load(refresh: true);
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _print(List<PreparationPaddonLabel> labels) async {
    if (_busy || !_ready || !_current) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final printer = await pickProgressPrinter(context);
      if (printer == null || !_current) return;
      for (final label in labels) {
        if (!_current) return;
        final barcode = label.barcode;
        final attempt = newPreparationRequestId();
        final started = await _api.trackPaddonLabel(widget.issue, barcode,
            attempt: attempt,
            previous: _states[barcode]?.attempt,
            confirm: false);
        if (!_current) return;
        setState(() => _states[barcode] = started);
        if (started.printed) continue;
        await printMaterialPaddonQr(printer,
            materialPaddonUnitPrintRequest(widget.issue, label, printer));
        // A user may close the sheet while the hardware is replying.
        if (_scope != currentSessionReadScope()) return;
        final done = await _api.trackPaddonLabel(widget.issue, barcode,
            attempt: attempt, confirm: true);
        if (_current) setState(() => _states[barcode] = done);
      }
    } catch (_) {
      if (_current) {
        setState(() => _failure = 'Chop uzildi. Chiqqan yorliqni tekshiring.');
      }
      await _load(refresh: true);
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    final remaining = _pending;
    return SafeArea(
      top: false,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: UrduAwareText('Chiqim yorliqlari',
                style: Theme.of(context).textTheme.titleLarge),
            subtitle: UrduAwareText([
              issue.destinationTitle,
              _issueQuantity(issue),
              if (issue.remainderKg != null)
                'Paddonda qoldi: ${preparationDisplay(issue.remainderKg!)} kg${issue.labels.first.unitNo == null ? '' : ' (№${issue.labels.first.unitNo})'}',
              if (issue.awaitsTransfer) 'Transfer so‘rovi yuborildi',
            ].join(' • ')),
          ),
          if (_failure case final failure?)
            UrduAwareText(failure,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (!_ready && !_busy && _failure != null)
            TextButton(
                onPressed: () => _load(refresh: true),
                child: const UrduAwareText('Holatni yangilash')),
          for (final label in issue.labels)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_states[label.barcode]?.printed == true
                  ? Icons.check_circle_outline_rounded
                  : Icons.qr_code_rounded),
              title: UrduAwareText(
                  '${label.itemName} • ${preparationDisplay(label.kg)} kg'),
              subtitle: UrduAwareText([
                if (label.lotNumber.isNotEmpty) 'Partiya: ${label.lotNumber}',
                label.barcode,
                if (_states[label.barcode]?.printed == true)
                  'Chop etilgan'
                else if (_states.containsKey(label.barcode) ||
                    issue.legacyPrint)
                  'Chop holatini tekshiring',
              ].join(' • ')),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_states[label.barcode]?.printed == false)
                  IconButton(
                      tooltip: 'Yorliq chiqqanini tasdiqlash',
                      icon: const Icon(Icons.check_rounded),
                      onPressed:
                          _busy || !_ready ? null : () => _confirm(label)),
                IconButton(
                  key: ValueKey('paddon-print-unit:${label.barcode}'),
                  onPressed: _busy || !_ready ? null : () => _print([label]),
                  tooltip:
                      _states.containsKey(label.barcode) || issue.legacyPrint
                          ? 'Yorliqni qayta chiqarish'
                          : 'Yorliq chiqarish',
                  icon: const Icon(Icons.print_outlined),
                ),
              ]),
            ),
          if (_busy) const LinearProgressIndicator(),
          if (_ready && remaining.isNotEmpty)
            FilledButton.icon(
              onPressed: _busy ? null : () => _print(remaining),
              icon: const Icon(Icons.print_outlined),
              label: UrduAwareText('${remaining.length} ta yorliq chiqarish'),
            ),
        ],
      ),
    );
  }
}
