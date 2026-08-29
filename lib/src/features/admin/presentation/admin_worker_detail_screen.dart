import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/timers/retry_after_countdown.dart';
import '../../../core/widgets/buttons/app_action_button_styles.dart';
import '../../../core/widgets/display/app_detail_field.dart';
import '../../../core/widgets/display/app_status_chip.dart';
import '../../../core/widgets/lists/app_segment_surface_card.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../../shared/presentation/widgets/profile_info_chip.dart';
import '../../chat/models/chat_models.dart';
import '../../chat/presentation/widgets/chat_profile_action_button.dart';
import '../logic/canonical_apparatus_display.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_profile_avatar.dart';
import 'widgets/admin_warehouse_assignment_editor.dart';

part 'admin_worker_detail_screen__AdminWorkerDetailScreenState_methods_01.dart';
part 'admin_worker_detail_screen_helpers_part_01.dart';
part 'admin_worker_detail_screen_widgets_part_02.dart';

const double _workerDetailPanelGap = 4;
const double _workerDetailFieldRadius = 14;

class _AdminWorkerDetailScreenState extends State<AdminWorkerDetailScreen> {
  AdminWorkerDetail? _detail;
  AdminWorkerProfileDetail? _profileDetail;
  List<AdminApparatus> _apparatus = const <AdminApparatus>[];
  Object? _profileDetailError;
  Object? _loadError;
  bool _loading = true;
  bool _profileLoading = false;
  bool _savingPhone = false;
  bool _regeneratingCode = false;
  bool _adminPanelExpanded = false;
  bool _changed = false;
  List<String> _assignedWarehouses = const <String>[];
  late final RetryAfterCountdown _retryAfter;
  int get _retryAfterSec => _retryAfter.seconds;

  String get _workerId => widget.entry.id.trim();
  bool get _isQolipchi =>
      widget.entry.kind == AdminUserKind.qolipchi ||
      widget.entry.principalRole == UserRole.qolipchi;
  bool get _isSystemUser =>
      widget.entry.kind == AdminUserKind.qolipchi ||
      widget.entry.kind == AdminUserKind.boyoqchi;
  bool get _warehouseManagementEnabled => _isQolipchi && !widget.readOnly;

  @override
  void initState() {
    super.initState();
    _retryAfter = RetryAfterCountdown(onChanged: _refreshRetryAfter);
    unawaited(_reload());
  }

  @override
  void dispose() {
    _retryAfter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final detail = _detail ??
        AdminWorkerDetail(
          id: _workerId,
          name: widget.entry.name,
          phone:
              _loading ? l10n.adminText('detail.loading') : widget.entry.phone,
          avatarUrl: '',
          level: widget.entry.roleLabel,
          code: _loading ? l10n.adminText('detail.loading') : '',
          codeLocked: false,
          codeRetryAfterSec: _retryAfterSec,
        );
    final warehouseEditor = _warehouseManagementEnabled
        ? AdminWarehouseAssignmentEditor(
            assignedWarehouses: _assignedWarehouses,
            principalRole: UserRole.qolipchi,
            principalRef: _workerId,
            displayName: detail.name,
            reloadAssignedWarehouses: _loadAssignedWarehouses,
            onChanged: (warehouses) {
              _changed = true;
              if (mounted) {
                setState(() => _assignedWarehouses = warehouses);
              }
            },
            assignedMessage: l10n.adminText('detail.warehouse_scope'),
            chipKeyPrefix: 'admin-qolipchi-detail-warehouse-',
            addButtonKey: 'admin-qolipchi-detail-add-warehouse',
            warehousesLoader: widget.warehousesLoader,
            warehouseAssigner: widget.warehouseAssigner,
            warehouseUnassigner: widget.warehouseUnassigner,
            buttonRadius: _workerDetailFieldRadius,
          )
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_changed);
      },
      child: AppShell(
        title: l10n.adminText('profile.title'),
        subtitle: '',
        nativeTopBar: true,
        nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
        contentPadding: EdgeInsets.zero,
        bottom: const AdminDock(activeTab: AdminDockTab.user),
        child: ColoredBox(
          color: AppTheme.shellStart(context),
          child: ListView(
            key: const ValueKey('admin-worker-detail-scroll'),
            padding: const EdgeInsets.fromLTRB(
              _workerDetailPanelGap,
              _workerDetailPanelGap,
              _workerDetailPanelGap,
              116,
            ),
            children: [
              AppSegmentSurfaceCard(
                padding: EdgeInsets.zero,
                child: _WorkerProfileExpandableCard(
                  detail: detail,
                  readOnly: widget.readOnly,
                  chatTarget: widget.chatTarget,
                  warehouseManagementEnabled: _warehouseManagementEnabled,
                  assignedWarehouses: _assignedWarehouses,
                  warehouseEditor: warehouseEditor,
                  statusLabel: _loading
                      ? l10n.adminText('detail.loading')
                      : _loadError != null
                          ? l10n.adminText('detail.error')
                          : l10n.adminText('detail.ready'),
                  expanded: _adminPanelExpanded,
                  savingPhone: _savingPhone,
                  regeneratingCode: _regeneratingCode,
                  onExpandedChanged: (expanded) {
                    setState(() => _adminPanelExpanded = expanded);
                  },
                  onSavePhone: _savePhone,
                  onRegenerateCode: _regenerateCode,
                  onCopyCode: _copyCode,
                ),
              ),
              if (!_isSystemUser) ...[
                const SizedBox(height: 12),
                _WorkerAssignmentSummaryCard(
                  detail: _profileDetail,
                  apparatus: _apparatus,
                  loading: _profileLoading,
                  error: _profileDetailError,
                  onRetry: _reloadProfileDetail,
                ),
              ],
              if (!widget.readOnly && !_isSystemUser) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  style: appOutlinedActionButtonStyle(
                    borderRadius: _workerDetailFieldRadius,
                  ),
                  onPressed: () => Navigator.of(context).pushNamed(
                    AppRoutes.adminWorkerProfileDetail,
                    arguments: widget.entry,
                  ),
                  child: Text(l10n.adminText('detail.worker_activity')),
                ),
              ],
              if (_loadError != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  style: appOutlinedActionButtonStyle(
                    borderRadius: _workerDetailFieldRadius,
                  ),
                  onPressed: _reload,
                  child: Text(l10n.adminText('detail.reload')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
