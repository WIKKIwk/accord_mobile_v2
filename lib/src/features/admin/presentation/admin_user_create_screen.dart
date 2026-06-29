import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/timers/retry_after_countdown.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import 'admin_suppliers_screen.dart';
import 'widgets/admin_dock.dart';
import '../logic/admin_aparatchi_assignment.dart';
import 'widgets/admin_apparatus_scope_picker.dart';
import 'widgets/admin_top_notice.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminUserCreateScreen extends StatefulWidget {
  const AdminUserCreateScreen({super.key});

  @override
  State<AdminUserCreateScreen> createState() => _AdminUserCreateScreenState();
}

class _AdminUserCreateScreenState extends State<AdminUserCreateScreen> {
  late Future<List<_AdminUserCreateChoice>> _roleChoices;
  _AdminUserCreateChoice? _choice;

  @override
  void initState() {
    super.initState();
    _roleChoices = _loadRoleChoices();
  }

  Future<List<_AdminUserCreateChoice>> _loadRoleChoices() async {
    final fallbackChoices = _AdminUserCreateKind.values
        .map(_AdminUserCreateChoice.system)
        .toList(growable: true);
    try {
      final roles = await MobileApi.instance.adminRoles();
      return [
        ...roles.where(_isAssignableRole).map(_AdminUserCreateChoice.custom),
        ...fallbackChoices,
      ];
    } catch (_) {
      return fallbackChoices;
    }
  }

  Future<void> _openRolePicker() async {
    final choices = await _roleChoices;
    if (!mounted) {
      return;
    }
    final picked = await showModalBottomSheet<_AdminUserCreateChoice>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3PickerSheet<_AdminUserCreateChoice>(
          title: 'Role tanlang',
          hintText: 'Role qidiring',
          items: choices,
          itemTitle: (choice) => choice.label,
          itemSubtitle: (choice) => choice.subtitle,
          matchesQuery: (choice, query) {
            final normalized = query.trim().toLowerCase();
            return choice.label.toLowerCase().contains(normalized) ||
                choice.subtitle.toLowerCase().contains(normalized);
          },
          onSelected: (choice) => Navigator.of(context).pop(choice),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _choice = picked);
  }

  @override
  Widget build(BuildContext context) {
    final choice = _choice;
    final kind = choice?.kind;
    final scheme = Theme.of(context).colorScheme;
    return AppShell(
      title: 'Foydalanuvchi qo‘shish',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: const AdminDock(activeTab: AdminDockTab.settings),
      contentPadding: EdgeInsets.zero,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          _adminUserCreatePanelGap,
          _adminUserCreatePanelGap,
          _adminUserCreatePanelGap,
          0,
        ),
        child: Card.filled(
          margin: EdgeInsets.zero,
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_adminUserCreateSectionRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoleSelector(choice: choice, onTap: _openRolePicker),
              if (choice != null)
                switch (kind) {
                  _AdminUserCreateKind.werka => _WerkaCreateTab(
                      assignedRole: choice.customRole,
                    ),
                  _AdminUserCreateKind.customer => _CustomerCreateTab(
                      assignedRole: choice.customRole,
                    ),
                  _AdminUserCreateKind.supplier => _SupplierCreateTab(
                      assignedRole: choice.customRole,
                    ),
                  _AdminUserCreateKind.custom => _CustomRoleCreateTab(
                      assignedRole: choice.customRole!,
                    ),
                  null => const SizedBox.shrink(),
                },
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminUserCreateChoice {
  const _AdminUserCreateChoice({
    required this.kind,
    required this.label,
    required this.subtitle,
    this.customRole,
  });

  factory _AdminUserCreateChoice.system(_AdminUserCreateKind kind) {
    return _AdminUserCreateChoice(
      kind: kind,
      label: kind.label,
      subtitle: kind.subtitle,
    );
  }

  factory _AdminUserCreateChoice.custom(AdminRoleDefinition role) {
    final kind = _kindForRole(role);
    return _AdminUserCreateChoice(
      kind: kind,
      label: role.label,
      subtitle: kind.label,
      customRole: role,
    );
  }

  final _AdminUserCreateKind kind;
  final String label;
  final String subtitle;
  final AdminRoleDefinition? customRole;
}

enum _AdminUserCreateKind {
  werka,
  customer,
  supplier,
  custom;

  String get label {
    return switch (this) {
      _AdminUserCreateKind.werka => 'Omborchi',
      _AdminUserCreateKind.customer => 'Haridor',
      _AdminUserCreateKind.supplier => 'Ta’minotchi',
      _AdminUserCreateKind.custom => 'Foydalanuvchi',
    };
  }

  String get subtitle {
    return switch (this) {
      _AdminUserCreateKind.werka => 'Warehouse worker account',
      _AdminUserCreateKind.customer => 'Mahsulot qabul qiluvchi haridor',
      _AdminUserCreateKind.supplier => 'Mahsulot yuboruvchi ta’minotchi',
      _AdminUserCreateKind.custom => 'Role asosidagi foydalanuvchi',
    };
  }
}

_AdminUserCreateKind _kindForRole(AdminRoleDefinition role) {
  final baseRole = role.baseRole;
  if (baseRole == UserRole.supplier) {
    return _AdminUserCreateKind.supplier;
  }
  if (baseRole == UserRole.customer) {
    return _AdminUserCreateKind.customer;
  }
  if (role.capabilityCodes.contains('supplier.access')) {
    return _AdminUserCreateKind.supplier;
  }
  if (role.capabilityCodes.contains('customer.access')) {
    return _AdminUserCreateKind.customer;
  }
  if (role.capabilityCodes.contains('werka.access')) {
    return _AdminUserCreateKind.werka;
  }
  return _AdminUserCreateKind.custom;
}

bool _isAssignableRole(AdminRoleDefinition role) {
  if (!role.system) {
    return true;
  }
  return !{'admin', 'werka', 'supplier', 'customer'}.contains(role.id);
}

const EdgeInsets _adminUserCreatePagePadding = EdgeInsets.fromLTRB(
  12,
  8,
  12,
  24,
);
const double _adminUserCreatePanelGap = 4;
const double _adminUserCreateSectionRadius = 18;
const double _adminUserCreateFieldGap = 12;

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.choice, required this.onTap});

  final _AdminUserCreateChoice? choice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fieldSurface = theme.brightness == Brightness.light
        ? scheme.surfaceBright
        : scheme.surface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Role tanlash',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Material(
            color: fieldSurface,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 66),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          choice == null
                              ? Icons.person_add_alt_1_outlined
                              : Icons.admin_panel_settings_outlined,
                          size: 21,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              choice?.label ?? 'Role tanlang',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              choice?.subtitle ??
                                  'Foydalanuvchi rolini tanlang',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.expand_more_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCreateTab extends StatefulWidget {
  const _CustomerCreateTab({required this.assignedRole});

  final AdminRoleDefinition? assignedRole;

  @override
  State<_CustomerCreateTab> createState() => _CustomerCreateTabState();
}

class _CustomerCreateTabState extends State<_CustomerCreateTab> {
  final TextEditingController name = TextEditingController();
  final TextEditingController phone = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => saving = true);
    try {
      final customer = await MobileApi.instance.adminCreateCustomer(
        name: name.text.trim(),
        phone: phone.text.trim(),
      );
      await _assignCustomRole(
        widget.assignedRole,
        UserRole.customer,
        customer.ref,
      );
      if (!mounted) {
        return;
      }
      name.clear();
      phone.clear();
      AdminSuppliersScreen.invalidateCache();
      showAdminTopNotice(context, 'Haridor yaratildi');
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, 'Haridor yaratilmadi');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CreateUserForm(
      name: name,
      phone: phone,
      nameLabel: 'Foydalanuvchi nomi',
      phoneLabel: 'Foydalanuvchi telefoni',
      actionLabel: saving ? 'Saqlanmoqda...' : 'Foydalanuvchi saqlash',
      saving: saving,
      onSubmit: _create,
    );
  }
}

class _SupplierCreateTab extends StatefulWidget {
  const _SupplierCreateTab({required this.assignedRole});

  final AdminRoleDefinition? assignedRole;

  @override
  State<_SupplierCreateTab> createState() => _SupplierCreateTabState();
}

class _SupplierCreateTabState extends State<_SupplierCreateTab> {
  final TextEditingController name = TextEditingController();
  final TextEditingController phone = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => saving = true);
    try {
      final supplier = await MobileApi.instance.adminCreateSupplier(
        name: name.text.trim(),
        phone: phone.text.trim(),
      );
      await _assignCustomRole(
        widget.assignedRole,
        UserRole.supplier,
        supplier.ref,
      );
      if (!mounted) {
        return;
      }
      name.clear();
      phone.clear();
      AdminSuppliersScreen.invalidateCache();
      showAdminTopNotice(context, 'Ta’minotchi yaratildi');
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, 'Ta’minotchi yaratilmadi');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CreateUserForm(
      name: name,
      phone: phone,
      nameLabel: 'Foydalanuvchi nomi',
      phoneLabel: 'Foydalanuvchi telefoni',
      actionLabel: saving ? 'Saqlanmoqda...' : 'Foydalanuvchi saqlash',
      saving: saving,
      onSubmit: _create,
    );
  }
}

class _CustomRoleCreateTab extends StatefulWidget {
  const _CustomRoleCreateTab({required this.assignedRole});

  final AdminRoleDefinition assignedRole;

  @override
  State<_CustomRoleCreateTab> createState() => _CustomRoleCreateTabState();
}

class _CustomRoleCreateTabState extends State<_CustomRoleCreateTab> {
  final TextEditingController name = TextEditingController();
  final TextEditingController phone = TextEditingController();
  bool saving = false;
  bool loadingApparatus = false;
  List<AdminWarehouse> apparatus = const [];
  final Set<String> selectedApparatus = <String>{};

  bool get _isAparatchiRole => widget.assignedRole.id == 'aparatchi';
  bool get _isQolipchiRole => widget.assignedRole.id == 'qolipchi';

  @override
  void initState() {
    super.initState();
    if (_isAparatchiRole) {
      unawaited(_loadApparatus());
    }
  }

  Future<void> _loadApparatus() async {
    setState(() => loadingApparatus = true);
    try {
      final items = await MobileApi.instance.adminWarehouses(
        parent: 'aparat - A',
        limit: 200,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        apparatus = items;
        loadingApparatus = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => loadingApparatus = false);
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_isAparatchiRole && selectedApparatus.isEmpty) {
      showAdminTopNotice(context, 'Kamida bitta aparat tanlang');
      return;
    }
    setState(() => saving = true);
    try {
      if (_isQolipchiRole) {
        final worker = await MobileApi.instance.adminCreateWorker(
          name: name.text.trim(),
          level: 'Brigader',
        );
        final workerPhone = phone.text.trim();
        if (workerPhone.isNotEmpty) {
          await MobileApi.instance.adminUpdateWorkerPhone(
            id: worker.id,
            phone: workerPhone,
          );
        }
        await _assignCustomRole(
          widget.assignedRole,
          UserRole.qolipchi,
          worker.id,
        );
        await MobileApi.instance.adminRegenerateWorkerCode(worker.id);
      } else {
        final user = await MobileApi.instance.adminCreateCustomer(
          name: name.text.trim(),
          phone: phone.text.trim(),
        );
        if (_isAparatchiRole) {
          await MobileApi.instance.adminUpsertRoleAssignment(
            adminAparatchiAssignmentUpsert(
              principalRef: user.ref,
              assignedApparatus: selectedApparatus.toList(growable: false)
                ..sort(),
            ),
          );
          await MobileApi.instance.adminRegenerateCustomerCode(user.ref);
        } else {
          final principalRole = _principalRoleForAssignedRole(
            widget.assignedRole,
          );
          await _assignCustomRole(
            widget.assignedRole,
            principalRole,
            user.ref,
          );
        }
      }
      if (!mounted) {
        return;
      }
      name.clear();
      phone.clear();
      selectedApparatus.clear();
      AdminSuppliersScreen.invalidateCache();
      showAdminTopNotice(context, 'Foydalanuvchi yaratildi');
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, 'Foydalanuvchi yaratilmadi');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: name,
                textInputAction: TextInputAction.next,
                decoration: appSoftInputDecoration(
                  context,
                  labelText: 'Foydalanuvchi nomi',
                ),
              ),
              const SizedBox(height: _adminUserCreateFieldGap),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: appSoftInputDecoration(
                  context,
                  labelText: 'Foydalanuvchi telefoni',
                ),
              ),
              if (_isAparatchiRole) ...[
                const SizedBox(height: 16),
                if (loadingApparatus)
                  const Center(child: AppLoadingIndicator())
                else
                  AdminApparatusScopePicker(
                    apparatus: apparatus,
                    selected: selectedApparatus,
                    onChanged: (warehouse, checked) {
                      setState(() {
                        if (checked) {
                          selectedApparatus.add(warehouse);
                        } else {
                          selectedApparatus.remove(warehouse);
                        }
                      });
                    },
                  ),
              ],
            ],
          ),
        ),
        Padding(
          padding: _adminUserCreatePagePadding,
          child: FilledButton(
            onPressed: saving ? null : _create,
            child: Text(saving ? 'Saqlanmoqda...' : 'Foydalanuvchi saqlash'),
          ),
        ),
      ],
    );
  }
}

class _WerkaCreateTab extends StatefulWidget {
  const _WerkaCreateTab({required this.assignedRole});

  final AdminRoleDefinition? assignedRole;

  @override
  State<_WerkaCreateTab> createState() => _WerkaCreateTabState();
}

class _WerkaCreateTabState extends State<_WerkaCreateTab> {
  late Future<AdminSettings> _future;
  final TextEditingController phone = TextEditingController();
  final TextEditingController name = TextEditingController();
  String werkaCode = '';
  late final RetryAfterCountdown _retryAfter;
  int get _retryAfterSec => _retryAfter.seconds;
  bool saving = false;
  bool regenerating = false;
  bool hydrated = false;

  @override
  void initState() {
    super.initState();
    _retryAfter = RetryAfterCountdown(onChanged: _refreshRetryAfter);
    _future = MobileApi.instance.adminSettings();
  }

  @override
  void dispose() {
    _retryAfter.dispose();
    phone.dispose();
    name.dispose();
    super.dispose();
  }

  void _fill(AdminSettings settings) {
    if (hydrated) {
      return;
    }
    phone.text = settings.werkaPhone;
    name.text = settings.werkaName;
    werkaCode = settings.werkaCode;
    _setRetryAfter(settings.werkaCodeRetryAfterSec);
    hydrated = true;
  }

  void _refreshRetryAfter() {
    if (mounted) {
      setState(() {});
    }
  }

  void _setRetryAfter(int seconds) => _retryAfter.set(seconds);

  Future<void> _reload() async {
    final future = MobileApi.instance.adminSettings();
    setState(() {
      hydrated = false;
      _future = future;
    });
  }

  Future<void> _save(AdminSettings current) async {
    setState(() => saving = true);
    try {
      final updated = await MobileApi.instance.updateAdminSettings(
        AdminSettings(
          erpUrl: current.erpUrl,
          erpApiKey: current.erpApiKey,
          erpApiSecret: current.erpApiSecret,
          defaultTargetWarehouse: current.defaultTargetWarehouse,
          defaultUom: current.defaultUom,
          werkaPhone: phone.text.trim(),
          werkaName: name.text.trim(),
          werkaAvatarUrl: current.werkaAvatarUrl,
          werkaCode: werkaCode,
          werkaCodeLocked: current.werkaCodeLocked,
          werkaCodeRetryAfterSec: _retryAfterSec,
          adminPhone: current.adminPhone,
          adminName: current.adminName,
        ),
      );
      await _assignCustomRole(widget.assignedRole, UserRole.werka, 'werka');
      if (!mounted) {
        return;
      }
      setState(() {
        werkaCode = updated.werkaCode;
      });
      AdminSuppliersScreen.invalidateCache();
      showAdminTopNotice(context, 'Omborchi saqlandi');
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, 'Omborchi saqlanmadi');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> _regenerate() async {
    setState(() => regenerating = true);
    try {
      final updated = await MobileApi.instance.adminRegenerateWerkaCode();
      if (!mounted) {
        return;
      }
      setState(() {
        werkaCode = updated.werkaCode;
      });
      _setRetryAfter(updated.werkaCodeRetryAfterSec);
      showAdminTopNotice(context, 'Omborchi code yangilandi');
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, 'Code yangilanmadi');
      }
    } finally {
      if (mounted) {
        setState(() => regenerating = false);
      }
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: werkaCode));
    if (!mounted) {
      return;
    }
    showAdminTopNotice(context, 'Code nusxalandi');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminSettings>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: AppLoadingIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: AppRetryState(onRetry: _reload, padding: EdgeInsets.zero),
          );
        }
        final current = snapshot.data!;
        _fill(current);
        return Padding(
          padding: _adminUserCreatePagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WerkaCodeField(
                code: werkaCode,
                regenerating: regenerating,
                retryAfterSec: _retryAfterSec,
                onCopy: werkaCode.trim().isEmpty ? null : _copyCode,
                onRegenerate:
                    regenerating || _retryAfterSec > 0 ? null : _regenerate,
              ),
              if (_retryAfterSec > 0) ...[
                const SizedBox(height: _adminUserCreateFieldGap),
                Text('Keyingi code uchun $_retryAfterSec soniya kuting.'),
              ],
              const SizedBox(height: 14),
              _CreateUserForm(
                name: name,
                phone: phone,
                nameLabel: 'Foydalanuvchi nomi',
                phoneLabel: 'Foydalanuvchi telefoni',
                actionLabel:
                    saving ? 'Saqlanmoqda...' : 'Foydalanuvchi saqlash',
                saving: saving,
                onSubmit: () => _save(current),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _assignCustomRole(
  AdminRoleDefinition? role,
  UserRole principalRole,
  String principalRef,
) async {
  if (role == null) {
    return;
  }
  await MobileApi.instance.adminUpsertRoleAssignment(
    AdminRoleAssignment(
      principalRole: principalRole,
      principalRef: principalRef,
      roleId: role.id,
    ),
  );
}

UserRole _principalRoleForAssignedRole(AdminRoleDefinition role) {
  if (role.id == 'aparatchi') {
    return UserRole.aparatchi;
  }
  if (role.id == 'qolipchi') {
    return UserRole.qolipchi;
  }
  return role.baseRole ?? UserRole.customer;
}

class _CreateUserForm extends StatelessWidget {
  const _CreateUserForm({
    required this.name,
    required this.phone,
    required this.nameLabel,
    required this.phoneLabel,
    required this.actionLabel,
    required this.saving,
    required this.onSubmit,
    this.padding = _adminUserCreatePagePadding,
  });

  final TextEditingController name;
  final TextEditingController phone;
  final String nameLabel;
  final String phoneLabel;
  final String actionLabel;
  final bool saving;
  final VoidCallback onSubmit;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: name,
          textInputAction: TextInputAction.next,
          decoration: appSoftInputDecoration(context, labelText: nameLabel),
        ),
        const SizedBox(height: _adminUserCreateFieldGap),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: appSoftInputDecoration(context, labelText: phoneLabel),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: saving ? null : onSubmit,
            child: Text(actionLabel),
          ),
        ),
      ],
    );
    if (padding == EdgeInsets.zero) {
      return content;
    }
    return Padding(
      padding: padding,
      child: content,
    );
  }
}

class _WerkaCodeField extends StatelessWidget {
  const _WerkaCodeField({
    required this.code,
    required this.regenerating,
    required this.retryAfterSec,
    required this.onCopy,
    required this.onRegenerate,
  });

  final String code;
  final bool regenerating;
  final int retryAfterSec;
  final VoidCallback? onCopy;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Code',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: theme.brightness == Brightness.light
              ? scheme.surfaceBright
              : scheme.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 6, 6),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      code.trim().isEmpty ? ' ' : code,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: onCopy,
                    icon: const Icon(Icons.content_copy_outlined),
                  ),
                  IconButton(
                    onPressed: onRegenerate,
                    icon: regenerating
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
          ),
        ),
      ],
    );
  }
}
