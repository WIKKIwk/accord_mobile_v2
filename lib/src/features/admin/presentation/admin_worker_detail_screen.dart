import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/timers/retry_after_countdown.dart';
import '../../../core/widgets/buttons/app_action_button_styles.dart';
import '../../../core/widgets/display/app_detail_field.dart';
import '../../../core/widgets/display/app_status_chip.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/lists/app_segment_surface_card.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../../shared/presentation/widgets/profile_info_chip.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_profile_avatar.dart';
import 'widgets/admin_warehouse_picker_sheet.dart';

const double _workerDetailPanelGap = 4;
const double _workerDetailFieldRadius = 14;

typedef AdminWorkerDetailLoader = Future<AdminWorkerDetail> Function(
  AdminUserListEntry entry,
);
typedef AdminWorkerWarehouseAssigner = Future<AdminWarehouseAssignment>
    Function({
  required String warehouse,
  required UserRole principalRole,
  required String principalRef,
  required String displayName,
});
typedef AdminWorkerWarehouseUnassigner = Future<AdminWarehouseAssignment>
    Function({
  required String warehouse,
  required UserRole principalRole,
  required String principalRef,
});

class AdminWorkerDetailScreen extends StatefulWidget {
  const AdminWorkerDetailScreen({
    super.key,
    required this.entry,
    this.readOnly = false,
    this.detailLoader,
    this.warehousesLoader,
    this.warehouseAssignmentsLoader,
    this.warehouseAssigner,
    this.warehouseUnassigner,
  });

  final AdminUserListEntry entry;
  final bool readOnly;
  final AdminWorkerDetailLoader? detailLoader;
  final Future<List<AdminWarehouse>> Function()? warehousesLoader;
  final Future<List<AdminWarehouseAssignment>> Function()?
      warehouseAssignmentsLoader;
  final AdminWorkerWarehouseAssigner? warehouseAssigner;
  final AdminWorkerWarehouseUnassigner? warehouseUnassigner;

  @override
  State<AdminWorkerDetailScreen> createState() =>
      _AdminWorkerDetailScreenState();
}

class _AdminWorkerDetailScreenState extends State<AdminWorkerDetailScreen> {
  AdminWorkerDetail? _detail;
  Object? _loadError;
  bool _loading = true;
  bool _savingPhone = false;
  bool _regeneratingCode = false;
  bool _addingWarehouse = false;
  String? _removingWarehouse;
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

  void _refreshRetryAfter() {
    if (mounted) {
      setState(() {});
    }
  }

  void _setRetryAfter(int seconds) => _retryAfter.set(seconds);

  Future<AdminWorkerDetail> _loadDetail() async {
    final loadDetail = widget.detailLoader;
    if (loadDetail != null) {
      return loadDetail(widget.entry);
    }
    if (_isSystemUser) {
      final user = await MobileApi.instance.adminSystemUserDetail(_workerId);
      return AdminWorkerDetail(
        id: user.id,
        name: user.name,
        phone: user.phone,
        avatarUrl: user.avatarUrl,
        level: widget.entry.roleLabel,
        code: user.code,
        codeLocked: user.codeLocked,
        codeRetryAfterSec: user.codeRetryAfterSec,
      );
    }
    return MobileApi.instance.adminWorkerDetail(_workerId);
  }

  Future<List<String>> _loadAssignedWarehouses() async {
    final loadAssignments = widget.warehouseAssignmentsLoader;
    final assignments = loadAssignments == null
        ? await MobileApi.instance.adminWarehouseAssignments()
        : await loadAssignments();
    final normalizedRef = _workerId.toLowerCase();
    return _normalizedWorkerWarehouseNames(
      assignments
          .where(
            (assignment) =>
                assignment.principalRole == UserRole.qolipchi &&
                assignment.principalRef.trim().toLowerCase() == normalizedRef,
          )
          .map((assignment) => assignment.warehouse),
    );
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final detail = await _loadDetail().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Profil yuklash vaqti tugadi'),
      );
      final assignedWarehouses = _warehouseManagementEnabled
          ? await _loadAssignedWarehouses().timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw Exception('Omborlar yuklash vaqti tugadi'),
            )
          : const <String>[];
      if (!mounted) {
        return;
      }
      _setRetryAfter(detail.codeRetryAfterSec);
      setState(() {
        _detail = detail;
        _assignedWarehouses = assignedWarehouses;
        _loadError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _savePhone(AdminWorkerDetail detail, String phone) async {
    final trimmedPhone = phone.trim();
    if (trimmedPhone.isEmpty) {
      return;
    }

    setState(() => _savingPhone = true);
    try {
      final updatedPhone = _isSystemUser
          ? (await MobileApi.instance.adminUpdateSystemUserPhone(
              id: detail.id,
              role: widget.entry.principalRole,
              name: detail.name,
              phone: trimmedPhone,
            ))
              .phone
          : (await MobileApi.instance.adminUpdateWorkerPhone(
              id: detail.id,
              phone: trimmedPhone,
            ))
              .phone;
      if (!mounted) {
        return;
      }
      _changed = true;
      setState(() {
        _detail = detail.copyWith(phone: updatedPhone);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Telefon saqlanmadi: $error')));
    } finally {
      if (mounted) {
        setState(() => _savingPhone = false);
      }
    }
  }

  Future<void> _regenerateCode() async {
    setState(() => _regeneratingCode = true);
    try {
      final updated = _isSystemUser
          ? await MobileApi.instance.adminRegenerateSystemUserCode(_workerId)
          : null;
      final detail = updated == null
          ? await MobileApi.instance.adminRegenerateWorkerCode(_workerId)
          : AdminWorkerDetail(
              id: updated.id,
              name: updated.name,
              phone: updated.phone,
              avatarUrl: updated.avatarUrl,
              level: widget.entry.roleLabel,
              code: updated.code,
              codeLocked: updated.codeLocked,
              codeRetryAfterSec: updated.codeRetryAfterSec,
            );
      if (!mounted) {
        return;
      }
      _changed = true;
      _setRetryAfter(detail.codeRetryAfterSec);
      setState(() => _detail = detail);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Code yangilanmadi: $error')));
    } finally {
      if (mounted) {
        setState(() => _regeneratingCode = false);
      }
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Code nusxalandi')));
  }

  Future<void> _addWarehouse() async {
    final detail = _detail;
    if (detail == null || !_warehouseManagementEnabled || _addingWarehouse) {
      return;
    }
    setState(() => _addingWarehouse = true);
    try {
      final loadWarehouses = widget.warehousesLoader;
      final warehouses = loadWarehouses == null
          ? await MobileApi.instance.adminWarehouses(limit: 500)
          : await loadWarehouses();
      final assignedKeys = _assignedWarehouses
          .map((warehouse) => warehouse.trim().toLowerCase())
          .toSet();
      final available = _normalizedWorkerWarehouseNames(
        warehouses
            .where((warehouse) => !warehouse.isGroup)
            .map((warehouse) => warehouse.warehouse)
            .where(
              (warehouse) =>
                  !assignedKeys.contains(warehouse.trim().toLowerCase()),
            ),
      );
      if (!mounted) {
        return;
      }
      if (available.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biriktirilmagan ombor topilmadi')),
        );
        return;
      }
      final warehouse = await showAdminWarehousePicker(
        context,
        available: available,
      );
      if (!mounted || warehouse == null) {
        return;
      }
      final assignWarehouse =
          widget.warehouseAssigner ?? MobileApi.instance.adminAssignWarehouse;
      final assignment = await assignWarehouse(
        warehouse: warehouse,
        principalRole: UserRole.qolipchi,
        principalRef: _workerId,
        displayName: detail.name,
      );
      final updated = await _loadAssignedWarehouses();
      final assignmentConfirmed = updated.any(
        (item) =>
            item.trim().toLowerCase() ==
            assignment.warehouse.trim().toLowerCase(),
      );
      if (!assignmentConfirmed) {
        throw const MobileApiException(
          code: 'warehouse_assignment_not_confirmed',
          message: 'Server ombor biriktirilganini tasdiqlamadi',
        );
      }
      _changed = true;
      if (mounted) {
        setState(() => _assignedWarehouses = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${assignment.warehouse} biriktirildi')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ombor biriktirilmadi: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _addingWarehouse = false);
      }
    }
  }

  Future<void> _removeWarehouse(String warehouse) async {
    final detail = _detail;
    if (detail == null ||
        !_warehouseManagementEnabled ||
        _removingWarehouse != null) {
      return;
    }
    final confirmed = await showM3ConfirmDialog(
      context: context,
      title: 'Omborni uzish',
      message: '$warehouse omborini ${detail.name} profilidan uzaymi?',
      cancelLabel: 'Yo‘q',
      confirmLabel: 'Ha',
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _removingWarehouse = warehouse);
    try {
      final unassignWarehouse = widget.warehouseUnassigner ??
          MobileApi.instance.adminUnassignWarehouse;
      await unassignWarehouse(
        warehouse: warehouse,
        principalRole: UserRole.qolipchi,
        principalRef: _workerId,
      );
      final updated = await _loadAssignedWarehouses();
      final assignmentStillExists = updated.any(
        (item) => item.trim().toLowerCase() == warehouse.trim().toLowerCase(),
      );
      if (assignmentStillExists) {
        throw const MobileApiException(
          code: 'warehouse_unassignment_not_confirmed',
          message: 'Server ombor uzilganini tasdiqlamadi',
        );
      }
      _changed = true;
      if (mounted) {
        setState(() => _assignedWarehouses = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$warehouse profildan uzildi')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ombor uzilmadi: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _removingWarehouse = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail ??
        AdminWorkerDetail(
          id: _workerId,
          name: widget.entry.name,
          phone: _loading ? 'Yuklanmoqda...' : widget.entry.phone,
          avatarUrl: '',
          level: widget.entry.roleLabel,
          code: _loading ? 'Yuklanmoqda...' : '',
          codeLocked: false,
          codeRetryAfterSec: _retryAfterSec,
        );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_changed);
      },
      child: AppShell(
        title: 'Profil',
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
                  warehouseManagementEnabled: _warehouseManagementEnabled,
                  assignedWarehouses: _assignedWarehouses,
                  statusLabel: _loading
                      ? 'Yuklanmoqda'
                      : _loadError != null
                          ? 'Xato'
                          : 'Tayyor',
                  expanded: _adminPanelExpanded,
                  savingPhone: _savingPhone,
                  regeneratingCode: _regeneratingCode,
                  addingWarehouse: _addingWarehouse,
                  removingWarehouse: _removingWarehouse,
                  onExpandedChanged: (expanded) {
                    setState(() => _adminPanelExpanded = expanded);
                  },
                  onSavePhone: _savePhone,
                  onRegenerateCode: _regenerateCode,
                  onCopyCode: _copyCode,
                  onAddWarehouse: _addWarehouse,
                  onRemoveWarehouse: _removeWarehouse,
                ),
              ),
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
                  child: const Text('Ish faoliyati tafsilotlari'),
                ),
              ],
              if (_loadError != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  style: appOutlinedActionButtonStyle(
                    borderRadius: _workerDetailFieldRadius,
                  ),
                  onPressed: _reload,
                  child: const Text('Qayta yuklash'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkerProfileExpandableCard extends StatelessWidget {
  const _WorkerProfileExpandableCard({
    required this.detail,
    required this.readOnly,
    required this.warehouseManagementEnabled,
    required this.assignedWarehouses,
    required this.statusLabel,
    required this.expanded,
    required this.savingPhone,
    required this.regeneratingCode,
    required this.addingWarehouse,
    required this.removingWarehouse,
    required this.onExpandedChanged,
    required this.onSavePhone,
    required this.onRegenerateCode,
    required this.onCopyCode,
    required this.onAddWarehouse,
    required this.onRemoveWarehouse,
  });

  final AdminWorkerDetail detail;
  final bool readOnly;
  final bool warehouseManagementEnabled;
  final List<String> assignedWarehouses;
  final String statusLabel;
  final bool expanded;
  final bool savingPhone;
  final bool regeneratingCode;
  final bool addingWarehouse;
  final String? removingWarehouse;
  final ValueChanged<bool> onExpandedChanged;
  final Future<void> Function(AdminWorkerDetail detail, String phone)
      onSavePhone;
  final Future<void> Function() onRegenerateCode;
  final Future<void> Function(String code) onCopyCode;
  final Future<void> Function() onAddWarehouse;
  final Future<void> Function(String warehouse) onRemoveWarehouse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final phone = detail.phone.trim();
    final level = detail.level.trim();
    final initials = _workerInitials(detail.name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 204,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                  top: 112, child: ColoredBox(color: scheme.surface)),
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 112,
                child: ColoredBox(color: Colors.black),
              ),
              Positioned(
                right: 14,
                top: 14,
                child: AppStatusChip(label: statusLabel),
              ),
              Positioned(
                left: 16,
                top: 74,
                child: AdminProfileAvatar(
                  avatarUrl: detail.avatarUrl,
                  fallbackText: initials,
                ),
              ),
              Positioned(
                left: 124,
                right: 16,
                top: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.name.trim().isEmpty
                          ? 'Nomsiz ishchi'
                          : detail.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      level.isEmpty ? 'Ishchi profili' : '$level profili',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ProfileInfoChip(
                      icon: Icons.phone_rounded,
                      label: phone.isEmpty ? 'Telefon kiritilmagan' : phone,
                    ),
                    ProfileInfoChip(
                      icon: Icons.badge_rounded,
                      label: level.isEmpty ? 'Daraja belgilanmagan' : level,
                    ),
                    if (warehouseManagementEnabled)
                      ProfileInfoChip(
                        icon: Icons.warehouse_outlined,
                        label: '${assignedWarehouses.length} ta ombor',
                      ),
                  ],
                ),
              ),
              if (!readOnly) ...[
                const SizedBox(width: 8),
                IconButton(
                  key: const ValueKey('admin-worker-detail-admin-toggle'),
                  tooltip:
                      expanded ? 'Boshqaruvni yopish' : 'Boshqaruvni ochish',
                  onPressed: () => onExpandedChanged(!expanded),
                  icon: AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !readOnly && expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _WorkerAdminPanel(
                    detail: detail,
                    savingPhone: savingPhone,
                    regeneratingCode: regeneratingCode,
                    warehouseManagementEnabled: warehouseManagementEnabled,
                    assignedWarehouses: assignedWarehouses,
                    addingWarehouse: addingWarehouse,
                    removingWarehouse: removingWarehouse,
                    onSavePhone: onSavePhone,
                    onRegenerateCode: onRegenerateCode,
                    onCopyCode: onCopyCode,
                    onAddWarehouse: onAddWarehouse,
                    onRemoveWarehouse: onRemoveWarehouse,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _WorkerAdminPanel extends StatelessWidget {
  const _WorkerAdminPanel({
    required this.detail,
    required this.savingPhone,
    required this.regeneratingCode,
    required this.warehouseManagementEnabled,
    required this.assignedWarehouses,
    required this.addingWarehouse,
    required this.removingWarehouse,
    required this.onSavePhone,
    required this.onRegenerateCode,
    required this.onCopyCode,
    required this.onAddWarehouse,
    required this.onRemoveWarehouse,
  });

  final AdminWorkerDetail detail;
  final bool savingPhone;
  final bool regeneratingCode;
  final bool warehouseManagementEnabled;
  final List<String> assignedWarehouses;
  final bool addingWarehouse;
  final String? removingWarehouse;
  final Future<void> Function(AdminWorkerDetail detail, String phone)
      onSavePhone;
  final Future<void> Function() onRegenerateCode;
  final Future<void> Function(String code) onCopyCode;
  final Future<void> Function() onAddWarehouse;
  final Future<void> Function(String warehouse) onRemoveWarehouse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(
          height: 1,
          color: scheme.outlineVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 14),
        Text(
          'Admin boshqaruv',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        const _WorkerDetailLabel('Telefon'),
        const SizedBox(height: 6),
        _WorkerPhoneInlineField(
          detail: detail,
          savingPhone: savingPhone,
          onSavePhone: onSavePhone,
        ),
        const SizedBox(height: 14),
        const _WorkerDetailLabel('Kirish kodi'),
        const SizedBox(height: 6),
        AppDetailField(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  detail.code.trim().isEmpty
                      ? 'Hali generatsiya qilinmagan'
                      : detail.code,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (detail.code.trim().isNotEmpty)
                IconButton(
                  onPressed: () => onCopyCode(detail.code),
                  icon: const Icon(Icons.content_copy_outlined),
                ),
              IconButton(
                onPressed: regeneratingCode || detail.codeLocked
                    ? null
                    : onRegenerateCode,
                icon: regeneratingCode
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        if (detail.codeRetryAfterSec > 0) ...[
          const SizedBox(height: 12),
          Text(
            'Keyingi code uchun ${detail.codeRetryAfterSec} soniya kuting.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (warehouseManagementEnabled) ...[
          const SizedBox(height: 18),
          Text('Biriktirilgan omborlar', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            assignedWarehouses.isEmpty
                ? 'Ombor biriktirilmagan.'
                : 'Qolipchi faqat shu omborlar bilan ishlaydi.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: assignedWarehouses.isEmpty
                  ? scheme.error
                  : scheme.onSurfaceVariant,
            ),
          ),
          if (assignedWarehouses.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final warehouse in assignedWarehouses)
                  InputChip(
                    key: ValueKey(
                      'admin-qolipchi-detail-warehouse-$warehouse',
                    ),
                    avatar: const Icon(Icons.warehouse_outlined, size: 17),
                    label: Text(warehouse),
                    deleteIcon: removingWarehouse == warehouse
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.close_rounded, size: 18),
                    onDeleted: removingWarehouse == null
                        ? () => onRemoveWarehouse(warehouse)
                        : null,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('admin-qolipchi-detail-add-warehouse'),
              style: appOutlinedActionButtonStyle(
                borderRadius: _workerDetailFieldRadius,
              ),
              onPressed: addingWarehouse ? null : onAddWarehouse,
              icon: addingWarehouse
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(
                addingWarehouse ? 'Yuklanmoqda...' : 'Ombor biriktirish',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

List<String> _normalizedWorkerWarehouseNames(Iterable<String> values) {
  final byKey = <String, String>{};
  for (final value in values) {
    final normalized = value.trim();
    if (normalized.isNotEmpty) {
      byKey.putIfAbsent(normalized.toLowerCase(), () => normalized);
    }
  }
  final result = byKey.values.toList(growable: false);
  result
      .sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
  return result;
}

class _WorkerPhoneInlineField extends StatefulWidget {
  const _WorkerPhoneInlineField({
    required this.detail,
    required this.savingPhone,
    required this.onSavePhone,
  });

  final AdminWorkerDetail detail;
  final bool savingPhone;
  final Future<void> Function(AdminWorkerDetail detail, String phone)
      onSavePhone;

  @override
  State<_WorkerPhoneInlineField> createState() =>
      _WorkerPhoneInlineFieldState();
}

class _WorkerPhoneInlineFieldState extends State<_WorkerPhoneInlineField> {
  late final TextEditingController _controller;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.detail.phone.trim());
  }

  @override
  void didUpdateWidget(covariant _WorkerPhoneInlineField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.detail.phone != widget.detail.phone) {
      _controller.text = widget.detail.phone.trim();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await widget.onSavePhone(widget.detail, _controller.text);
    if (mounted) {
      setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phone = widget.detail.phone.trim();
    return AppDetailField(
      child: Row(
        children: [
          Expanded(
            child: _editing
                ? TextField(
                    key: const ValueKey('admin-worker-detail-phone-input'),
                    controller: _controller,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: '+998901234567',
                    ),
                    style: theme.textTheme.titleMedium,
                    onSubmitted: (_) => _submit(),
                  )
                : Text(
                    phone.isEmpty ? 'Kiritilmagan' : phone,
                    style: theme.textTheme.titleMedium,
                  ),
          ),
          IconButton(
            key: const ValueKey('admin-worker-detail-phone-action'),
            tooltip: _editing
                ? 'Telefonni saqlash'
                : phone.isEmpty
                    ? 'Telefon raqami kiritish'
                    : 'Telefonni yangilash',
            onPressed: widget.savingPhone
                ? null
                : _editing
                    ? _submit
                    : () => setState(() => _editing = true),
            icon: widget.savingPhone
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_editing ? Icons.check_rounded : Icons.edit_rounded),
          ),
        ],
      ),
    );
  }
}

String _workerInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'I';
  }
  final first = parts.first.characters.first.toUpperCase();
  if (parts.length == 1) {
    return first;
  }
  return '$first${parts.last.characters.first.toUpperCase()}';
}

class _WorkerDetailLabel extends StatelessWidget {
  const _WorkerDetailLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.bodySmall);
  }
}
