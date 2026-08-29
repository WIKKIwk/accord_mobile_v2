import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/print_service.dart';
import '../../admin/presentation/admin_progress_qr_scan_screen.dart';
import '../../admin/presentation/progress_printer_picker.dart';
import '../../admin/presentation/widgets/admin_drawer_navigation.dart';
import 'widgets/aparatchi_dock.dart';
import 'widgets/aparatchi_navigation_drawer.dart';

part 'aparatchi_paddon_detail_screen__AparatchiPaddonDetailScreenState_methods_01.dart';
part 'aparatchi_paddon_detail_screen__AparatchiPaddonDetailScreenState_methods_02.dart';
part 'aparatchi_paddon_detail_screen_models_part_01.dart';

class _AparatchiPaddonDetailScreenState
    extends State<AparatchiPaddonDetailScreen> {
  late Future<AdminPaddonSnapshot> _future;
  final _selectionListKey = GlobalKey();
  final Set<String> _selectedAvailableBatchIds = <String>{};
  final Set<String> _selectedAssignedBatchIds = <String>{};
  bool _busy = false;
  bool _printingQr = false;
  bool _selectionMode = false;
  _PaddonEditMode _editMode = _PaddonEditMode.add;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Set<String> get _selectedBatchIds => _editMode == _PaddonEditMode.add
      ? _selectedAvailableBatchIds
      : _selectedAssignedBatchIds;

  IconData get _editModeActionIcon => _editMode == _PaddonEditMode.add
      ? Icons.playlist_add_rounded
      : Icons.playlist_remove_rounded;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: widget.code,
      subtitle: context.l10n.productionText('worker.paddon.detail.subtitle'),
      nativeTopBar: true,
      drawer: AparatchiNavigationDrawer(
        selectedIndex: 2,
        selectedRouteName: AppRoutes.apparatusPaddons,
        onNavigate: (routeName) =>
            AdminDrawerNavigation.openRoute(context, routeName),
      ),
      bottom: const AparatchiDock(activeTab: null),
      contentPadding: EdgeInsets.zero,
      child: ColoredBox(
        color: AppTheme.shellStart(context),
        child: _buildBody(context),
      ),
    );
  }
}
