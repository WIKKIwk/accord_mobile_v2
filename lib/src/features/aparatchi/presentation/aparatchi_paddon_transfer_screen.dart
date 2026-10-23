import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/session/state/app_session.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/navigation/native_back_button.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/transfer/two_pane_transfer.dart';
import '../../../core/widgets/transfer/transfer_list.dart';
import '../../shared/models/app_models.dart';
import 'aparatchi_paddon_display.dart';

part 'aparatchi_paddon_transfer_actions.dart';

class AparatchiPaddonTransferScreen extends StatefulWidget {
  const AparatchiPaddonTransferScreen({super.key, this.apparatusId = ''});

  final String apparatusId;

  @override
  State<AparatchiPaddonTransferScreen> createState() =>
      _AparatchiPaddonTransferScreenState();
}

class _PaddonTransferDrag
    extends TransferDragPayload<AdminProgressBatch, String> {
  const _PaddonTransferDrag({required super.items, required super.source});
}

class _AparatchiPaddonTransferScreenState
    extends State<AparatchiPaddonTransferScreen> {
  List<AdminPaddon> _paddons = [];
  AdminPaddonSnapshot? _source;
  AdminPaddonSnapshot? _target;
  _PaddonTransferDrag? _dragging;
  final Set<String> _selected = {};
  String? _selectedCode;
  bool _loading = true;
  bool _saving = false;
  Object? _error;
  int _generation = 0;
  late String _observedScope;
  final _topScroll = ScrollController();
  final _bottomScroll = ScrollController();

  String _text(String key, {Map<String, Object> values = const {}}) =>
      context.l10n
          .productionText('worker.paddon.transfer.$key', values: values);

  @override
  void initState() {
    super.initState();
    _observedScope = currentSessionReadScope();
    AppSession.instance.revision.addListener(_sessionChanged);
    unawaited(_reload());
  }

  bool _isCurrentScope(String scope) => scope == currentSessionReadScope();
  void _updateState(VoidCallback update) => setState(update);

  void _sessionChanged() {
    final scope = currentSessionReadScope();
    if (scope == _observedScope) return;
    _observedScope = scope;
    _source = null;
    _target = null;
    _saving = false;
    unawaited(_reload());
  }

  @override
  void dispose() {
    AppSession.instance.revision.removeListener(_sessionChanged);
    _topScroll.dispose();
    _bottomScroll.dispose();
    super.dispose();
  }

  bool _movable(AdminProgressBatch item) =>
      item.batchId.trim().isNotEmpty &&
      item.wipStatus == 'waiting' &&
      (item.payloadJson['finished_goods_stock_id']?.toString() ?? '').isEmpty &&
      (item.payloadJson['received_warehouse']?.toString() ?? '').isEmpty;

  bool _editable(AdminPaddonSnapshot? snapshot) {
    final profile = AppSession.instance.profile;
    return snapshot != null &&
        !snapshot.paddon.isLocked &&
        snapshot.canManageItems &&
        profile != null &&
        (profile.role == UserRole.admin ||
            snapshot.freeMovementEnabled ||
            snapshot.paddon.createdByRef == profile.ref);
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: AppShell(
          title: _text('title'),
          subtitle: '',
          nativeTopBar: true,
          leading: NativeBackButtonSlot(
            onPressed: () {
              if (!_saving) Navigator.of(context).maybePop();
            },
          ),
          contentPadding: const EdgeInsets.all(12),
          child: _loading
              ? const Center(child: AppLoadingIndicator())
              : _error != null
                  ? AppRetryState(onRetry: _reload)
                  : Column(children: [
                      Row(children: [
                        Expanded(child: Text(_text('hint'))),
                        IconButton(
                          key: const ValueKey('paddon-transfer-refresh'),
                          tooltip: _text('refresh'),
                          onPressed: _saving ? null : _reload,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ]),
                      if (_saving) const LinearProgressIndicator(),
                      if (_selected.isNotEmpty)
                        FilledButton.icon(
                          key: const ValueKey('paddon-transfer-selected'),
                          onPressed: _saving ||
                                  !_editable(_source) ||
                                  !_editable(_target)
                              ? null
                              : () => _move(
                                    _selected.toList(),
                                    from: _selectedCode!,
                                    to: _selectedCode == _source!.paddon.code
                                        ? _target!.paddon.code
                                        : _source!.paddon.code,
                                  ),
                          icon: const Icon(Icons.swap_vert_rounded),
                          label: Text(_text('move',
                              values: {'count': _selected.length})),
                        ),
                      Expanded(
                          child: TwoPaneTransfer(
                        topHeader: _header(_source, true),
                        topBody: _zone(_source, true),
                        bottomHeader: _header(_target, false),
                        bottomBody: _zone(_target, false),
                      )),
                    ]),
        ),
      );

  Widget _header(AdminPaddonSnapshot? data, bool top) => TransferPickerHeader(
        key:
            ValueKey(top ? 'paddon-transfer-source' : 'paddon-transfer-target'),
        title: data?.paddon.code ?? _text(top ? 'source' : 'target'),
        icon: Icons.pallet,
        onTap: _saving ? null : () => _pick(top),
      );

  Widget _zone(AdminPaddonSnapshot? data, bool top) {
    if (data == null) return Center(child: Text(_text('choose')));
    final code = data.paddon.code;
    return TransferDropZone<AdminProgressBatch, String, _PaddonTransferDrag>(
      zone: code,
      items: data.items,
      listKey: ValueKey('paddon-transfer-list-$code'),
      scrollController: top ? _topScroll : _bottomScroll,
      selectedItemIds: _selected,
      draggingItems: _dragging?.items ?? const [],
      draggingSource: _dragging?.source,
      itemId: (item) => item.batchId,
      itemKey: (item, _, disabled) =>
          ValueKey('paddon-transfer-wip-${item.batchId}'),
      sameZone: (a, b) => a == b,
      isItemDisabled: (item, _) =>
          _saving || !_editable(data) || !_movable(item),
      canMoveTo: (item, target, source) =>
          !_saving &&
          source != target &&
          _editable(_source) &&
          _editable(_target) &&
          _movable(item),
      emptyState: Center(child: Text(_text('empty'))),
      batchLabel: (count) => _text('move', values: {'count': count}),
      onToggleSelect: (id) => setState(() {
        if (_selectedCode != code) _selected.clear();
        _selectedCode = code;
        if (!_selected.add(id)) _selected.remove(id);
      }),
      buildDragPayload: (
              {required item, required source, required zoneItems}) =>
          _PaddonTransferDrag(
              source: source,
              items: _selected.contains(item.batchId)
                  ? zoneItems
                      .where(
                          (b) => _selected.contains(b.batchId) && _movable(b))
                      .toList()
                  : [item]),
      onDragStarted: (payload) => setState(() => _dragging = payload),
      onDragEnded: () {
        if (mounted) setState(() => _dragging = null);
      },
      onMove: ({required items, required from, required to}) =>
          _move(items.map((b) => b.batchId).toList(), from: from, to: to),
      itemCardBuilder: _card,
    );
  }

  Widget _card(
      {required AdminProgressBatch item,
      required int index,
      required M3SegmentVerticalSlot slot,
      required bool selected,
      required bool disabled,
      required VoidCallback? onToggleSelect,
      required Widget? trailing,
      required BorderRadius? borderRadiusOverride}) {
    final theme = Theme.of(context);
    return TransferListRow(
      slot: slot,
      identity: item.batchId,
      title: TransferItemTitle(
          code: '',
          title: AparatchiPaddonDisplay.orderSummary(item),
          identity: item.batchId,
          theme: theme,
          scheme: theme.colorScheme),
      subtitle: [
        formatQuantityWithUnit(item.producedQty, item.uom),
        if (item.qrPayload.trim().isNotEmpty) item.qrPayload.trim()
      ].join(' • '),
      leading: TransferIndexBadge(
          index: index, selected: selected, onTap: onToggleSelect),
      trailing: trailing ?? const SizedBox.shrink(),
      onTap: onToggleSelect,
      disabled: disabled,
      borderRadiusOverride: borderRadiusOverride,
    );
  }
}
