import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/timers/retry_after_countdown.dart';
import '../../../core/widgets/buttons/app_action_button_styles.dart';
import '../../../core/widgets/display/app_detail_field.dart';
import '../../../core/widgets/display/app_status_chip.dart';
import '../../../core/widgets/lists/app_segment_surface_card.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../shared/models/app_models.dart';
import '../../shared/presentation/widgets/profile_info_chip.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_profile_avatar.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double _supplierDetailPanelGap = 4;
const double _supplierDetailButtonRadius = 14;

class AdminSupplierDetailScreen extends StatefulWidget {
  const AdminSupplierDetailScreen({super.key, required this.supplierRef});

  final String supplierRef;

  @override
  State<AdminSupplierDetailScreen> createState() =>
      _AdminSupplierDetailScreenState();
}

class _AdminSupplierDetailScreenState extends State<AdminSupplierDetailScreen> {
  late Future<AdminSupplierDetail> _detailFuture;
  bool _savingStatus = false;
  bool _savingPhone = false;
  bool _regeneratingCode = false;
  bool _removing = false;
  bool _adminPanelExpanded = false;
  bool _changed = false;
  late final RetryAfterCountdown _retryAfter;
  int get _retryAfterSec => _retryAfter.seconds;

  @override
  void initState() {
    super.initState();
    _retryAfter = RetryAfterCountdown(onChanged: _refreshRetryAfter);
    _detailFuture = _loadDetail();
  }

  @override
  void dispose() {
    _retryAfter.dispose();
    super.dispose();
  }

  Future<AdminSupplierDetail> _loadDetail() async {
    final detail = await MobileApi.instance.adminSupplierDetail(
      widget.supplierRef,
    );
    _setRetryAfter(detail.codeRetryAfterSec);
    return detail;
  }

  void _refreshRetryAfter() {
    if (mounted) {
      setState(() {});
    }
  }

  void _setRetryAfter(int seconds) => _retryAfter.set(seconds);

  Future<void> _reload() async {
    final future = _loadDetail();
    setState(() {
      _detailFuture = future;
    });
    await future;
  }

  Future<void> _toggleBlocked(AdminSupplierDetail detail) async {
    setState(() => _savingStatus = true);
    try {
      final updated = await MobileApi.instance.adminSetSupplierBlocked(
        ref: detail.ref,
        blocked: !detail.blocked,
      );
      _changed = true;
      setState(() {
        _detailFuture = Future<AdminSupplierDetail>.value(updated);
      });
    } finally {
      if (mounted) {
        setState(() => _savingStatus = false);
      }
    }
  }

  Future<void> _savePhone(AdminSupplierDetail detail, String phone) async {
    final trimmedPhone = phone.trim();
    if (trimmedPhone.isEmpty) {
      return;
    }

    setState(() => _savingPhone = true);
    try {
      final updated = await MobileApi.instance.adminUpdateSupplierPhone(
        ref: detail.ref,
        phone: trimmedPhone,
      );
      _changed = true;
      setState(() {
        _detailFuture = Future<AdminSupplierDetail>.value(updated);
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
      final updated = await MobileApi.instance.adminRegenerateSupplierCode(
        widget.supplierRef,
      );
      _setRetryAfter(updated.codeRetryAfterSec);
      _changed = true;
      setState(() {
        _detailFuture = Future<AdminSupplierDetail>.value(updated);
      });
    } finally {
      if (mounted) {
        setState(() => _regeneratingCode = false);
      }
    }
  }

  Future<void> _removeSupplier() async {
    final bool? confirmed = await showM3ConfirmDialog(
      context: context,
      title: 'Supplierni chiqarish',
      message:
          'Bu supplier admin panel ro‘yxatidan chiqariladi va kira olmaydi.',
      cancelLabel: 'Bekor qilish',
      confirmLabel: 'Chiqarish',
      destructive: true,
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _removing = true);
    try {
      await MobileApi.instance.adminRemoveSupplier(widget.supplierRef);
      _changed = true;
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _removing = false);
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
        bottom: const AdminDock(activeTab: AdminDockTab.suppliers),
        child: SafeArea(
          top: false,
          child: FutureBuilder<AdminSupplierDetail>(
            future: _detailFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: AppLoadingIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    AppRetryState(onRetry: _reload, padding: EdgeInsets.zero),
                  ],
                );
              }

              final detail = snapshot.data!;
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  _supplierDetailPanelGap,
                  _supplierDetailPanelGap,
                  _supplierDetailPanelGap,
                  116,
                ),
                children: [
                  AppSegmentSurfaceCard(
                    padding: EdgeInsets.zero,
                    child: _AdminSupplierDetailCard(
                      detail: detail,
                      retryAfterSec: _retryAfterSec,
                      expanded: _adminPanelExpanded,
                      savingStatus: _savingStatus,
                      savingPhone: _savingPhone,
                      regeneratingCode: _regeneratingCode,
                      removing: _removing,
                      onExpandedChanged: (expanded) {
                        setState(() => _adminPanelExpanded = expanded);
                      },
                      onSavePhone: _savePhone,
                      onToggleBlocked: _toggleBlocked,
                      onRegenerateCode: _regenerateCode,
                      onCopyCode: _copyCode,
                      onRemove: _removeSupplier,
                      onViewItems: () => Navigator.of(context).pushNamed(
                        AppRoutes.adminSupplierItemsView,
                        arguments: widget.supplierRef,
                      ),
                      onAddItem: () => Navigator.of(context).pushNamed(
                        AppRoutes.adminSupplierItemsAdd,
                        arguments: widget.supplierRef,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AdminSupplierDetailCard extends StatelessWidget {
  const _AdminSupplierDetailCard({
    required this.detail,
    required this.retryAfterSec,
    required this.expanded,
    required this.savingStatus,
    required this.savingPhone,
    required this.regeneratingCode,
    required this.removing,
    required this.onExpandedChanged,
    required this.onSavePhone,
    required this.onToggleBlocked,
    required this.onRegenerateCode,
    required this.onCopyCode,
    required this.onRemove,
    required this.onViewItems,
    required this.onAddItem,
  });

  final AdminSupplierDetail detail;
  final int retryAfterSec;
  final bool expanded;
  final bool savingStatus;
  final bool savingPhone;
  final bool regeneratingCode;
  final bool removing;
  final ValueChanged<bool> onExpandedChanged;
  final Future<void> Function(AdminSupplierDetail detail, String phone)
      onSavePhone;
  final Future<void> Function(AdminSupplierDetail detail) onToggleBlocked;
  final Future<void> Function() onRegenerateCode;
  final Future<void> Function(String code) onCopyCode;
  final Future<void> Function() onRemove;
  final VoidCallback onViewItems;
  final VoidCallback onAddItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final phone = detail.phone.trim();
    final displayName =
        detail.name.trim().isEmpty ? 'Yetkazib beruvchi' : detail.name.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 204,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                top: 112,
                child: ColoredBox(color: scheme.surface),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 112,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        scheme.surfaceContainerHighest,
                        scheme.surfaceContainerLow,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 14,
                top: 14,
                child: AppStatusChip(
                  label: detail.blocked ? 'Bloklangan' : 'Tayyor',
                ),
              ),
              Positioned(
                left: 16,
                top: 74,
                child: AdminProfileAvatar(
                  avatarUrl: detail.avatarUrl,
                  fallbackText: _supplierInitials(displayName),
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
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Yetkazib beruvchi profili',
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
                      icon: Icons.inventory_2_rounded,
                      label: '${detail.assignedItems.length} ta mahsulot',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey('admin-supplier-detail-admin-toggle'),
                tooltip: expanded ? 'Boshqaruvni yopish' : 'Boshqaruvni ochish',
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
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _AdminSupplierPanel(
                    detail: detail,
                    retryAfterSec: retryAfterSec,
                    savingStatus: savingStatus,
                    savingPhone: savingPhone,
                    regeneratingCode: regeneratingCode,
                    removing: removing,
                    onSavePhone: onSavePhone,
                    onToggleBlocked: onToggleBlocked,
                    onRegenerateCode: onRegenerateCode,
                    onCopyCode: onCopyCode,
                    onRemove: onRemove,
                    onViewItems: onViewItems,
                    onAddItem: onAddItem,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _AdminSupplierPanel extends StatelessWidget {
  const _AdminSupplierPanel({
    required this.detail,
    required this.retryAfterSec,
    required this.savingStatus,
    required this.savingPhone,
    required this.regeneratingCode,
    required this.removing,
    required this.onSavePhone,
    required this.onToggleBlocked,
    required this.onRegenerateCode,
    required this.onCopyCode,
    required this.onRemove,
    required this.onViewItems,
    required this.onAddItem,
  });

  final AdminSupplierDetail detail;
  final int retryAfterSec;
  final bool savingStatus;
  final bool savingPhone;
  final bool regeneratingCode;
  final bool removing;
  final Future<void> Function(AdminSupplierDetail detail, String phone)
      onSavePhone;
  final Future<void> Function(AdminSupplierDetail detail) onToggleBlocked;
  final Future<void> Function() onRegenerateCode;
  final Future<void> Function(String code) onCopyCode;
  final Future<void> Function() onRemove;
  final VoidCallback onViewItems;
  final VoidCallback onAddItem;

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
        Text('Telefon', style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        _SupplierPhoneInlineField(
          detail: detail,
          savingPhone: savingPhone,
          onSavePhone: onSavePhone,
        ),
        const SizedBox(height: 14),
        Text('Kirish kodi', style: theme.textTheme.bodySmall),
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
                onPressed: regeneratingCode || retryAfterSec > 0
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
        if (retryAfterSec > 0) ...[
          const SizedBox(height: 12),
          Text(
            'Keyingi code uchun $retryAfterSec soniya kuting.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          'Biriktirilgan mahsulotlar',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          detail.assignedItems.isEmpty
              ? 'Hozircha mahsulot biriktirilmagan.'
              : '${detail.assignedItems.length} ta mahsulot biriktirilgan.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: appOutlinedActionButtonStyle(
                  borderRadius: _supplierDetailButtonRadius,
                ),
                onPressed: onViewItems,
                child: const Text('Ko‘rish'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                style: appOutlinedActionButtonStyle(
                  borderRadius: _supplierDetailButtonRadius,
                ),
                onPressed: onAddItem,
                child: const Text('Qo‘shish'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: appOutlinedActionButtonStyle(
              borderRadius: _supplierDetailButtonRadius,
            ),
            onPressed: savingStatus ? null : () => onToggleBlocked(detail),
            child: Text(
              savingStatus
                  ? 'Saqlanmoqda...'
                  : detail.blocked
                      ? 'Blokdan chiqarish'
                      : 'Bloklash',
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: appOutlinedActionButtonStyle(
              borderRadius: _supplierDetailButtonRadius,
            ),
            onPressed: removing ? null : onRemove,
            child: Text(
              removing ? 'Chiqarilmoqda...' : 'Tizimdan chiqarish',
            ),
          ),
        ),
      ],
    );
  }
}

class _SupplierPhoneInlineField extends StatefulWidget {
  const _SupplierPhoneInlineField({
    required this.detail,
    required this.savingPhone,
    required this.onSavePhone,
  });

  final AdminSupplierDetail detail;
  final bool savingPhone;
  final Future<void> Function(AdminSupplierDetail detail, String phone)
      onSavePhone;

  @override
  State<_SupplierPhoneInlineField> createState() =>
      _SupplierPhoneInlineFieldState();
}

class _SupplierPhoneInlineFieldState extends State<_SupplierPhoneInlineField> {
  late final TextEditingController _controller;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.detail.phone.trim());
  }

  @override
  void didUpdateWidget(covariant _SupplierPhoneInlineField oldWidget) {
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
                    key: const ValueKey('admin-supplier-detail-phone-input'),
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
            key: const ValueKey('admin-supplier-detail-phone-action'),
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

String _supplierInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'Y';
  }
  final first = parts.first.characters.first.toUpperCase();
  if (parts.length == 1) {
    return first;
  }
  return '$first${parts.last.characters.first.toUpperCase()}';
}
