import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/timers/retry_after_countdown.dart';
import '../../../core/widgets/buttons/app_action_button_styles.dart';
import '../../../core/widgets/display/app_detail_field.dart';
import '../../../core/widgets/display/app_status_chip.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/lists/app_segment_surface_card.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../../shared/presentation/widgets/profile_info_chip.dart';
import '../../chat/models/chat_models.dart';
import '../../chat/presentation/widgets/chat_profile_action_button.dart';
import 'dart:async';

import 'widgets/admin_aparatchi_apparatus_card.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_profile_avatar.dart';
import 'widgets/admin_warehouse_assignment_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'admin_customer_detail_screen__AdminCustomerDetailScreenState_methods_01.dart';
part 'admin_customer_detail_screen_declarations_part_01.dart';
part 'admin_customer_detail_screen_widgets_part_02.dart';
part 'admin_customer_detail_screen_widgets_part_03.dart';
part 'admin_customer_detail_screen_widgets_part_04.dart';

const double _customerDetailPanelGap = 4;
const double _customerDetailButtonRadius = 14;

class _AdminCustomerDetailScreenState extends State<AdminCustomerDetailScreen> {
  AdminCustomerDetail? _detail;
  Object? _loadError;
  bool _loading = true;
  bool _savingPhone = false;
  bool _regeneratingCode = false;
  bool _removing = false;
  bool _addingItem = false;
  bool _editingMaterialItemGroups = false;
  bool _adminPanelExpanded = false;
  String? _removingItemCode;
  bool _changed = false;
  late final RetryAfterCountdown _retryAfter;
  int get _retryAfterSec => _retryAfter.seconds;

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
    final screenTitle = widget.title == 'Profil'
        ? l10n.adminText('profile.title')
        : widget.title;
    final profileSubtitle = widget.profileSubtitle == 'Haridor profili'
        ? l10n.adminText('detail.customer_profile')
        : widget.profileSubtitle;
    final namelessLabel = widget.namelessLabel == 'Nomsiz haridor'
        ? l10n.adminText('detail.nameless_customer')
        : widget.namelessLabel;
    final AdminCustomerDetail detail = _detail ??
        AdminCustomerDetail(
          ref: widget.customerRef,
          name: _loading
              ? l10n.adminText('detail.loading')
              : widget.emptyName == 'Customer'
                  ? l10n.adminText('detail.customer')
                  : widget.emptyName,
          phone: _loading
              ? l10n.adminText('detail.loading')
              : l10n.adminText('profile.entered'),
          avatarUrl: '',
          code: _loading
              ? l10n.adminText('detail.loading')
              : l10n.adminText('profile.not_generated'),
          codeLocked: false,
          codeRetryAfterSec: _retryAfterSec,
          assignedItems: const [],
        );
    final materialWarehouseEditor =
        widget.isMaterialTaminotchi && _detail != null
            ? AdminWarehouseAssignmentEditor(
                assignedWarehouses: detail.assignedWarehouses,
                principalRole: UserRole.materialTaminotchi,
                principalRef: detail.ref,
                displayName: detail.name,
                reloadAssignedWarehouses: () async =>
                    (await _loadDetail()).assignedWarehouses,
                onChanged: (warehouses) {
                  _changed = true;
                  if (mounted) {
                    setState(() {
                      _detail = _detail?.copyWith(
                        assignedWarehouses: warehouses,
                      );
                    });
                  }
                },
                assignedMessage: l10n.adminText(
                  'detail.material_scope_message',
                ),
                chipKeyPrefix: 'admin-material-detail-warehouse-',
                addButtonKey: 'admin-material-detail-add-warehouse',
                warehousesLoader: widget.materialWarehousesLoader,
                warehouseAssigner: widget.materialWarehouseAssigner,
                warehouseUnassigner: widget.materialWarehouseUnassigner,
                buttonRadius: _customerDetailButtonRadius,
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
        title: screenTitle,
        subtitle: '',
        nativeTopBar: true,
        nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
        contentPadding: EdgeInsets.zero,
        bottom: const AdminDock(activeTab: AdminDockTab.user),
        child: ListView(
          key: const ValueKey('admin-customer-detail-scroll'),
          padding: const EdgeInsets.fromLTRB(
            _customerDetailPanelGap,
            _customerDetailPanelGap,
            _customerDetailPanelGap,
            116,
          ),
          children: [
            AppSegmentSurfaceCard(
              padding: EdgeInsets.zero,
              child: _AdminCustomerDetailCard(
                detail: detail,
                statusLabel: _loading
                    ? l10n.adminText('detail.loading')
                    : _loadError != null
                        ? l10n.adminText('detail.error')
                        : _detail == null
                            ? l10n.adminText('detail.empty')
                            : l10n.adminText('detail.ready'),
                profileSubtitle: profileSubtitle,
                namelessLabel: namelessLabel,
                customerManagementEnabled: widget.customerManagementEnabled,
                itemManagementEnabled: widget.itemManagementEnabled,
                removeEnabled: widget.removeEnabled,
                isMaterialTaminotchi: widget.isMaterialTaminotchi,
                chatTarget: widget.chatTarget,
                warehouseEditor: materialWarehouseEditor,
                expanded:
                    widget.customerManagementEnabled && _adminPanelExpanded,
                savingPhone: _savingPhone,
                regeneratingCode: _regeneratingCode,
                removing: _removing,
                addingItem: _addingItem,
                editingMaterialItemGroups: _editingMaterialItemGroups,
                removingItemCode: _removingItemCode,
                onExpandedChanged: (expanded) {
                  setState(() => _adminPanelExpanded = expanded);
                },
                onSavePhone: _savePhone,
                onAddItem: _addItem,
                onRemoveItem: _removeItem,
                onEditMaterialItemGroups: _editMaterialItemGroups,
                onRegenerateCode: _regenerateCode,
                onCopyCode: _copyCode,
                onRemove: _removeCustomer,
              ),
            ),
            if (widget.customerManagementEnabled) ...[
              const SizedBox(height: 12),
              AdminAparatchiApparatusCard(
                customerRef: widget.customerRef,
                materialTaminotchi: widget.isMaterialTaminotchi,
                onChanged: () => _changed = true,
              ),
            ],
            if (_loadError != null) ...[
              const SizedBox(height: 12),
              AppRetryState(onRetry: _reload, padding: EdgeInsets.zero),
            ],
          ],
        ),
      ),
    );
  }
}
