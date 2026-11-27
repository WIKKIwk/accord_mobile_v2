import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/session/session.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_action_button_styles.dart';
import '../../../core/widgets/display/app_metric_tile.dart';
import '../../../core/widgets/display/app_status_chip.dart';
import '../../../core/widgets/lists/app_segment_surface_card.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/raw_material_scan_dialog.dart';
import 'waste_bin_details.dart';

class WasteOperatorAction extends StatelessWidget {
  const WasteOperatorAction({
    super.key,
    this.apparatusId,
    this.apparatusName,
    this.orderId,
  });

  final String? apparatusId, apparatusName, orderId;

  @override
  Widget build(BuildContext context) {
    final profile = AppSession.instance.profile;
    final assigned = profile?.assignedApparatus ?? const [];
    if (assigned.isEmpty ||
        (apparatusId != null && !assigned.contains(apparatusId))) {
      return const SizedBox.shrink();
    }
    String labelFor(String id) {
      final labels = profile?.assignedApparatusLabels ?? const <String>[];
      final index = assigned.indexOf(id);
      return labels.length == assigned.length && index >= 0
          ? labels[index]
          : id;
    }

    return IconButton(
      icon: const Icon(Icons.recycling),
      tooltip: 'Chiqindi qutisi',
      onPressed: () async {
        final scope = currentSessionReadScope();
        final String? id;
        if (apparatusId != null) {
          id = apparatusId;
        } else if (assigned.length == 1) {
          id = assigned.single;
        } else {
          id = await showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            builder: (_) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  const ListTile(title: Text('Apparatni tanlang')),
                  for (final id in assigned)
                    ListTile(
                      title: Text(labelFor(id)),
                      onTap: () => Navigator.pop(context, id),
                    ),
                ],
              ),
            ),
          );
        }
        final selectedId = id;
        if (!context.mounted ||
            selectedId == null ||
            scope != currentSessionReadScope()) {
          return;
        }
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => WasteOperatorScreen(
              apparatusId: selectedId,
              apparatusName: apparatusName ?? labelFor(selectedId),
              orderId: orderId,
            ),
          ),
        );
      },
    );
  }
}

class WasteOperatorScreen extends StatefulWidget {
  const WasteOperatorScreen({
    super.key,
    required this.apparatusId,
    required this.apparatusName,
    this.orderId,
  });

  final String apparatusId, apparatusName;
  final String? orderId;

  @override
  State<WasteOperatorScreen> createState() => _WasteOperatorScreenState();
}

class _WasteOperatorScreenState extends State<WasteOperatorScreen> {
  final _api = MobileApi.instance;
  final _scope = currentSessionReadScope();
  WasteActiveBins? _snapshot;
  String? _error;
  bool _busy = false;

  bool get _current => mounted && currentSessionReadScope() == _scope;

  @override
  void initState() {
    super.initState();
    _run(_refresh);
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool claimingBin = false,
  }) async {
    if (!_current || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!_current) return;
      final message = claimingBin && error is MobileApiException
          ? switch (error.code) {
              'waste_bin_conflict' =>
                'Quti band yoki apparatda boshqa faol quti bor. Ro‘yxatni qayta oching.',
              'waste_bin_forbidden' =>
                'Bu quti ushbu apparatga biriktirilmagan.',
              _ => wasteErrorText(error),
            }
          : wasteErrorText(error);
      setState(() => _error = message);
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    final snapshot = await _api.activeWasteBin(widget.apparatusId);
    if (_current) setState(() => _snapshot = snapshot);
  }

  Future<String?> _pickBin() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EmptyWasteBinPicker(apparatusId: widget.apparatusId),
    );
    if (!mounted || choice != '' || !_current) return choice;
    return showRawMaterialScanDialog(
      context,
      title: 'Bo‘sh chiqindi qutisini skan qiling',
      manualLabel: 'Quti kodi',
      acceptCameraCode: isWasteBinQr,
    );
  }

  Future<void> _assign() async {
    final code = await _pickBin();
    if (!_current || code == null) return;
    await _run(() async {
      await _api.assignWasteBin(code, widget.apparatusId);
      await _refresh();
    }, claimingBin: true);
  }

  Future<void> _submit(WasteBin bin, {required bool replace}) async {
    String? replacement;
    if (replace) {
      replacement = await _pickBin();
      if (!mounted || !_current || replacement == null) return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${bin.label} qutisini topshirish'),
        content: Text(replacement == null
            ? 'Quti qabulga yuboriladi. Keyingi chiqindi uchun bo‘sh quti biriktiring.'
            : 'Quti qabulga yuboriladi va bo‘sh quti apparatga biriktiriladi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Topshirish'),
          ),
        ],
      ),
    );
    if (!_current || confirmed != true) return;
    await _run(() async {
      await _api.submitWasteBin(
        bin: bin,
        apparatusId: widget.apparatusId,
        replacementCode: replacement,
      );
      await _refresh();
    }, claimingBin: replace);
  }

  Future<void> _reconcile(WasteBin bin, List<WasteEntry> pending) async {
    final selected = <String>{};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Qutiga yozuv biriktirish'),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                    'Faqat ${bin.label} qutisiga solingan chiqindilarni belgilang.'),
                for (final entry in pending)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title:
                        Text('${wasteKgLabel(entry.kg)} · ${entry.actorName}'),
                    subtitle: Text([
                      entry.reason,
                      entry.orderId,
                      wasteWhen(context, entry.createdAt),
                    ].where((value) => value.isNotEmpty).join(' · ')),
                    value: selected.contains(entry.id),
                    onChanged: (checked) => setDialogState(() {
                      if (checked == true) {
                        selected.add(entry.id);
                      } else {
                        selected.remove(entry.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Biriktirish'),
            ),
          ],
        ),
      ),
    );
    if (!_current || confirmed != true) return;
    await _run(() async {
      await _api.reconcileWasteEntries(
        bin: bin,
        apparatusId: widget.apparatusId,
        entryIds: selected.toList(),
      );
      await _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final bin = _snapshot?.bin;
    final cycle = bin?.cycle;
    final pending = _snapshot?.pending ?? const <WasteEntry>[];
    return AppShell(
      title: 'Chiqindi qutisi',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      showProfileAction: false,
      contentPadding: EdgeInsets.zero,
      appBarBottomLoading: _busy,
      actions: [
        IconButton(
          tooltip: 'Yangilash',
          onPressed: _busy ? null : () => _run(_refresh),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          10,
          14,
          10,
          16 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          Text(
            widget.apparatusName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (widget.orderId case final orderId?) ...[
            const SizedBox(height: 4),
            Text('Buyurtma: $orderId', style: secondaryText),
          ],
          const SizedBox(height: 4),
          Text(
            'Hisobotdagi chiqindi faol qutiga avtomatik qo‘shiladi.',
            style: secondaryText,
          ),
          if (_error case final message?) ...[
            const SizedBox(height: 14),
            AppSegmentSurfaceCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading:
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                title: Text(message),
              ),
            ),
          ],
          if (_snapshot != null && bin == null) ...[
            const SizedBox(height: 14),
            AppSegmentSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Faol quti yo‘q', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Bo‘sh qutini tanlang yoki QR’ni skan qiling.',
                    style: secondaryText,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _assign,
                    style: appFilledActionButtonStyle(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Quti tanlash'),
                  ),
                ],
              ),
            ),
          ],
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 14),
            AppSegmentSurfaceCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                title: Text('Qutiga biriktirilmagan: ${pending.length} ta'),
                trailing: bin != null
                    ? TextButton(
                        onPressed:
                            _busy ? null : () => _reconcile(bin, pending),
                        child: const Text('Biriktirish'),
                      )
                    : null,
              ),
            ),
          ],
          if (bin != null && cycle != null) ...[
            const SizedBox(height: 14),
            _activeBinCard(bin, cycle),
            const SizedBox(height: 14),
            AppSegmentSurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: WasteCycleDetails(cycle: cycle, showSummary: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _activeBinCard(WasteBin bin, WasteCycle cycle) {
    final theme = Theme.of(context);
    return AppSegmentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Text(
                bin.label,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              AppStatusChip(label: wasteStatusLabel(cycle.status)),
            ],
          ),
          const SizedBox(height: 12),
          AppMetricTile(
            label: 'Qayd etilgan chiqindi',
            value: wasteKgLabel(cycle.expectedKg),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _busy ? null : () => _submit(bin, replace: true),
            style: appFilledActionButtonStyle(),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Qutini almashtirish'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _submit(bin, replace: false),
            style: appOutlinedActionButtonStyle(),
            icon: const Icon(Icons.outbox_outlined),
            label: const Text('Qutini topshirish'),
          ),
        ],
      ),
    );
  }
}

class _EmptyWasteBinPicker extends StatefulWidget {
  const _EmptyWasteBinPicker({required this.apparatusId});

  final String apparatusId;

  @override
  State<_EmptyWasteBinPicker> createState() => _EmptyWasteBinPickerState();
}

class _EmptyWasteBinPickerState extends State<_EmptyWasteBinPicker> {
  late final _load = MobileApi.instance.wasteBins(
    apparatusId: widget.apparatusId,
    status: WasteBinStatus.empty,
  );

  @override
  Widget build(BuildContext context) => SafeArea(
        child: FutureBuilder<List<WasteBin>>(
          future: _load,
          builder: (context, snapshot) {
            final bins = snapshot.data
                ?.where((bin) => bin.configured)
                .toList(growable: false);
            return ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner),
                  title: const Text('Qutini skan qilish'),
                  onTap: () => Navigator.pop(context, ''),
                ),
                if (snapshot.connectionState != ConnectionState.done)
                  const LinearProgressIndicator(),
                if (snapshot.hasError)
                  ListTile(title: Text(wasteErrorText(snapshot.error!))),
                if (bins?.isEmpty == true)
                  const ListTile(
                      title: Text(
                          'Bu apparatga biriktirilgan bo‘sh quti topilmadi')),
                for (final bin in bins ?? <WasteBin>[])
                  ListTile(
                    title: Text(bin.name),
                    subtitle: Text([
                      if (bin.name != bin.code) bin.code,
                      'Tara ${wasteKgLabel(bin.tareKg)}',
                    ].join(' · ')),
                    onTap: () => Navigator.pop(context, bin.code),
                  ),
              ],
            );
          },
        ),
      );
}
