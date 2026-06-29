import '../../../core/api/mobile_api.dart';
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
import 'dart:async';

import 'widgets/admin_aparatchi_apparatus_card.dart';
import 'widgets/admin_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double _customerDetailPanelGap = 4;
const double _customerDetailButtonRadius = 14;

class AdminCustomerDetailScreen extends StatefulWidget {
  const AdminCustomerDetailScreen({
    super.key,
    required this.customerRef,
    this.detailLoader,
    this.title = 'Profil',
  });

  final String customerRef;
  final Future<AdminCustomerDetail> Function(String ref)? detailLoader;
  final String title;

  @override
  State<AdminCustomerDetailScreen> createState() =>
      _AdminCustomerDetailScreenState();
}

class _AdminCustomerDetailScreenState extends State<AdminCustomerDetailScreen> {
  AdminCustomerDetail? _detail;
  Object? _loadError;
  bool _loading = true;
  bool _savingPhone = false;
  bool _regeneratingCode = false;
  bool _removing = false;
  bool _addingItem = false;
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

  Future<AdminCustomerDetail> _loadDetail() async {
    final loadDetail =
        widget.detailLoader ?? MobileApi.instance.adminCustomerDetail;
    final detail = await loadDetail(widget.customerRef).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Customer detail timeout'),
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
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final detail = await _loadDetail();
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
        _loadError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = null;
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _savePhone(AdminCustomerDetail detail, String phone) async {
    final trimmedPhone = phone.trim();
    if (trimmedPhone.isEmpty) {
      return;
    }

    setState(() => _savingPhone = true);
    try {
      final updated = await MobileApi.instance.adminUpdateCustomerPhone(
        ref: detail.ref,
        phone: trimmedPhone,
      );
      _changed = true;
      if (!mounted) {
        return;
      }
      _setRetryAfter(updated.codeRetryAfterSec);
      setState(() => _detail = updated);
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
      final updated = await MobileApi.instance.adminRegenerateCustomerCode(
        widget.customerRef,
      );
      _changed = true;
      if (!mounted) {
        return;
      }
      _setRetryAfter(updated.codeRetryAfterSec);
      setState(() => _detail = updated);
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

  Future<void> _removeCustomer() async {
    final bool? confirmed = await showM3ConfirmDialog(
      context: context,
      title: 'Customerni chiqarish',
      message:
          'Bu customer admin panel ro‘yxatidan chiqariladi va kira olmaydi.',
      cancelLabel: 'Bekor qilish',
      confirmLabel: 'Chiqarish',
      destructive: true,
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _removing = true);
    try {
      await MobileApi.instance.adminRemoveCustomer(widget.customerRef);
      _changed = true;
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Customer chiqarilmadi: $error')));
    } finally {
      if (mounted) {
        setState(() => _removing = false);
      }
    }
  }

  Future<bool> _assignItem(SupplierItem item) async {
    setState(() => _addingItem = true);
    try {
      final updated = await MobileApi.instance.adminAssignCustomerItem(
        ref: widget.customerRef,
        itemCode: item.code,
      );
      _changed = true;
      if (!mounted) {
        return false;
      }
      setState(() => _detail = updated);
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mahsulot biriktirilmadi: $error')),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _addingItem = false);
      }
    }
  }

  Future<void> _addItem() async {
    final detail = _detail;
    if (detail == null) {
      return;
    }

    final allItems = await MobileApi.instance.adminItems();
    if (!mounted) {
      return;
    }
    final assignedCodes = detail.assignedItems.map((item) => item.code).toSet();
    final availableItems =
        allItems.where((item) => !assignedCodes.contains(item.code)).toList();
    if (availableItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biriktirilmagan mahsulot topilmadi')),
      );
      return;
    }
    await _showAvailableItemsSheet(
      context,
      detail,
      availableItems,
      onAddItem: _assignItem,
    );
  }

  Future<bool> _removeItem(SupplierItem item) async {
    final bool? confirmed = await showM3ConfirmDialog(
      context: context,
      title: 'Mahsulotni uzish',
      message: '${item.name} mahsulotini customerdan uzaymi?',
      cancelLabel: 'Yo‘q',
      confirmLabel: 'Ha',
    );
    if (confirmed != true) {
      return false;
    }

    setState(() => _removingItemCode = item.code);
    try {
      final updated = await MobileApi.instance.adminRemoveCustomerItem(
        ref: widget.customerRef,
        itemCode: item.code,
      );
      _changed = true;
      if (!mounted) {
        return false;
      }
      setState(() => _detail = updated);
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mahsulot uzilmadi: $error')));
      return false;
    } finally {
      if (mounted) {
        setState(() => _removingItemCode = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AdminCustomerDetail detail = _detail ??
        AdminCustomerDetail(
          ref: widget.customerRef,
          name: _loading ? 'Yuklanmoqda...' : 'Customer',
          phone: _loading ? 'Yuklanmoqda...' : 'Kiritilmagan',
          code: _loading ? 'Yuklanmoqda...' : 'Hali generatsiya qilinmagan',
          codeLocked: false,
          codeRetryAfterSec: _retryAfterSec,
          assignedItems: const [],
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
        title: widget.title,
        subtitle: '',
        nativeTopBar: true,
        nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
        contentPadding: EdgeInsets.zero,
        bottom: const AdminDock(activeTab: AdminDockTab.suppliers),
        child: ListView(
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
                    ? 'Yuklanmoqda'
                    : _loadError != null
                        ? 'Xato'
                        : _detail == null
                            ? 'Bo‘sh'
                            : 'Tayyor',
                expanded: _adminPanelExpanded,
                savingPhone: _savingPhone,
                regeneratingCode: _regeneratingCode,
                removing: _removing,
                addingItem: _addingItem,
                removingItemCode: _removingItemCode,
                onExpandedChanged: (expanded) {
                  setState(() => _adminPanelExpanded = expanded);
                },
                onSavePhone: _savePhone,
                onAddItem: _addItem,
                onRemoveItem: _removeItem,
                onRegenerateCode: _regenerateCode,
                onCopyCode: _copyCode,
                onRemove: _removeCustomer,
              ),
            ),
            const SizedBox(height: 12),
            AdminAparatchiApparatusCard(
              customerRef: widget.customerRef,
              onChanged: () => _changed = true,
            ),
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

Future<void> _showAvailableItemsSheet(
  BuildContext context,
  AdminCustomerDetail detail,
  List<SupplierItem> availableItems, {
  required Future<bool> Function(SupplierItem item) onAddItem,
}) async {
  final visibleItems = availableItems.toList();
  final collapsingCodes = <String>{};
  String? activeAddingCode;

  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Mahsulot qo‘shish',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  detail.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: visibleItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];
                      final collapsing = collapsingCodes.contains(item.code);
                      return AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOutCubic,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeInOutCubic,
                          opacity: collapsing ? 0 : 1,
                          child: collapsing
                              ? const SizedBox.shrink()
                              : ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  tileColor: scheme.surfaceContainerHighest,
                                  title: Text(item.name),
                                  subtitle: Text(item.code),
                                  trailing: activeAddingCode == item.code
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.add_rounded),
                                  onTap: activeAddingCode == item.code
                                      ? null
                                      : () async {
                                          setModalState(() {
                                            activeAddingCode = item.code;
                                          });
                                          final added = await onAddItem(item);
                                          if (!context.mounted) {
                                            return;
                                          }
                                          if (added) {
                                            setModalState(() {
                                              collapsingCodes.add(item.code);
                                            });
                                            await Future<void>.delayed(
                                              const Duration(milliseconds: 180),
                                            );
                                            if (!context.mounted) {
                                              return;
                                            }
                                            setModalState(() {
                                              visibleItems.removeWhere(
                                                (current) =>
                                                    current.code == item.code,
                                              );
                                              collapsingCodes.remove(item.code);
                                              activeAddingCode = null;
                                            });
                                          } else {
                                            setModalState(() {
                                              activeAddingCode = null;
                                            });
                                          }
                                        },
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _AdminCustomerDetailCard extends StatelessWidget {
  const _AdminCustomerDetailCard({
    required this.detail,
    required this.statusLabel,
    required this.expanded,
    required this.savingPhone,
    required this.regeneratingCode,
    required this.removing,
    required this.addingItem,
    required this.removingItemCode,
    required this.onExpandedChanged,
    required this.onSavePhone,
    required this.onAddItem,
    required this.onRemoveItem,
    required this.onRegenerateCode,
    required this.onCopyCode,
    required this.onRemove,
  });

  final AdminCustomerDetail detail;
  final String statusLabel;
  final bool expanded;
  final bool savingPhone;
  final bool regeneratingCode;
  final bool removing;
  final bool addingItem;
  final String? removingItemCode;
  final ValueChanged<bool> onExpandedChanged;
  final Future<void> Function(AdminCustomerDetail detail, String phone)
      onSavePhone;
  final Future<void> Function() onAddItem;
  final Future<bool> Function(SupplierItem item) onRemoveItem;
  final Future<void> Function() onRegenerateCode;
  final Future<void> Function(String code) onCopyCode;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final phone = detail.phone.trim();
    final initials = _customerInitials(detail.name);

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
                child: AppStatusChip(label: statusLabel),
              ),
              Positioned(
                left: 16,
                top: 74,
                child: Container(
                  height: 92,
                  width: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primaryContainer,
                    border: Border.all(color: scheme.surface, width: 5),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.16),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
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
                          ? 'Nomsiz haridor'
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
                      'Haridor profili',
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
                      icon: Icons.shopping_bag_rounded,
                      label: '${detail.assignedItems.length} ta mahsulot',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey('admin-customer-detail-admin-toggle'),
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
                  child: _AdminCustomerPanel(
                    detail: detail,
                    savingPhone: savingPhone,
                    regeneratingCode: regeneratingCode,
                    removing: removing,
                    addingItem: addingItem,
                    removingItemCode: removingItemCode,
                    onSavePhone: onSavePhone,
                    onAddItem: onAddItem,
                    onRemoveItem: onRemoveItem,
                    onRegenerateCode: onRegenerateCode,
                    onCopyCode: onCopyCode,
                    onRemove: onRemove,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _AdminCustomerPanel extends StatelessWidget {
  const _AdminCustomerPanel({
    required this.detail,
    required this.savingPhone,
    required this.regeneratingCode,
    required this.removing,
    required this.addingItem,
    required this.removingItemCode,
    required this.onSavePhone,
    required this.onAddItem,
    required this.onRemoveItem,
    required this.onRegenerateCode,
    required this.onCopyCode,
    required this.onRemove,
  });

  final AdminCustomerDetail detail;
  final bool savingPhone;
  final bool regeneratingCode;
  final bool removing;
  final bool addingItem;
  final String? removingItemCode;
  final Future<void> Function(AdminCustomerDetail detail, String phone)
      onSavePhone;
  final Future<void> Function() onAddItem;
  final Future<bool> Function(SupplierItem item) onRemoveItem;
  final Future<void> Function() onRegenerateCode;
  final Future<void> Function(String code) onCopyCode;
  final Future<void> Function() onRemove;

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
        _CustomerPhoneInlineField(
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
                  borderRadius: _customerDetailButtonRadius,
                ),
                onPressed: detail.assignedItems.isEmpty
                    ? null
                    : () => _showAssignedItemsSheet(
                          context,
                          detail,
                          onRemoveItem: onRemoveItem,
                          removingItemCode: removingItemCode,
                        ),
                child: const Text('Ko‘rish'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                style: appOutlinedActionButtonStyle(
                  borderRadius: _customerDetailButtonRadius,
                ),
                onPressed: addingItem ? null : onAddItem,
                child: Text(addingItem ? 'Qo‘shilmoqda...' : 'Qo‘shish'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: appOutlinedActionButtonStyle(
              borderRadius: _customerDetailButtonRadius,
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

class _CustomerPhoneInlineField extends StatefulWidget {
  const _CustomerPhoneInlineField({
    required this.detail,
    required this.savingPhone,
    required this.onSavePhone,
  });

  final AdminCustomerDetail detail;
  final bool savingPhone;
  final Future<void> Function(AdminCustomerDetail detail, String phone)
      onSavePhone;

  @override
  State<_CustomerPhoneInlineField> createState() =>
      _CustomerPhoneInlineFieldState();
}

class _CustomerPhoneInlineFieldState extends State<_CustomerPhoneInlineField> {
  late final TextEditingController _controller;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.detail.phone.trim());
  }

  @override
  void didUpdateWidget(covariant _CustomerPhoneInlineField oldWidget) {
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
                    key: const ValueKey('admin-customer-detail-phone-input'),
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
            key: const ValueKey('admin-customer-detail-phone-action'),
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

String _customerInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'H';
  }
  final first = parts.first.characters.first.toUpperCase();
  if (parts.length == 1) {
    return first;
  }
  return '$first${parts.last.characters.first.toUpperCase()}';
}

Future<void> _showAssignedItemsSheet(
  BuildContext context,
  AdminCustomerDetail detail, {
  required Future<bool> Function(SupplierItem item) onRemoveItem,
  required String? removingItemCode,
}) async {
  final visibleItems = detail.assignedItems.toList();
  final collapsingCodes = <String>{};
  String? activeRemovingCode = removingItemCode;
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Biriktirilgan mahsulotlar',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  detail.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: visibleItems.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];
                      final collapsing = collapsingCodes.contains(item.code);
                      return AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOutCubic,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeInOutCubic,
                          opacity: collapsing ? 0 : 1,
                          child: collapsing
                              ? const SizedBox.shrink()
                              : AppDetailField(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.code,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: activeRemovingCode ==
                                                item.code
                                            ? null
                                            : () async {
                                                setModalState(() {
                                                  activeRemovingCode =
                                                      item.code;
                                                });
                                                final removed =
                                                    await onRemoveItem(item);
                                                if (!context.mounted) {
                                                  return;
                                                }
                                                if (removed) {
                                                  setModalState(() {
                                                    collapsingCodes.add(
                                                      item.code,
                                                    );
                                                  });
                                                  await Future<void>.delayed(
                                                    const Duration(
                                                      milliseconds: 180,
                                                    ),
                                                  );
                                                  if (!context.mounted) {
                                                    return;
                                                  }
                                                  setModalState(() {
                                                    visibleItems.removeWhere(
                                                      (current) =>
                                                          current.code ==
                                                          item.code,
                                                    );
                                                    collapsingCodes.remove(
                                                      item.code,
                                                    );
                                                    activeRemovingCode = null;
                                                  });
                                                } else {
                                                  setModalState(() {
                                                    activeRemovingCode = null;
                                                  });
                                                }
                                              },
                                        icon: activeRemovingCode == item.code
                                            ? const SizedBox(
                                                height: 18,
                                                width: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(Icons.remove_rounded),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
