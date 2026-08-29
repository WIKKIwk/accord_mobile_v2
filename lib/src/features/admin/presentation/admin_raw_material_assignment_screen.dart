import 'dart:async';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/search/search_normalizer.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/lists/lists.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_dock.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_navigation_drawer.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../logic/canonical_apparatus_display.dart';
import '../logic/production_map_chain.dart';
import '../models/production_map_models.dart';
import 'raw_material_scan_dialog.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_summary_card.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_expandable_filter_chip.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';

part 'admin_raw_material_assignment_screen__AdminRawMaterialAssignmentPanelState_methods_01.dart';
part 'admin_raw_material_assignment_screen__AdminRawMaterialAssignmentPanelState_methods_02.dart';
part 'admin_raw_material_assignment_screen__AdminRawMaterialAssignmentPanelState_methods_03.dart';
part 'admin_raw_material_assignment_screen_models_part_01.dart';
part 'admin_raw_material_assignment_screen_widgets_part_02.dart';
part 'admin_raw_material_assignment_screen_widgets_part_03.dart';

const double _rawMaterialAssignmentPanelGap = 4;

class _AdminRawMaterialAssignmentPanelState
    extends State<AdminRawMaterialAssignmentPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<_RawMaterialAssignmentData> _future;
  List<AdminRawMaterialAssignment> _assignments = const [];
  List<AdminApparatus> _apparatusCatalog = const [];
  List<AdminRawMaterialAssignmentCandidate> _manualCandidates = const [];
  String _selectedOrderId = '';
  String _scannedBarcode = '';
  AdminRawMaterialLookup? _scannedMaterial;
  AdminRawMaterialAssignmentDiagnostic? _scannedDiagnostic;
  String _scanLookupError = '';
  bool _scanLookupLoading = false;
  int _scanLookupRequestId = 0;
  int _scanDiagnosticRequestId = 0;
  bool _saving = false;
  String? _expandedAssignmentKey;
  String _unlinkingAssignmentKey = '';
  String _manualCandidatesOrderId = '';
  String _manualCandidatesApparatus = '';
  String _manualAssigningBarcode = '';
  Object? _manualCandidatesError;
  bool _manualCandidatesLoading = false;
  bool _initialBarcodeHandled = false;
  List<String> _apparatusOptions = const [];
  String _selectedApparatus = '';
  bool _apparatusFilterExpanded = false;

  bool get _apparatusFilterEnabled =>
      AppSession.instance.profile?.role == UserRole.materialTaminotchi;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      initialIndex: widget.initialBarcode.trim().isEmpty ? 0 : 1,
      vsync: this,
    )..addListener(_handleTabChanged);
    _future = widget.groupScopeReady
        ? _load()
        : Future.value(const _RawMaterialAssignmentData.empty());
    _scheduleInitialBarcodeLookup();
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AdminRawMaterialAssignmentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialBarcode.trim() != widget.initialBarcode.trim()) {
      _initialBarcodeHandled = false;
      if (widget.initialBarcode.trim().isNotEmpty) {
        _tabController.animateTo(1);
      }
    }
    if (!oldWidget.groupScopeReady && widget.groupScopeReady) {
      _future = _load();
    }
    _scheduleInitialBarcodeLookup();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.groupScopeReady) {
      return _MaterialGroupScopeMissingState(
        bottomPadding: widget.bottomPadding,
      );
    }
    return FutureBuilder<_RawMaterialAssignmentData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: AppLoadingIndicator());
        }
        if (snapshot.hasError) {
          return AppRetryState(
            onRetry: () async {
              setState(() => _future = _load());
            },
          );
        }
        final data = snapshot.data!;
        return ColoredBox(
          color: AppTheme.shellStart(context),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Ro‘yxatdan'),
                  Tab(text: 'QR orqali'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildManualTab(data),
                    _buildQrTab(data),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
