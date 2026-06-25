import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/display/motion_widgets.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart' show AppRefreshIndicator;
import '../logic/admin_aparatchi_assignment.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_apparatus_scope_picker.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_shell.dart';
import 'widgets/admin_surface_tab_bar.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';

class AdminRolesScreen extends StatefulWidget {
  const AdminRolesScreen({super.key});

  @override
  State<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends State<AdminRolesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<_AdminRolesData> _future;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _future = _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_AdminRolesData> _load() async {
    final results = await Future.wait<Object>([
      MobileApi.instance.adminCapabilities(),
      MobileApi.instance.adminRoles(),
      MobileApi.instance.adminRoleAssignments(),
      MobileApi.instance.adminSettings(),
      MobileApi.instance.adminSuppliers(limit: 100),
      MobileApi.instance.adminCustomers(limit: 100),
      MobileApi.instance.adminWarehouses(parent: 'aparat - A', limit: 200),
    ]);
    return _AdminRolesData(
      capabilities: results[0] as List<AdminCapability>,
      roles: results[1] as List<AdminRoleDefinition>,
      assignments: results[2] as List<AdminRoleAssignment>,
      settings: results[3] as AdminSettings,
      suppliers: results[4] as List<AdminSupplier>,
      customers: results[5] as List<CustomerDirectoryEntry>,
      apparatus: results[6] as List<AdminWarehouse>,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _openRoleEditor(
    _AdminRolesData data, {
    AdminRoleDefinition? initialRole,
  }) async {
    final role = await showModalBottomSheet<AdminRoleDefinition>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) =>
          _AdminRoleEditorSheet(data: data, role: initialRole),
    );
    if (role == null || !mounted) {
      return;
    }
    try {
      final saved = await MobileApi.instance.adminUpsertRole(role);
      if (!mounted) {
        return;
      }
      setState(() {
        _future = Future<_AdminRolesData>.value(data.upsertRole(saved));
      });
      showAdminTopNotice(
        context,
        context.l10n.adminRoleSaved,
        icon: Icons.verified_user,
      );
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(
          context,
          context.l10n.adminRoleSaveFailed,
          icon: Icons.error,
        );
      }
    }
  }

  Future<void> _assignRole(
    _AdminRolesData data,
    _RolePrincipal principal,
  ) async {
    final assignment = await showModalBottomSheet<AdminRoleAssignment>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return _RoleAssignmentSheet(
          principal: principal,
          roles: data.roles,
          apparatus: data.apparatus,
          existingAssignment: data.assignmentForPrincipal(principal),
        );
      },
    );
    if (assignment == null || !mounted) {
      return;
    }
    try {
      final saved = await MobileApi.instance.adminUpsertRoleAssignment(
        assignment,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _future = Future<_AdminRolesData>.value(data.upsertAssignment(saved));
      });
      showAdminTopNotice(
        context,
        context.l10n.adminRoleAssigned,
        icon: Icons.assignment_turned_in_outlined,
      );
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(
          context,
          context.l10n.adminRoleAssignFailed,
          icon: Icons.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    return AdminShell(
      title: context.l10n.adminRolesTitle,
      selectedRouteName: AppRoutes.adminRoles,
      activeTab: AdminDockTab.settings,
      bottomDockFadeStrength: null,
      child: FutureBuilder<_AdminRolesData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: AppLoadingIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return AppRetryState(onRetry: _reload);
          }
          final data = snapshot.data!;
          return Column(
            children: [
              _AdminRoleTabs(controller: _tabController),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _RolesTab(
                      data: data,
                      bottomPadding: bottomPadding,
                      onRefresh: _reload,
                      onCreateRole: () => _openRoleEditor(data),
                      onEditRole: (role) =>
                          _openRoleEditor(data, initialRole: role),
                    ),
                    _AssignmentsTab(
                      data: data,
                      bottomPadding: bottomPadding,
                      onRefresh: _reload,
                      onAssign: (principal) => _assignRole(data, principal),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminRoleTabs extends StatelessWidget {
  const _AdminRoleTabs({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return AdminSurfaceTabBar(
      controller: controller,
      tabs: [
        Tab(height: 38, text: context.l10n.adminRolesTitle),
        Tab(height: 38, text: context.l10n.adminRolesAssignTab),
      ],
    );
  }
}

class _RolesTab extends StatefulWidget {
  const _RolesTab({
    required this.data,
    required this.bottomPadding,
    required this.onRefresh,
    required this.onCreateRole,
    required this.onEditRole,
  });

  final _AdminRolesData data;
  final double bottomPadding;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreateRole;
  final ValueChanged<AdminRoleDefinition> onEditRole;

  @override
  State<_RolesTab> createState() => _RolesTabState();
}

class _RolesTabState extends State<_RolesTab> {
  String? _expandedRoleId;

  @override
  Widget build(BuildContext context) {
    return AppRefreshIndicator(
      onRefresh: widget.onRefresh,
      allowRefreshOnShortContent: true,
      child: ListView(
        physics: const TopRefreshScrollPhysics(),
        padding: EdgeInsets.fromLTRB(12, 12, 12, widget.bottomPadding),
        children: [
          SmoothAppear(
            child: FilledButton.icon(
              onPressed: widget.onCreateRole,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.l10n.adminNewRole),
            ),
          ),
          const SizedBox(height: 12),
          M3SegmentSpacedColumn(
            children: [
              for (int index = 0; index < widget.data.roles.length; index++)
                _RoleDefinitionTile(
                  role: widget.data.roles[index],
                  capabilities: widget.data.capabilities,
                  expanded: _expandedRoleId == widget.data.roles[index].id,
                  onExpandedChanged: (expanded) {
                    setState(() {
                      _expandedRoleId =
                          expanded ? widget.data.roles[index].id : null;
                    });
                  },
                  onEdit: widget.data.roles[index].system
                      ? null
                      : () => widget.onEditRole(widget.data.roles[index]),
                  slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                    index,
                    widget.data.roles.length,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleDefinitionTile extends StatelessWidget {
  const _RoleDefinitionTile({
    required this.role,
    required this.capabilities,
    required this.expanded,
    required this.onExpandedChanged,
    required this.onEdit,
    required this.slot,
  });

  final AdminRoleDefinition role;
  final List<AdminCapability> capabilities;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback? onEdit;
  final M3SegmentVerticalSlot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final capabilityLabels = role.capabilityCodes
        .map((code) => _capabilityLabel(l10n, code, capabilities))
        .toList(growable: false);
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );
    return Material(
      key: ValueKey('admin-role-card-${role.id}'),
      color: scheme.surface,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onExpandedChanged(!expanded),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 4, expanded ? 8 : 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: expanded ? 0 : 45),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 30,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          role.system
                              ? Icons.admin_panel_settings_rounded
                              : Icons.verified_user_rounded,
                          size: 16,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _roleDefinitionLabel(context, role),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _roleDefinitionSummary(l10n, role),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onEdit != null)
                      IconButton(
                        key: ValueKey('admin-role-edit-${role.id}'),
                        tooltip: l10n.adminEditRole,
                        onPressed: onEdit,
                        icon: Icon(
                          Icons.edit_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    IconButton(
                      key: ValueKey('admin-role-details-${role.id}'),
                      tooltip: expanded
                          ? l10n.adminRoleDetailsHide
                          : l10n.adminRoleDetailsShow,
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
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded && capabilityLabels.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(58, 0, 14, 14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        capabilityLabels.join(', '),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _AssignmentsTab extends StatelessWidget {
  const _AssignmentsTab({
    required this.data,
    required this.bottomPadding,
    required this.onRefresh,
    required this.onAssign,
  });

  final _AdminRolesData data;
  final double bottomPadding;
  final Future<void> Function() onRefresh;
  final ValueChanged<_RolePrincipal> onAssign;

  @override
  Widget build(BuildContext context) {
    final principals = data.principalsForDisplay(context.l10n);
    return AppRefreshIndicator(
      onRefresh: onRefresh,
      allowRefreshOnShortContent: true,
      child: ListView(
        physics: const TopRefreshScrollPhysics(),
        padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
        children: [
          M3SegmentSpacedColumn(
            children: [
              for (int index = 0; index < principals.length; index++)
                _RoleAssignmentTile(
                  principal: principals[index],
                  assignedRole: data.roleForPrincipal(principals[index]),
                  assignment: data.assignmentForPrincipal(principals[index]),
                  slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                    index,
                    principals.length,
                  ),
                  onAssign: () => onAssign(principals[index]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleAssignmentTile extends StatelessWidget {
  const _RoleAssignmentTile({
    required this.principal,
    required this.assignedRole,
    required this.assignment,
    required this.slot,
    required this.onAssign,
  });

  final _RolePrincipal principal;
  final AdminRoleDefinition? assignedRole;
  final AdminRoleAssignment? assignment;
  final M3SegmentVerticalSlot slot;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );
    return Material(
      color: scheme.surface,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 30,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  principal.icon,
                  size: 16,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    principal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.roleLabelForCode(userRoleToJson(principal.role))} • ${principal.ref}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    assignedRole == null
                        ? l10n.adminDefaultRole
                        : _roleDefinitionLabel(context, assignedRole!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (assignment != null &&
                      assignment!.assignedApparatus.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${assignment!.assignedApparatus.length} ta aparat: ${assignment!.assignedApparatus.join(', ')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: onAssign,
              child: Text(l10n.archiveSelectDateAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminRoleEditorSheet extends StatefulWidget {
  const _AdminRoleEditorSheet({required this.data, this.role});

  final _AdminRolesData data;
  final AdminRoleDefinition? role;

  @override
  State<_AdminRoleEditorSheet> createState() => _AdminRoleEditorSheetState();
}

class _AdminRoleEditorSheetState extends State<_AdminRoleEditorSheet> {
  final TextEditingController _labelController = TextEditingController();
  final Set<String> _capabilityCodes = <String>{};

  @override
  void initState() {
    super.initState();
    final role = widget.role;
    if (role != null) {
      _labelController.text = role.label;
      _capabilityCodes.addAll(role.capabilityCodes);
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final l10n = context.l10n;
    final canSave =
        _labelController.text.trim().isNotEmpty && _capabilityCodes.isNotEmpty;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.role == null
                        ? l10n.adminNewRole
                        : l10n.adminEditRole,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton.filledTonal(
                  key: const ValueKey('admin-role-save-action'),
                  tooltip: l10n.save,
                  onPressed: canSave ? _save : null,
                  icon: const Icon(Icons.check_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _labelController,
              decoration: InputDecoration(
                labelText: l10n.adminRoleNameLabel,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final capability in widget.data.capabilities)
                    CheckboxListTile(
                      value: _capabilityCodes.contains(capability.code),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _capabilityCodes.add(capability.code);
                          } else {
                            _capabilityCodes.remove(capability.code);
                          }
                        });
                      },
                      title: Text(
                        l10n.adminCapabilityLabel(
                          capability.code,
                          capability.label,
                        ),
                      ),
                      subtitle: Text(capability.code),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final existingRole = widget.role;
    Navigator.of(context).pop(
      AdminRoleDefinition(
        id: existingRole?.id ?? _roleIdFromLabel(_labelController.text),
        label: _labelController.text.trim(),
        baseRole: null,
        capabilityCodes: _capabilityCodes.toList(growable: false),
        system: false,
      ),
    );
  }
}

class _RoleAssignmentSheet extends StatelessWidget {
  const _RoleAssignmentSheet({
    required this.principal,
    required this.roles,
    required this.apparatus,
    required this.existingAssignment,
  });

  final _RolePrincipal principal;
  final List<AdminRoleDefinition> roles;
  final List<AdminWarehouse> apparatus;
  final AdminRoleAssignment? existingAssignment;

  @override
  Widget build(BuildContext context) {
    return _RoleAssignmentSheetBody(
      principal: principal,
      roles: roles,
      apparatus: apparatus,
      existingAssignment: existingAssignment,
    );
  }
}

class _RoleAssignmentSheetBody extends StatefulWidget {
  const _RoleAssignmentSheetBody({
    required this.principal,
    required this.roles,
    required this.apparatus,
    required this.existingAssignment,
  });

  final _RolePrincipal principal;
  final List<AdminRoleDefinition> roles;
  final List<AdminWarehouse> apparatus;
  final AdminRoleAssignment? existingAssignment;

  @override
  State<_RoleAssignmentSheetBody> createState() =>
      _RoleAssignmentSheetBodyState();
}

class _RoleAssignmentSheetBodyState extends State<_RoleAssignmentSheetBody> {
  late final Set<String> _assignedApparatus =
      widget.existingAssignment?.assignedApparatus.toSet() ?? <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        children: [
          Text(
            l10n.adminRoleForPrincipal(widget.principal.name),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          for (final role in widget.roles) ...[
            ListTile(
              enabled: _roleCanAssignToPrincipal(role, widget.principal),
              leading: Icon(
                role.system
                    ? Icons.admin_panel_settings_outlined
                    : Icons.verified_user_outlined,
              ),
              title: Text(_roleDefinitionLabel(context, role)),
              subtitle: Text(_roleAssignmentSubtitle(l10n, role)),
              onTap: _roleCanAssignToPrincipal(role, widget.principal)
                  ? () => _submit(role)
                  : null,
            ),
            if (_roleNeedsApparatus(role))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AdminApparatusScopePicker(
                      apparatus: widget.apparatus,
                      selected: _assignedApparatus,
                      onChanged: (warehouse, checked) {
                        setState(() {
                          if (checked) {
                            _assignedApparatus.add(warehouse);
                          } else {
                            _assignedApparatus.remove(warehouse);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed:
                          _roleCanAssignToPrincipal(role, widget.principal)
                              ? () => _submit(role)
                              : null,
                      child: const Text('Saqlash'),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _submit(AdminRoleDefinition role) {
    if (_roleNeedsApparatus(role) && _assignedApparatus.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kamida bitta aparat tanlang')),
      );
      return;
    }
    final principalRole = role.id == 'aparatchi'
        ? UserRole.aparatchi
        : role.id == 'qolipchi'
            ? UserRole.qolipchi
            : widget.principal.role;
    Navigator.of(context).pop(
      AdminRoleAssignment(
        principalRole: principalRole,
        principalRef: widget.principal.ref,
        roleId: role.id,
        assignedApparatus:
            _roleNeedsApparatus(role) ? _sortedAssignedApparatus() : const [],
      ),
    );
  }

  List<String> _sortedAssignedApparatus() {
    return _assignedApparatus.toList(growable: false)..sort();
  }
}

class _AdminRolesData {
  const _AdminRolesData({
    required this.capabilities,
    required this.roles,
    required this.assignments,
    required this.settings,
    required this.suppliers,
    required this.customers,
    required this.apparatus,
  });

  final List<AdminCapability> capabilities;
  final List<AdminRoleDefinition> roles;
  final List<AdminRoleAssignment> assignments;
  final AdminSettings settings;
  final List<AdminSupplier> suppliers;
  final List<CustomerDirectoryEntry> customers;
  final List<AdminWarehouse> apparatus;

  List<_RolePrincipal> get _principals {
    return <_RolePrincipal>[
      _RolePrincipal(
        role: UserRole.werka,
        ref: 'werka',
        name: settings.werkaName.trim(),
        icon: Icons.badge_outlined,
      ),
      for (final supplier in suppliers)
        _RolePrincipal(
          role: UserRole.supplier,
          ref: supplier.ref,
          name: supplier.name,
          icon: Icons.local_shipping_outlined,
        ),
      for (final customer in customers)
        _RolePrincipal(
          role: adminCustomerPrincipalRole(assignments, customer.ref),
          ref: customer.ref,
          name: customer.name,
          icon: adminCustomerPrincipalRole(assignments, customer.ref) ==
                  UserRole.aparatchi
              ? Icons.precision_manufacturing_outlined
              : Icons.person_outline_rounded,
        ),
    ];
  }

  List<_RolePrincipal> principalsForDisplay(AppLocalizations l10n) {
    final principals = _principals
        .map((principal) {
          final isWerka =
              principal.role == UserRole.werka && principal.ref == 'werka';
          if (isWerka && principal.name.trim().isEmpty) {
            return principal.copyWith(name: l10n.werkaRoleName);
          }
          return principal;
        })
        .where((principal) => principal.name.trim().isNotEmpty)
        .toList(growable: false);
    if (principals.isNotEmpty) {
      return principals;
    }
    return <_RolePrincipal>[
      _RolePrincipal(
        role: UserRole.werka,
        ref: 'werka',
        name: l10n.werkaRoleName,
        icon: Icons.badge_outlined,
      ),
    ];
  }

  AdminRoleDefinition? roleForPrincipal(_RolePrincipal principal) {
    final assignment = assignmentForPrincipal(principal);
    if (assignment == null) {
      return roles
          .where(
            (role) =>
                role.system &&
                role.baseRole == principal.role &&
                role.id == userRoleToJson(principal.role),
          )
          .letFirstOrNull();
    }
    return roles.where((role) => role.id == assignment.roleId).letFirstOrNull();
  }

  AdminRoleAssignment? assignmentForPrincipal(_RolePrincipal principal) {
    if (principal.role == UserRole.customer ||
        principal.role == UserRole.aparatchi) {
      return adminAssignmentForCustomerRef(assignments, principal.ref);
    }
    return assignments
        .where(
          (item) =>
              item.principalRole == principal.role &&
              item.principalRef == principal.ref,
        )
        .letFirstOrNull();
  }

  _AdminRolesData upsertRole(AdminRoleDefinition role) {
    final nextRoles = roles.where((item) => item.id != role.id).toList()
      ..add(role)
      ..sort((left, right) {
        if (left.system != right.system) {
          return left.system ? -1 : 1;
        }
        return left.label.compareTo(right.label);
      });
    return copyWith(roles: nextRoles);
  }

  _AdminRolesData upsertAssignment(AdminRoleAssignment assignment) {
    final nextAssignments = assignments
        .where(
          (item) => item.principalRef.trim() != assignment.principalRef.trim(),
        )
        .toList()
      ..add(assignment);
    return copyWith(assignments: nextAssignments);
  }

  _AdminRolesData copyWith({
    List<AdminRoleDefinition>? roles,
    List<AdminRoleAssignment>? assignments,
  }) {
    return _AdminRolesData(
      capabilities: capabilities,
      roles: roles ?? this.roles,
      assignments: assignments ?? this.assignments,
      settings: settings,
      suppliers: suppliers,
      customers: customers,
      apparatus: apparatus,
    );
  }
}

class _RolePrincipal {
  const _RolePrincipal({
    required this.role,
    required this.ref,
    required this.name,
    required this.icon,
  });

  final UserRole role;
  final String ref;
  final String name;
  final IconData icon;

  _RolePrincipal copyWith({String? name}) {
    return _RolePrincipal(
      role: role,
      ref: ref,
      name: name ?? this.name,
      icon: icon,
    );
  }
}

String _roleIdFromLabel(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return normalized.isEmpty ? 'custom_role' : normalized;
}

String _roleDefinitionLabel(BuildContext context, AdminRoleDefinition role) {
  if (!role.system) {
    return role.label;
  }
  return context.l10n.systemRoleLabel(role.id, role.label);
}

String _roleDefinitionSummary(AppLocalizations l10n, AdminRoleDefinition role) {
  final baseRole = role.baseRole;
  if (baseRole == null) {
    return l10n.adminRoleKindLabel(role.system);
  }
  return '${l10n.roleLabelForCode(userRoleToJson(baseRole))} • ${l10n.adminRoleKindLabel(role.system)}';
}

bool _roleCanAssignToPrincipal(
  AdminRoleDefinition role,
  _RolePrincipal principal,
) {
  if (!role.system) {
    return true;
  }
  if (role.id == 'aparatchi') {
    return principal.role == UserRole.customer ||
        principal.role == UserRole.aparatchi;
  }
  if (role.id == 'qolipchi') {
    return principal.role == UserRole.qolipchi ||
        principal.role == UserRole.aparatchi;
  }
  if (role.baseRole == null) {
    return true;
  }
  return role.baseRole == principal.role;
}

bool _roleNeedsApparatus(AdminRoleDefinition role) {
  return role.capabilityCodes.contains('apparatus.queue.read');
}

String _roleAssignmentSubtitle(
  AppLocalizations l10n,
  AdminRoleDefinition role,
) {
  final baseRole = role.baseRole;
  if (baseRole == null) {
    return l10n.adminRoleKindLabel(role.system);
  }
  return l10n.roleLabelForCode(userRoleToJson(baseRole));
}

String _capabilityLabel(
  AppLocalizations l10n,
  String code,
  List<AdminCapability> capabilities,
) {
  final fallback = capabilities
          .where((capability) => capability.code == code)
          .map((capability) => capability.label)
          .letFirstOrNull() ??
      code;
  return l10n.adminCapabilityLabel(code, fallback);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? letFirstOrNull() {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}
