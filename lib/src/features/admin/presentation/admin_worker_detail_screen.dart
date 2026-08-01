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
import '../../../core/widgets/lists/app_segment_surface_card.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../../shared/presentation/widgets/profile_info_chip.dart';
import '../../chat/models/chat_models.dart';
import '../../chat/presentation/widgets/chat_profile_action_button.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_profile_avatar.dart';
import 'widgets/admin_warehouse_assignment_editor.dart';

const double _workerDetailPanelGap = 4;
const double _workerDetailFieldRadius = 14;

typedef AdminWorkerDetailLoader = Future<AdminWorkerDetail> Function(
  AdminUserListEntry entry,
);

typedef AdminWorkerProfileDetailLoader =
    Future<AdminWorkerProfileDetail> Function(AdminUserListEntry entry);

class AdminWorkerDetailScreen extends StatefulWidget {
  const AdminWorkerDetailScreen({
    super.key,
    required this.entry,
    this.readOnly = false,
    this.chatTarget,
    this.detailLoader,
    this.profileDetailLoader,
    this.warehousesLoader,
    this.warehouseAssignmentsLoader,
    this.warehouseAssigner,
    this.warehouseUnassigner,
  });

  final AdminUserListEntry entry;
  final bool readOnly;
  final ChatDirectoryEntry? chatTarget;
  final AdminWorkerDetailLoader? detailLoader;
  final AdminWorkerProfileDetailLoader? profileDetailLoader;
  final Future<List<AdminWarehouse>> Function()? warehousesLoader;
  final Future<List<AdminWarehouseAssignment>> Function()?
      warehouseAssignmentsLoader;
  final AdminWarehouseEditorAssigner? warehouseAssigner;
  final AdminWarehouseEditorUnassigner? warehouseUnassigner;

  @override
  State<AdminWorkerDetailScreen> createState() =>
      _AdminWorkerDetailScreenState();
}

class _AdminWorkerDetailScreenState extends State<AdminWorkerDetailScreen> {
  AdminWorkerDetail? _detail;
  AdminWorkerProfileDetail? _profileDetail;
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

  Future<AdminWorkerProfileDetail> _loadProfileDetail() {
    final loadProfileDetail = widget.profileDetailLoader;
    if (loadProfileDetail != null) {
      return loadProfileDetail(widget.entry);
    }
    return MobileApi.instance.adminWorkerProfileDetail(_workerId);
  }

  Future<void> _reloadProfileDetail() async {
    if (_isSystemUser) {
      return;
    }
    if (mounted) {
      setState(() {
        _profileLoading = true;
        _profileDetailError = null;
      });
    }
    try {
      final profileDetail = await _loadProfileDetail().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Ish faoliyati yuklash vaqti tugadi'),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _profileDetail = profileDetail;
        _profileDetailError = null;
        _profileLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profileDetailError = error;
        _profileLoading = false;
      });
    }
  }

  Future<List<String>> _loadAssignedWarehouses() async {
    final loadAssignments = widget.warehouseAssignmentsLoader;
    final assignments = loadAssignments == null
        ? await MobileApi.instance.adminWarehouseAssignments()
        : await loadAssignments();
    final normalizedRef = _workerId.toLowerCase();
    return normalizeAdminWarehouseNames(
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
      _profileDetail = null;
      _profileDetailError = null;
      _profileLoading = !_isSystemUser;
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
      if (!_isSystemUser) {
        await _reloadProfileDetail();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error;
        _loading = false;
        _profileDetailError = _isSystemUser ? null : error;
        _profileLoading = false;
      });
    }
  }

  Future<bool> _savePhone(AdminWorkerDetail detail, String phone) async {
    final trimmedPhone = phone.trim();
    if (trimmedPhone.isEmpty) {
      return false;
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
        return true;
      }
      _changed = true;
      setState(() {
        _detail = detail.copyWith(phone: updatedPhone);
      });
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Telefon saqlanmadi: $error')));
      return false;
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
            assignedMessage: 'Qolipchi faqat shu omborlar bilan ishlaydi.',
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
                  chatTarget: widget.chatTarget,
                  warehouseManagementEnabled: _warehouseManagementEnabled,
                  assignedWarehouses: _assignedWarehouses,
                  warehouseEditor: warehouseEditor,
                  statusLabel: _loading
                      ? 'Yuklanmoqda'
                      : _loadError != null
                          ? 'Xato'
                          : 'Tayyor',
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

class _WorkerAssignmentSummaryCard extends StatelessWidget {
  const _WorkerAssignmentSummaryCard({
    required this.detail,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final AdminWorkerProfileDetail? detail;
  final bool loading;
  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading && detail == null) {
      return const AppSegmentSurfaceCard(
        key: ValueKey('admin-worker-detail-activity-summary'),
        child: Row(
          children: [
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Ish faoliyati yuklanmoqda...'),
          ],
        ),
      );
    }

    if (error != null && detail == null) {
      return AppSegmentSurfaceCard(
        key: const ValueKey('admin-worker-detail-activity-summary'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ish faoliyati yuklanmadi',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => onRetry(),
              child: const Text('Qayta urinish'),
            ),
          ],
        ),
      );
    }

    final groups = detail?.assignedGroups ?? const <AdminWorkerGroup>[];
    return AppSegmentSurfaceCard(
      key: const ValueKey('admin-worker-detail-activity-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ish faoliyati',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          if (groups.isEmpty)
            const _WorkerAssignmentSummaryLine(
              label: 'Aparat',
              value: 'Aparat biriktirilmagan',
            )
          else
            for (var index = 0; index < groups.length; index++) ...[
              if (index > 0) const Divider(height: 20),
              _WorkerAssignmentSummaryLine(
                label: 'Aparat',
                value: _workerGroupSummary(groups[index]),
              ),
            ],
        ],
      ),
    );
  }
}

class _WorkerAssignmentSummaryLine extends StatelessWidget {
  const _WorkerAssignmentSummaryLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value.trim().isEmpty ? 'Kiritilmagan' : value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

String _workerGroupSummary(AdminWorkerGroup group) {
  final apparatus = group.apparatus.trim();
  final schedule = [
    if (group.groupCode.trim().isNotEmpty) 'Guruh ${group.groupCode.trim()}',
    if (group.shift.trim().isNotEmpty) group.shift.trim(),
    if (group.startTime.trim().isNotEmpty && group.endTime.trim().isNotEmpty)
      '${group.startTime.trim()}–${group.endTime.trim()}',
    if (group.workDaysPerWeek > 0) '${group.workDaysPerWeek} kun/hafta',
  ];
  return [apparatus, ...schedule]
      .where((item) => item.isNotEmpty)
      .join(' • ');
}

class _WorkerProfileExpandableCard extends StatelessWidget {
  const _WorkerProfileExpandableCard({
    required this.detail,
    required this.readOnly,
    required this.chatTarget,
    required this.warehouseManagementEnabled,
    required this.assignedWarehouses,
    required this.warehouseEditor,
    required this.statusLabel,
    required this.expanded,
    required this.savingPhone,
    required this.regeneratingCode,
    required this.onExpandedChanged,
    required this.onSavePhone,
    required this.onRegenerateCode,
    required this.onCopyCode,
  });

  final AdminWorkerDetail detail;
  final bool readOnly;
  final ChatDirectoryEntry? chatTarget;
  final bool warehouseManagementEnabled;
  final List<String> assignedWarehouses;
  final Widget? warehouseEditor;
  final String statusLabel;
  final bool expanded;
  final bool savingPhone;
  final bool regeneratingCode;
  final ValueChanged<bool> onExpandedChanged;
  final Future<bool> Function(AdminWorkerDetail detail, String phone)
      onSavePhone;
  final Future<void> Function() onRegenerateCode;
  final Future<void> Function(String code) onCopyCode;

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
                    if (chatTarget != null)
                      ChatProfileActionButton(
                        key: const ValueKey(
                          'admin-worker-detail-chat-action',
                        ),
                        target: chatTarget!,
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
                    warehouseEditor: warehouseEditor,
                    onSavePhone: onSavePhone,
                    onRegenerateCode: onRegenerateCode,
                    onCopyCode: onCopyCode,
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
    required this.warehouseEditor,
    required this.onSavePhone,
    required this.onRegenerateCode,
    required this.onCopyCode,
  });

  final AdminWorkerDetail detail;
  final bool savingPhone;
  final bool regeneratingCode;
  final Widget? warehouseEditor;
  final Future<bool> Function(AdminWorkerDetail detail, String phone)
      onSavePhone;
  final Future<void> Function() onRegenerateCode;
  final Future<void> Function(String code) onCopyCode;

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
        if (warehouseEditor != null) ...[
          const SizedBox(height: 18),
          warehouseEditor!,
        ],
      ],
    );
  }
}

class _WorkerPhoneInlineField extends StatefulWidget {
  const _WorkerPhoneInlineField({
    required this.detail,
    required this.savingPhone,
    required this.onSavePhone,
  });

  final AdminWorkerDetail detail;
  final bool savingPhone;
  final Future<bool> Function(AdminWorkerDetail detail, String phone)
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
    final saved = await widget.onSavePhone(widget.detail, _controller.text);
    if (mounted && saved) {
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
