import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../../core/widgets/paddon_weight_totals.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/feedback/rps_qr_reprint_sheet.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/print_service.dart';
import '../../../core/production/active_rezka_paddon_store.dart';
import '../../admin/presentation/raw_material_scan_dialog.dart';
import '../../admin/presentation/progress_printer_picker.dart';
import '../../admin/presentation/widgets/admin_drawer_navigation.dart';
import '../../admin/presentation/widgets/admin_create_hub_sheet.dart';
import '../../admin/presentation/widgets/admin_order_image_thumb.dart';
import '../../shared/models/app_models.dart';
import 'aparatchi_paddon_display.dart';
import 'widgets/aparatchi_dock.dart';
import 'widgets/aparatchi_navigation_drawer.dart';
import '../../../core/localization/urdu_aware_text.dart';

part 'aparatchi_paddon_detail_screen__AparatchiPaddonDetailScreenState_methods_01.dart';
part 'aparatchi_paddon_detail_screen__AparatchiPaddonDetailScreenState_methods_02.dart';
part 'aparatchi_paddon_detail_screen_models_part_01.dart';
part 'aparatchi_paddon_detail_screen_bobina_summary.dart';
part 'aparatchi_paddon_detail_screen_swipe_remove.dart';
part 'aparatchi_paddon_detail_screen_order_header.dart';
part 'aparatchi_paddon_print_workflow.dart';
part 'aparatchi_paddon_qr_addition.dart';

class _AparatchiPaddonDetailScreenState
    extends State<AparatchiPaddonDetailScreen> {
  late Future<AdminPaddonSnapshot> _future;
  List<AdminApparatus> _apparatus = const [];
  final _selectionListKey = GlobalKey();
  final Set<String> _selectedAvailableBatchIds = <String>{};
  final Set<String> _selectedAssignedBatchIds = <String>{};
  bool _busy = false;
  bool _printingQr = false;
  bool _selectionMode = false;
  _PaddonEditMode _editMode = _PaddonEditMode.add;
  int? _bobinaFilterUnits;
  final _qrScannerKey = GlobalKey();
  final Map<String, AdminProgressBatch> _scannedWips = {};
  final Map<String, String> _scannedBatchIdsByQr = {};
  final Set<String> _queuedQrValues = {};
  Future<void> _qrScanQueue = Future<void>.value();
  Object? _qrScanScope;
  int _qrScanGeneration = 0;
  int _qrLookupsPending = 0;
  bool _qrScanMode = false;
  bool _qrReviewOpen = false;
  String _qrScanStatus = '';
  ProductionQuickScanFeedback? _qrScanFeedback;
  Timer? _qrScanFeedbackTimer;

  void _setPrintingQr(bool value) => setState(() => _printingQr = value);
  void _updateQrScan(VoidCallback update) => setState(update);

  @override
  void initState() {
    super.initState();
    final initial =
        widget.snapshot ?? widget.initialSnapshot?.takeForCode(widget.code);
    _future = initial == null ? _load() : Future.value(initial);
    if (widget.apparatus == null) unawaited(_loadApparatus());
  }

  @override
  void dispose() {
    _qrScanFeedbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadApparatus() async {
    try {
      final catalog = await (widget.apparatusLoader?.call() ??
          MobileApi.instance.adminApparatus(limit: 10000));
      if (mounted) setState(() => _apparatus = catalog);
    } catch (_) {
      // The pallet remains usable with localized labels if the catalog fails.
    }
  }

  Set<String> get _selectedBatchIds => _editMode == _PaddonEditMode.add
      ? _selectedAvailableBatchIds
      : _selectedAssignedBatchIds;

  void _exitSelection() {
    if (_busy || !mounted) return;
    setState(() {
      _selectionMode = false;
      _editMode = _PaddonEditMode.add;
      _bobinaFilterUnits = null;
      _selectedAvailableBatchIds.clear();
      _selectedAssignedBatchIds.clear();
    });
  }

  void _toggleBobinaFilter(int weightUnits) {
    setState(() {
      _bobinaFilterUnits =
          _bobinaFilterUnits == weightUnits ? null : weightUnits;
      _selectedAvailableBatchIds.clear();
      _selectedAssignedBatchIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_qrScanMode ||
          (!_busy && _scannedWips.isEmpty && _qrLookupsPending == 0),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy && !_qrReviewOpen) {
          unawaited(_leaveQrScanPage());
        }
      },
      child: AppShell(
        title: widget.code,
        subtitle: context.l10n.productionText('worker.paddon.detail.subtitle'),
        nativeTopBar: true,
        drawer: widget.manageItems
            ? AparatchiNavigationDrawer(
                selectedIndex: 2,
                selectedRouteName: AppRoutes.apparatusPaddons,
                onNavigate: (routeName) =>
                    AdminDrawerNavigation.openRoute(context, routeName),
              )
            : null,
        bottom: widget.bottom ?? _buildDock(context),
        contentPadding: EdgeInsets.zero,
        child: ColoredBox(
          color: AppTheme.shellStart(context),
          child: _buildBody(context),
        ),
      ),
    );
  }
}
