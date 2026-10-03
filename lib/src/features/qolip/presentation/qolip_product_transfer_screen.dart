import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/navigation/native_back_button.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/transfer/two_pane_transfer.dart';
import '../../../core/widgets/transfer/transfer_list.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../state/qolip_data_revision.dart';
import 'qolip_cell_qr_scan_screen.dart';
import 'widgets/qolip_dock.dart';
import 'widgets/qolip_navigation_drawer.dart';

part 'qolip_product_transfer_actions.dart';

class QolipProductTransferScreen extends StatefulWidget {
  const QolipProductTransferScreen({super.key});

  @override
  State<QolipProductTransferScreen> createState() =>
      _QolipProductTransferScreenState();
}

class _QolipTransferDrag
    extends TransferDragPayload<QolipProduct, QolipProduct> {
  const _QolipTransferDrag({required super.source, required super.items});
}

class _QolipProductTransferScreenState
    extends State<QolipProductTransferScreen> {
  List<QolipProduct> _molds = const [];
  QolipProduct? _source;
  QolipProduct? _target;
  QolipProduct? _selectedProduct;
  _QolipTransferDrag? _dragging;
  final _topScrollController = ScrollController();
  final _bottomScrollController = ScrollController();
  final Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;
  bool _scanning = false;
  Object? _loadError;
  int _loadGeneration = 0;
  String? _requestSignature;
  String? _requestId;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    _topScrollController.dispose();
    _bottomScrollController.dispose();
    super.dispose();
  }

  List<QolipProduct> _forProduct(QolipProduct? product) => product == null
      ? const []
      : _molds
          .where((mold) =>
              mold.code.trim().toLowerCase() ==
              product.code.trim().toLowerCase())
          .toList();

  String _text(String key, {Map<String, Object> values = const {}}) =>
      context.l10n.qolipText('product_transfer.$key', values: values);

  void _openDrawerRoute(String route) {
    if (ModalRoute.of(context)?.settings.name != route) {
      Navigator.of(context).pushReplacementNamed(route);
    }
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.maybePop();
    } else {
      navigator.pushReplacementNamed(AppRoutes.qolipProducts);
    }
  }

  @override
  Widget build(BuildContext context) => AppShell(
        title: _text('title'),
        subtitle: '',
        nativeTopBar: true,
        automaticallyImplyNativeLeading: true,
        leading: NativeBackButtonSlot(onPressed: _goBack),
        nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
        drawer: QolipNavigationDrawer(
          selectedIndex: 8,
          selectedRouteName: AppRoutes.qolipProductTransfer,
          onNavigate: _openDrawerRoute,
        ),
        bottom: const QolipDock(activeTab: null),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: _loading
            ? const Center(child: AppLoadingIndicator())
            : _loadError != null
                ? AppRetryState(onRetry: _reload)
                : Column(children: [
                    Row(children: [
                      Expanded(
                          child: Text(_text('hint'),
                              style: Theme.of(context).textTheme.bodySmall)),
                      IconButton(
                        key: const ValueKey('qolip-product-transfer-scan'),
                        tooltip: context.l10n.qolipText('scanner.title.mold'),
                        onPressed: _saving || _scanning ? null : _scanSource,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                      ),
                      IconButton(
                        tooltip: context.l10n.qolipText('tasks.check'),
                        onPressed: _saving || _scanning ? null : _reload,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ]),
                    Expanded(
                        child: TwoPaneTransfer(
                      topHeader: TransferPickerHeader(
                        key: const ValueKey('qolip-product-transfer-source'),
                        title: _source?.name ?? _text('source'),
                        icon: Icons.inventory_2_outlined,
                        onTap: _saving || _scanning
                            ? null
                            : () => _pickProduct(true),
                      ),
                      topBody: _buildMolds(_source, source: true),
                      bottomHeader: TransferPickerHeader(
                        key: const ValueKey('qolip-product-transfer-target'),
                        title: _target?.name ?? _text('target'),
                        icon: Icons.drive_file_move_outlined,
                        onTap: _saving || _scanning
                            ? null
                            : () => _pickProduct(false),
                      ),
                      bottomBody: _buildMolds(_target, source: false),
                    )),
                  ]),
      );

  Widget _buildMolds(QolipProduct? product, {required bool source}) {
    if (product == null) {
      return Center(child: Text(_text(source ? 'source' : 'target')));
    }
    return TransferDropZone<QolipProduct, QolipProduct, _QolipTransferDrag>(
      zone: product,
      items: _forProduct(product),
      listKey: ValueKey(source
          ? 'qolip-product-transfer-source-list'
          : 'qolip-product-transfer-target-list'),
      scrollController: source ? _topScrollController : _bottomScrollController,
      selectedItemIds: _selected,
      draggingItems: _dragging?.items ?? const [],
      draggingSource: _dragging?.source,
      itemId: (mold) => mold.qolipCode.trim().toLowerCase(),
      itemKey: (mold, product, disabled) =>
          ValueKey('qolip-transfer-${mold.qolipCode.trim().toLowerCase()}'),
      sameZone: (a, b) =>
          a.code.trim().toLowerCase() == b.code.trim().toLowerCase(),
      isItemDisabled: (mold, _) => mold.isInUse || _saving || _scanning,
      canMoveTo: (mold, target, origin) =>
          !_saving && !_scanning && !mold.isInUse && target.code != origin.code,
      emptyState: Center(child: Text(_text('empty'))),
      batchLabel: (count) => _text('move', values: {'count': count}),
      onToggleSelect: (code) => _toggle(code, product),
      buildDragPayload: (
              {required item, required source, required zoneItems}) =>
          _QolipTransferDrag(
        source: source,
        items: _selected.contains(item.qolipCode.trim().toLowerCase())
            ? zoneItems
                .where((mold) =>
                    _selected.contains(mold.qolipCode.trim().toLowerCase()) &&
                    !mold.isInUse)
                .toList()
            : [item],
      ),
      onDragStarted: (payload) => setState(() => _dragging = payload),
      onDragEnded: () {
        if (mounted) setState(() => _dragging = null);
      },
      onMove: ({required items, required from, required to}) => _move(
        items.map((mold) => mold.qolipCode.trim().toLowerCase()).toList(),
        from: from,
        to: to,
      ),
      itemCardBuilder: _buildMoldCard,
    );
  }

  Widget _buildMoldCard({
    required QolipProduct item,
    required int index,
    required M3SegmentVerticalSlot slot,
    required bool selected,
    required bool disabled,
    required VoidCallback? onToggleSelect,
    required Widget? trailing,
    required BorderRadius? borderRadiusOverride,
  }) {
    final theme = Theme.of(context);
    return TransferListRow(
      slot: slot,
      identity: item.qolipCode,
      title: TransferItemTitle(
        code: item.qolipCode,
        title: item.name,
        identity: item.qolipCode,
        theme: theme,
        scheme: theme.colorScheme,
      ),
      subtitle: [
        if (item.qolipSize > 0) '${item.qolipSize}',
        if (item.qolipColor.trim().isNotEmpty)
          context.l10n.qolipColorName(item.qolipColor),
        if (item.isInUse) context.l10n.qolipErrorText('qolip_in_use'),
      ].join(' • '),
      leading: TransferIndexBadge(
          index: index,
          selected: selected,
          onTap: disabled ? null : onToggleSelect),
      trailing: trailing ??
          TransferDragHandle(color: theme.colorScheme.onSurfaceVariant),
      onTap: disabled ? null : onToggleSelect,
      disabled: disabled,
      borderRadiusOverride: borderRadiusOverride,
    );
  }
}
