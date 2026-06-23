import 'dart:async';
import 'dart:math' as math;

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/navigation/app_navigation_bar.dart';
import '../../../core/widgets/navigation/dock_gesture_overlay.dart';
import '../../../core/widgets/navigation/dock_system_bottom_inset.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../logic/production_map_pechat_rules.dart';
import '../models/production_map_models.dart';
import '../state/calculate_order_store.dart';
import 'widgets/admin_create_hub_sheet.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'admin_production_map_test_formula_widgets.dart';
part 'admin_production_map_test_helpers.dart';
part 'admin_production_map_test_sheet_widgets.dart';
part 'admin_production_map_test_node_edit_sheets.dart';
part 'admin_production_map_test_node_visual.dart';
part 'admin_production_map_test_painters.dart';
part 'admin_production_map_test_canvas_actions.dart';
part 'admin_production_map_test_canvas.dart';
part 'admin_production_map_test_definition_state.dart';
part 'admin_production_map_test_graph_state.dart';

const _productionMapDockHeight = 60.0;

class AdminProductionMapTestScreen extends StatefulWidget {
  const AdminProductionMapTestScreen({
    super.key,
    this.orderContext,
    this.savedMap,
    this.readOnly = false,
  });

  final ProductionMapOrderContext? orderContext;
  final ProductionMapDefinition? savedMap;
  final bool readOnly;

  @override
  State<AdminProductionMapTestScreen> createState() =>
      _AdminProductionMapTestScreenState();
}

class _AdminProductionMapTestScreenState
    extends State<AdminProductionMapTestScreen> {
  static const _nodeGap = 18.0;
  static const _nodeStepX = 280.0;
  static const _nodeStepY = 132.0;
  static const _minNodeX = -2400.0;
  static const _minNodeY = -1600.0;
  static const _maxNodeX = 6000.0;
  static const _maxNodeY = 6000.0;

  late final bool _orderMode;
  late final List<ProductionMapNode> nodes;
  late final List<ProductionMapEdge> edges;

  int _nextNodeIndex = 1;
  String? _connectingFromNodeID;
  String _connectingFromBranch = '';
  Offset? _connectionPreviewEnd;
  bool _savingMap = false;
  late String _orderNumber;
  CalculateOrderTemplate? _templateDraft;
  CalculateOrderTemplate? _lastSavedTemplate;
  List<AdminApparatusGroup> _apparatusGroups = const [];

  @override
  void initState() {
    super.initState();
    final savedMap = widget.savedMap;
    _orderMode = widget.orderContext != null ||
        (savedMap?.id.trim().startsWith('zakaz-') ?? false);
    nodes = savedMap != null
        ? List<ProductionMapNode>.from(savedMap.nodes)
        : _orderMode
            ? _orderFlowNodes(widget.orderContext!)
            : _defaultTestNodes();
    edges = savedMap != null
        ? List<ProductionMapEdge>.from(savedMap.edges)
        : _orderMode
            ? _orderFlowEdges()
            : _defaultTestEdges();
    _syncNextNodeIndexFromExistingNodes();
    _orderNumber = savedMap?.orderNumber.trim() ?? '';
    _templateDraft = widget.orderContext?.templateDraft;
    unawaited(_loadApparatusGroups());
  }

  void _updateScreenState(VoidCallback callback) {
    setState(callback);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final viewMetrics = MediaQueryData.fromView(View.of(context));
    final systemBottomInset = dockLayoutBottomInset(
      viewMetrics,
      thinGestureBottom: DockGestureOverlayScope.thinGestureBottomOf(context),
    );
    final dockHeight = appNavigationBarDockHeight(
      height: _productionMapDockHeight,
      systemBottomInset: systemBottomInset,
    );
    final fabBottom = math.max(
      0.0,
      appNavigationBarPrimaryButtonBottom(dockHeight: dockHeight) - dockHeight,
    );
    // System back (swipe) must also return the saved template to the caller.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop(_lastSavedTemplate);
        }
      },
      child: _buildShell(context, scheme, fabBottom),
    );
  }

  Widget _buildShell(
    BuildContext context,
    ColorScheme scheme,
    double fabBottom,
  ) {
    return AppShell(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          final nav = Navigator.of(context);
          if (nav.canPop()) {
            nav.pop(_lastSavedTemplate);
          } else {
            nav.pushNamedAndRemoveUntil(AppRoutes.adminHome, (route) => false);
          }
        },
      ),
      title: 'Production map test',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      actions: [
        if (_orderMode && !widget.readOnly)
          AppShellIconAction(
            key: const ValueKey('production-map-save'),
            icon:
                _savingMap ? Icons.hourglass_top_rounded : Icons.save_outlined,
            onTap: _saveMap,
          ),
      ],
      contentPadding: EdgeInsets.zero,
      animateOnEnter: false,
      bottom: const AdminDock(
        activeTab: AdminDockTab.home,
        showPrimaryFab: false,
      ),
      child: ColoredBox(
        color: scheme.surface,
        child: Stack(
          children: [
            Positioned.fill(
              child: _ProductionMapCanvas(
                readOnly: widget.readOnly,
                nodes: nodes,
                edges: edges,
                connectingFromNodeID: _connectingFromNodeID,
                connectingFromBranch: _connectingFromBranch,
                connectionPreviewEnd: _connectionPreviewEnd,
                onNodeTap: (node) => _editNode(nodes.indexOf(node)),
                onNodeDelete: (node) => _deleteNode(nodes.indexOf(node)),
                onNodeMoved: _moveNode,
                onConnectionStart: _startConnection,
                onConnectionUpdate: _updateConnectionPreview,
                onConnectionEnd: _finishConnection,
                onConnectionCancel: _cancelConnection,
                onEdgeDelete: _removeEdge,
              ),
            ),
            if (!widget.readOnly)
              Positioned(
                left: 10,
                bottom: fabBottom,
                child: AdminFabOverlayActionMenu(
                  actions: _mapToolActions(),
                  closedLabel: 'Element qo‘shish',
                  openLabel: 'Yopish',
                  closedIcon: Icons.add_rounded,
                  alignEnd: false,
                  columns: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
