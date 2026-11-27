import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/urdu_aware_text.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../admin/presentation/widgets/admin_catalog_list_row.dart';
import '../../admin/presentation/widgets/admin_top_notice.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../models/preparation_models.dart';
import 'material_paddon_details_sheet.dart';
import 'material_paddon_receipt_dialog.dart';

typedef PaddonAttachment = ({
  String code,
  List<String> rollIds,
  List<String> batchIds,
});

Future<PaddonAttachment?> showProductionPaddonPicker(
  BuildContext context, {
  required bool Function() currentAccount,
  List<String> receiptNames = const [],
  List<String> batchIds = const [],
}) =>
    _showPaddonPicker(
      context,
      _ProductionPaddonPicker(
        receiptNames: receiptNames,
        batchIds: batchIds,
        currentAccount: currentAccount,
      ),
    );

Future<PaddonAttachment?> showInventoryPaddonPicker(
  BuildContext context, {
  required bool Function() currentAccount,
  required List<String> assetRefs,
}) =>
    _showPaddonPicker(
      context,
      _ProductionPaddonPicker(
        inventoryAssetRefs: assetRefs,
        currentAccount: currentAccount,
      ),
    );

Future<PaddonAttachment?> _showPaddonPicker(
  BuildContext context,
  _ProductionPaddonPicker picker,
) async {
  final result = await showDialog<PaddonAttachment>(
    context: context,
    barrierDismissible: false,
    builder: (_) => picker,
  );
  if (result != null && context.mounted && picker.currentAccount()) {
    showAdminTopNotice(
      context,
      AppLocalizations.of(context).uiText(
        '${result.rollIds.length} ta rulon ${result.code} paddoniga biriktirildi',
      ),
      tone: AdminTopNoticeTone.success,
    );
  }
  return result;
}

class _ProductionPaddonPicker extends StatefulWidget {
  const _ProductionPaddonPicker({
    this.receiptNames = const [],
    this.batchIds = const [],
    this.inventoryAssetRefs,
    required this.currentAccount,
  });

  final List<String> receiptNames;
  final List<String> batchIds;
  final List<String>? inventoryAssetRefs;
  final bool Function() currentAccount;

  @override
  State<_ProductionPaddonPicker> createState() =>
      _ProductionPaddonPickerState();
}

class _ProductionPaddonPickerState extends State<_ProductionPaddonPicker> {
  final _api = MobileApi.instance;
  final _paddons = <PreparationMaterialPaddon>[];
  PreparationPendingCommand? _pending;
  PreparationPaddonSelection? _selection;
  String? _selectedCode, _error;
  int? _nextOffset;
  bool _loading = false, _saving = false, _paddonDialogOpen = false;

  bool get _current => mounted && widget.currentAccount();
  bool get _fromBatches => widget.batchIds.isNotEmpty;
  bool get _fromInventory => widget.inventoryAssetRefs != null;
  List<String> get _requestedRolls =>
      widget.inventoryAssetRefs ?? widget.receiptNames;

  Future<PreparationPendingCommand?> _pendingAttachment() => _fromInventory
      ? _api.pendingInventoryPaddonAttachment()
      : _api.pendingPreparationPaddonAttachment();

  PreparationMaterialPaddon? get _selectedPaddon =>
      _paddons.where((paddon) => paddon.code == _selectedCode).firstOrNull;
  bool get _transfersToSelected {
    final selection = _selection;
    final warehouse = _selectedPaddon?.warehouse;
    return selection != null &&
        (selection.transferReceiptNamesByWarehouse.containsKey(warehouse) ||
            selection.transferWarehouses.contains(warehouse));
  }
  List<String> get _selectedRolls {
    if (_selection case final selection?) {
      return selection.receiptsFor(_selectedPaddon?.warehouse);
    }
    return _fromBatches ? const [] : _requestedRolls;
  }

  @override
  void initState() {
    super.initState();
    AppSession.instance.revision.addListener(_accountChanged);
    unawaited(_load());
  }

  void _accountChanged() {
    if (mounted && !_current && ModalRoute.isCurrentOf(context) == true) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    AppSession.instance.revision.removeListener(_accountChanged);
    super.dispose();
  }

  Future<void> _load({int offset = 0, String? selectCode}) async {
    if (!_current || _loading || _saving) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (offset == 0) {
        final pending = await _pendingAttachment();
        if (!_current) return;
        if (pending != null) {
          setState(() => _pending = pending);
          return;
        }
      }
      if (_fromInventory && _requestedRolls.isEmpty) {
        setState(() => _error = 'Tanlangan rulonlar yo‘q');
        return;
      }
      final (page, selection) = _fromInventory
          ? (await _api.inventoryPaddonOptions(_requestedRolls, offset: offset), null)
          : _fromBatches
          ? await _api.preparationBatchPaddonOptions(widget.batchIds, offset: offset)
          : await _api.preparationPaddonOptions(widget.receiptNames, offset: offset);
      if (!_current) return;
      final created = selectCode != null &&
              page.hasMore &&
              !page.paddons.any((paddon) => paddon.code == selectCode)
          ? await _api.materialPaddonByCode(selectCode)
          : null;
      if (!_current) return;
      setState(() {
        _selection = selection;
        if (offset == 0) _paddons.clear();
        final known = _paddons.map((paddon) => paddon.code).toSet();
        _paddons.addAll(page.paddons.where((paddon) => known.add(paddon.code)));
        if (created != null && known.add(created.code)) _paddons.add(created);
        if (selection != null) {
          _paddons.removeWhere(
            (paddon) => selection.receiptsFor(paddon.warehouse).isEmpty,
          );
        }
        if (selectCode != null && _paddons.any((paddon) => paddon.code == selectCode)) {
          _selectedCode = selectCode;
        }
        if (_selectedPaddon == null) _selectedCode = null;
        _nextOffset = page.nextOffset;
      });
    } catch (error) {
      if (_current) {
        setState(() {
          if (_fromInventory) {
            _paddons.clear();
            _selectedCode = null;
            _nextOffset = null;
          }
          _error = error is MobileApiException
              ? error.message
              : 'Mos paddonlar yuklanmadi';
        });
      }
    } finally {
      if (_current) setState(() => _loading = false);
    }
  }

  String _paddonSubtitle(PreparationMaterialPaddon paddon) => [
        paddon.warehouse,
        if (paddon.name.isNotEmpty) paddon.code,
        materialPaddonBalance(paddon),
      ].join(' • ');

  Future<void> _findExistingPaddon(PreparationPaddonSelection? selection) async {
    if (!_current || _loading || _saving || _paddonDialogOpen) return;
    setState(() => _paddonDialogOpen = true);
    try {
      final paddon = await showModalBottomSheet<PreparationMaterialPaddon>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        sheetAnimationStyle: kM3PickerSheetAnimation,
        builder: (sheetContext) => M3AsyncPickerSheet<PreparationMaterialPaddon>(
          title: 'Mavjud paddonlar',
          hintText: 'Paddon nomi yoki kodi',
          itemKey: (paddon) => paddon.code,
          itemTitle: (paddon) => paddon.title,
          itemSubtitle: _paddonSubtitle,
          loadPage: (query, offset, _) async {
            if (!_current) throw StateError('Akkaunt o‘zgargan');
            final page = _fromInventory
                ? await _api.inventoryPaddonOptions(
                    _requestedRolls, query: query, offset: offset,
                  )
                : await _api.materialPaddons(query: query, offset: offset);
            if (!_current) throw StateError('Akkaunt o‘zgargan');
            return page.paddons;
          },
          onSelected: (value) => Navigator.of(sheetContext).pop(value),
          listBuilder: (context, paddons, controller, loadingMore, select) =>
              ListView.separated(
            controller: controller,
            shrinkWrap: true,
            itemCount: paddons.length + (loadingMore ? 1 : 0),
            separatorBuilder: (context, index) =>
                const SizedBox(height: M3SegmentedListGeometry.gap),
            itemBuilder: (context, index) {
              if (index == paddons.length) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: AppLoadingIndicator()),
                );
              }
              final paddon = paddons[index];
              final count = selection?.receiptsFor(paddon.warehouse).length ??
                  _requestedRolls.length;
              final compatible = count > 0;
              final availability = compatible
                  ? '$count ta rulon biriktiriladi'
                  : 'Bu omborda yaroqli rulon yo‘q';
              return AdminCatalogListRow(
                key: ValueKey('production-existing-paddon-${paddon.code}'),
                slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                  index, paddons.length,
                ),
                icon: compatible ? Icons.inventory_2_outlined : Icons.block_rounded,
                title: paddon.title,
                titleMaxLines: 2,
                subtitleMaxLines: 4,
                subtitle: '${_paddonSubtitle(paddon)}\n$availability',
                onTap: compatible ? () => select(paddon) : null,
              );
            },
          ),
        ),
      );
      if (!_current || paddon == null) return;
      setState(() {
        final index = _paddons.indexWhere((item) => item.code == paddon.code);
        if (index < 0) {
          _paddons.add(paddon);
        } else {
          _paddons[index] = paddon;
        }
        _selectedCode = paddon.code;
      });
    } finally {
      if (_current) setState(() => _paddonDialogOpen = false);
    }
  }

  Future<void> _openEmptyPaddon(String warehouse) async {
    if (!_current || _loading || _saving || _paddonDialogOpen) return;
    setState(() => _paddonDialogOpen = true);
    try {
      final result = await showMaterialPaddonReceipt(
        context,
        emptyWarehouse: warehouse,
      );
      if (!_current || result == null) return;
      await _load(
        selectCode: result.empty && result.warehouse == warehouse
            ? result.code
            : null,
      );
    } finally {
      if (_current) setState(() => _paddonDialogOpen = false);
    }
  }

  Future<void> _save() async {
    if (!_current || _loading || _saving || _paddonDialogOpen) return;
    final pending = _pending;
    final code = pending?.payload['code'] as String? ?? _selectedCode;
    if (code == null) return;
    final idField = _fromInventory ? 'asset_refs' : 'receipt_names';
    final ids = (pending?.payload[idField] as List?)?.cast<String>() ??
        _selectedRolls;
    if (ids.isEmpty) return;
    final batchIds = switch (pending?.payload) {
      null => widget.batchIds,
      {'batch_ids': final List ids} => ids.cast<String>(),
      {'batch_id': final String id} => [id],
      _ => const <String>[],
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_fromInventory) {
        await _api.attachInventoryRollsToPaddon(code, ids);
      } else {
        await _api.attachPreparationRollsToPaddon(
          code,
          ids,
          batchIds: batchIds,
          transferBetweenWarehouses: pending == null
              ? _transfersToSelected
              : pending.payload['transfer_between_warehouses'] == true,
        );
      }
      if (mounted && widget.currentAccount()) {
        Navigator.of(context).pop(
          (code: code, rollIds: ids, batchIds: batchIds),
        );
      }
    } catch (error) {
      if (!_current) return;
      final retry = await _pendingAttachment().onError((_, __) => null);
      if (_current) {
        setState(() {
          _pending = retry;
          if (retry == null) {
            _selection = null;
            _paddons.clear();
            _selectedCode = null;
            _nextOffset = null;
          }
          _error = error is MobileApiException
              ? error.message
              : 'Biriktirish natijasini qayta tekshiring';
        });
      }
    } finally {
      if (_current) setState(() => _saving = false);
    }
  }

  Widget _packedRolls(int count, List<PreparationPackedRoll> rolls) =>
      ExpansionTile(
        key: const ValueKey('production-attach-packed-rolls'),
        tilePadding: EdgeInsets.zero,
        title: UrduAwareText('$count ta rulon allaqachon paddonda'),
        children: [
          for (final roll in rolls)
            ListTile(
              title: UrduAwareText(roll.barcode),
              subtitle: (roll.paddonName.isNotEmpty || roll.paddonCode.isNotEmpty)
                  ? UrduAwareText([
                      roll.paddonName,
                      roll.paddonCode,
                    ].where((part) => part.isNotEmpty).join(' • '))
                  : null,
            ),
        ],
      );

  Widget _selectionSummary(PreparationPaddonSelection selection) {
    if (selection.totalRolls == 0) {
      return const UrduAwareText('Hali rulon kirim qilinmagan.');
    }
    final selected = _selectedPaddon;
    final receipts = _selectedRolls.toSet();
    final count = selected == null ? selection.eligibleCount : receipts.length;
    final elsewhere = selection.eligibleCount - count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selection.batchIds.length > 1)
          UrduAwareText('${selection.batchIds.length} ta partiya tanlandi'),
        UrduAwareText(
          '${selection.totalRolls} ta rulondan $count tasi '
          '${selected == null ? 'biriktirishga yaroqli' : 'biriktiriladi'}',
        ),
        for (final entry in selection.skipped.entries)
          if (entry.key == 'packed' && selection.packedRolls.isNotEmpty)
            _packedRolls(entry.value, selection.packedRolls)
          else
            UrduAwareText('${entry.value} ta ${switch (entry.key) {
              'missing' => 'rulon omborda topilmadi',
              'packed' => 'rulon allaqachon paddonda',
              'consumed' => 'rulon kesilgan yoki sarflangan',
              'outside_warehouse' => 'rulon ko‘chirilmoqda yoki boshqa joyda',
              _ => 'rulon band yoki biriktirib bo‘lmaydi',
            }}'),
        if (elsewhere > 0)
          UrduAwareText('$elsewhere ta rulon boshqa omborda qoladi'),
        if (selected != null && _transfersToSelected)
          for (final entry in selection.receiptNamesByWarehouse.entries)
            if (entry.key != selected.warehouse)
              if (entry.value.where(receipts.contains).length
                  case final moving when moving > 0)
                UrduAwareText(
                  '${entry.key} → ${selected.warehouse} • '
                  '$moving ta rulon ko‘chiriladi',
                ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
    final selection = _selection;
    final nextOffset = _nextOffset;
    final partial = selection != null &&
        _selectedPaddon != null &&
        _selectedRolls.length < selection.totalRolls;
    return PopScope(
      canPop: !_saving && !_paddonDialogOpen,
      child: AlertDialog(
        title: const UrduAwareText('Paddonga biriktirish'),
        scrollable: true,
        insetPadding: m3DialogInsetPadding,
        constraints: const BoxConstraints(maxWidth: m3DialogMaxWidth),
        content: SizedBox(
          width: m3DialogMaxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pending != null)
                UrduAwareText(
                  '${pending.payload['code']} paddoniga biriktirish natijasini tekshiring.',
                )
              else ...[
                if (selection != null)
                  _selectionSummary(selection)
                else if (!_fromBatches)
                  UrduAwareText(
                    '${_requestedRolls.length} ta tanlangan rulon',
                  ),
                const SizedBox(height: 8),
                if ((_fromInventory && _paddons.isNotEmpty) ||
                    (selection != null && selection.eligibleCount > 0))
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      key: const ValueKey('production-find-existing-paddon'),
                      onPressed: _loading || _saving || _paddonDialogOpen
                          ? null
                          : () => _findExistingPaddon(selection),
                      icon: const Icon(Icons.search_rounded),
                      label: const UrduAwareText('Mavjud paddonni topish'),
                    ),
                  ),
                for (final paddon in _paddons)
                  ListTile(
                    key: ValueKey('production-attach-paddon-${paddon.code}'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _selectedCode == paddon.code
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                    ),
                    selected: _selectedCode == paddon.code,
                    title: UrduAwareText(paddon.title),
                    subtitle: UrduAwareText(_paddonSubtitle(paddon)),
                    onTap: _loading || _saving || _paddonDialogOpen
                        ? null
                        : () => setState(() => _selectedCode = paddon.code),
                  ),
                if (_loading)
                  const Center(child: AppLoadingIndicator())
                else if (nextOffset != null)
                  TextButton(
                    onPressed: _saving ? null : () => _load(offset: nextOffset),
                    child: const UrduAwareText('Yana yuklash'),
                  )
                else if (_error == null &&
                    _paddons.isEmpty &&
                    selection?.eligibleCount != 0)
                  UrduAwareText(
                    selection == null
                        ? 'Shu omborda paddon topilmadi.'
                        : 'Mos paddon topilmadi.',
                  ),
                if (!_loading && _error == null && nextOffset == null &&
                    selection != null)
                  for (final warehouse in {
                    ...selection.receiptNamesByWarehouse.keys,
                    ...selection.transferWarehouses,
                    ...selection.transferReceiptNamesByWarehouse.keys,
                  })
                    if (selection.receiptsFor(warehouse).isNotEmpty &&
                        !_paddons.any((paddon) => paddon.warehouse == warehouse))
                      ListTile(
                        key: ValueKey('production-open-paddon-$warehouse'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.add_rounded),
                        title: const UrduAwareText('Bo‘sh paddon ochish'),
                        subtitle: UrduAwareText(
                          '$warehouse • ${selection.receiptsFor(warehouse).length} ta rulon',
                        ),
                        onTap: _saving || _paddonDialogOpen
                            ? null
                            : () => _openEmptyPaddon(warehouse),
                      ),
              ],
              if (_error case final error?) ...[
                const SizedBox(height: 8),
                UrduAwareText(error,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                if (pending == null && _paddons.isEmpty)
                  TextButton(
                    onPressed: _loading || _saving ? null : () => _load(),
                    child: const UrduAwareText('Qayta urinish'),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving || _paddonDialogOpen
                ? null
                : () => Navigator.of(context).pop(),
            child: const UrduAwareText('Bekor qilish'),
          ),
          FilledButton(
            key: const ValueKey('production-attach-paddon-save'),
            onPressed: _loading ||
                    _saving ||
                    _paddonDialogOpen ||
                    (pending == null &&
                        (_selectedCode == null || _selectedRolls.isEmpty))
                ? null
                : _save,
            child: UrduAwareText(
              _saving
                  ? 'Biriktirilmoqda…'
                  : pending != null
                      ? 'Natijani tekshirish'
                      : _transfersToSelected
                          ? 'Ko‘chirish va biriktirish'
                          : partial
                              ? 'Yaroqli rulonlarni biriktirish'
                              : 'Biriktirish',
            ),
          ),
        ],
      ),
    );
  }
}
