import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'package:flutter/material.dart';

part 'admin_item_detail_editors.dart';

typedef AdminItemDetailLoader = Future<AdminItemDetail> Function(String code);
typedef AdminItemUpdater = Future<AdminItemDetail> Function({
  required String originalCode,
  required String code,
  required String name,
});
typedef AdminItemGroupsLoader = Future<List<String>> Function();
typedef AdminItemGroupUpdater = Future<AdminItemDetail> Function({
  required String itemCode,
  required String itemGroup,
});
typedef AdminCustomersLoader = Future<List<CustomerDirectoryEntry>> Function({
  String query,
  int limit,
  int offset,
});
typedef AdminItemCustomerUpdater = Future<AdminItemDetail> Function({
  required String itemCode,
  required CustomerDirectoryEntry customer,
  required bool assigned,
});
typedef AdminItemDeleter = Future<void> Function(String itemCode);

class AdminItemDetailScreen extends StatefulWidget {
  const AdminItemDetailScreen({
    super.key,
    required this.itemCode,
    this.loadDetail,
    this.updateItem,
    this.loadItemGroups,
    this.updateItemGroup,
    this.loadCustomers,
    this.updateItemCustomer,
    this.deleteItem,
  });

  final String itemCode;
  final AdminItemDetailLoader? loadDetail;
  final AdminItemUpdater? updateItem;
  final AdminItemGroupsLoader? loadItemGroups;
  final AdminItemGroupUpdater? updateItemGroup;
  final AdminCustomersLoader? loadCustomers;
  final AdminItemCustomerUpdater? updateItemCustomer;
  final AdminItemDeleter? deleteItem;

  @override
  State<AdminItemDetailScreen> createState() => _AdminItemDetailScreenState();
}

class _AdminItemDetailScreenState extends State<AdminItemDetailScreen> {
  late String _itemCode;
  late Future<AdminItemDetail> _detailFuture;
  bool _saving = false;
  bool _changingGroup = false;
  bool _deleting = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _itemCode = widget.itemCode.trim();
    _detailFuture = _load();
  }

  Future<AdminItemDetail> _load() {
    final loader = widget.loadDetail ?? MobileApi.instance.adminItemDetail;
    return loader(_itemCode);
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() => _detailFuture = future);
    await future;
  }

  Future<void> _edit(AdminItemDetail detail) async {
    if (_saving || _changingGroup || _deleting) {
      return;
    }
    final draft = await showDialog<_AdminItemEditDraft>(
      context: context,
      barrierDismissible: !_saving,
      builder: (_) => _AdminItemEditDialog(detail: detail),
    );
    if (draft == null || !mounted) {
      return;
    }
    if (draft.code == detail.code && draft.name == detail.name) {
      return;
    }

    setState(() => _saving = true);
    try {
      final updater = widget.updateItem ?? MobileApi.instance.adminUpdateItem;
      final updated = await updater(
        originalCode: detail.code,
        code: draft.code,
        name: draft.name,
      );
      if (!mounted) {
        return;
      }
      _changed = true;
      _itemCode = updated.code;
      setState(() {
        _detailFuture = Future<AdminItemDetail>.value(updated);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.adminText('detail.item_saved')),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showError(String fallback, Object error) {
    if (!mounted) {
      return;
    }
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.isEmpty ? fallback : message)),
    );
  }

  Future<void> _delete(AdminItemDetail detail) async {
    if (_saving || _changingGroup || _deleting) {
      return;
    }
    final itemName =
        detail.name.trim().isEmpty ? detail.code.trim() : detail.name.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.delete_forever_rounded, color: scheme.error),
          title: Text(l10n.adminText('detail.item_delete_title')),
          content: Text(
            l10n.adminText(
              'detail.item_delete_message',
              values: {'name': itemName, 'code': detail.code},
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('admin-item-delete-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.adminText('action.cancel')),
            ),
            FilledButton.icon(
              key: const ValueKey('admin-item-delete-confirm'),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_forever_rounded),
              label: Text(l10n.adminText('action.delete')),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _deleting = true);
    try {
      final deleter = widget.deleteItem ?? MobileApi.instance.adminDeleteItem;
      await deleter(detail.code);
    } catch (error) {
      if (mounted) {
        setState(() => _deleting = false);
      }
      _showError(
        context.l10n.adminText('detail.item_delete_failed'),
        error,
      );
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _deleting = false;
      _changed = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.adminText('detail.item_deleted'))),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _changeGroup(AdminItemDetail detail) async {
    if (_saving || _changingGroup || _deleting) {
      return;
    }
    setState(() => _changingGroup = true);
    try {
      final loader =
          widget.loadItemGroups ?? MobileApi.instance.adminItemGroups;
      final groups = await loader();
      if (!mounted) {
        return;
      }
      setState(() => _changingGroup = false);
      final selected = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _ItemGroupPickerSheet(
          groups: groups,
          currentGroup: detail.itemGroup,
        ),
      );
      if (selected == null ||
          selected.trim().isEmpty ||
          selected.trim().toLowerCase() ==
              detail.itemGroup.trim().toLowerCase() ||
          !mounted) {
        return;
      }
      setState(() => _changingGroup = true);
      final updater =
          widget.updateItemGroup ?? MobileApi.instance.adminUpdateItemGroup;
      final updated = await updater(
        itemCode: detail.code,
        itemGroup: selected,
      );
      if (!mounted) {
        return;
      }
      _changed = true;
      setState(() {
        _detailFuture = Future<AdminItemDetail>.value(updated);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.adminText('detail.group_updated')),
        ),
      );
    } catch (error) {
      _showError(context.l10n.adminText('detail.groups_save_failed'), error);
    } finally {
      if (mounted) {
        setState(() => _changingGroup = false);
      }
    }
  }

  Future<AdminItemDetail> _setCustomerAssigned({
    required AdminItemDetail detail,
    required CustomerDirectoryEntry customer,
    required bool assigned,
  }) async {
    final updater = widget.updateItemCustomer ??
        MobileApi.instance.adminSetItemCustomerAssigned;
    final updated = await updater(
      itemCode: detail.code,
      customer: customer,
      assigned: assigned,
    );
    if (mounted) {
      _changed = true;
      setState(() {
        _detailFuture = Future<AdminItemDetail>.value(updated);
      });
    }
    return updated;
  }

  Future<void> _manageCustomers(AdminItemDetail detail) async {
    if (_saving || _changingGroup || _deleting) {
      return;
    }
    final loader = widget.loadCustomers ?? MobileApi.instance.adminCustomers;
    final updated = await showModalBottomSheet<AdminItemDetail>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ItemCustomerPickerSheet(
        detail: detail,
        loadCustomers: loader,
        onSetAssigned: ({required customer, required assigned}) {
          return _setCustomerAssigned(
            detail: detail,
            customer: customer,
            assigned: assigned,
          );
        },
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _detailFuture = Future<AdminItemDetail>.value(updated);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.of(context).pop(_changed);
        }
      },
      child: AppShell(
        title: context.l10n.adminText('detail.item_title'),
        subtitle: '',
        nativeTopBar: true,
        nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
        showProfileAction: false,
        contentPadding: EdgeInsets.zero,
        bottom: const AdminDock(
          activeTab: AdminDockTab.settings,
          showPrimaryFab: false,
        ),
        child: ColoredBox(
          color: AppTheme.shellStart(context),
          child: SafeArea(
            top: false,
            child: FutureBuilder<AdminItemDetail>(
              future: _detailFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: AppLoadingIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                    children: [
                      AppRetryState(
                        onRetry: _reload,
                        message: context.l10n.adminText(
                          'detail.item_load_failed',
                        ),
                      ),
                    ],
                  );
                }
                final detail = snapshot.data!;
                final mutationBusy = _saving || _changingGroup || _deleting;
                final l10n = context.l10n;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 120),
                  children: [
                    _ItemDetailHeader(
                      detail: detail,
                      saving: _saving,
                      disabled: _changingGroup || _deleting,
                      onEdit: () => _edit(detail),
                    ),
                    const SizedBox(height: 10),
                    _ItemDetailSection(
                      title: l10n.adminText('detail.main_info'),
                      children: [
                        _ItemDetailRow(
                          label: l10n.adminText('detail.item_name'),
                          value: detail.name,
                        ),
                        _ItemDetailRow(
                          label: l10n.adminText('detail.item_code'),
                          value: detail.code,
                        ),
                        _ItemDetailRow(
                          label: l10n.adminText('item.group'),
                          value: detail.itemGroup,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              key: const ValueKey(
                                'admin-item-detail-change-group',
                              ),
                              onPressed: mutationBusy
                                  ? null
                                  : () => _changeGroup(detail),
                              icon: _changingGroup
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.account_tree_rounded),
                              label: Text(
                                _changingGroup
                                    ? l10n.adminText('detail.groups_loading')
                                    : l10n.adminText('detail.change_group'),
                              ),
                            ),
                          ),
                        ),
                        _ItemDetailRow(
                          label: l10n.adminText('item.uom_label'),
                          value: detail.uom,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ItemDetailSection(
                      title: l10n.adminText('detail.system_info'),
                      children: [
                        _ItemDetailRow(
                          label: l10n.adminText('detail.created_at'),
                          value: formatUnixSecondsLocalDateTime(
                            detail.createdAtUnix,
                          ),
                          emptyText: l10n.adminText('detail.date_missing'),
                        ),
                        _ItemDetailRow(
                          label: l10n.adminText('detail.updated_at'),
                          value: formatUnixSecondsLocalDateTime(
                            detail.updatedAtUnix,
                          ),
                          emptyText: l10n.adminText('detail.not_changed'),
                        ),
                      ],
                    ),
                    if (detail.isFinishedGoods) ...[
                      const SizedBox(height: 10),
                      _ItemCustomersSection(
                        customers: detail.customers,
                        enabled: !mutationBusy,
                        onManage: () => _manageCustomers(detail),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _ItemDeleteSection(
                      deleting: _deleting,
                      enabled: !_saving && !_changingGroup,
                      onDelete: () => _delete(detail),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemDetailHeader extends StatelessWidget {
  const _ItemDetailHeader({
    required this.detail,
    required this.saving,
    required this.disabled,
    required this.onEdit,
  });

  final AdminItemDetail detail;
  final bool saving;
  final bool disabled;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.name.trim().isEmpty ? detail.code : detail.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail.code,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (detail.isFinishedGoods) ...[
              const SizedBox(height: 14),
              Chip(
                avatar: Icon(Icons.task_alt_rounded, size: 18),
                label: Text(l10n.adminText('detail.finished_product')),
                visualDensity: VisualDensity.compact,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('admin-item-detail-edit'),
                onPressed: saving || disabled ? null : onEdit,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_rounded),
                label: Text(
                  saving
                      ? l10n.adminText('action.saving')
                      : l10n.adminText('detail.edit_name_code'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemDetailSection extends StatelessWidget {
  const _ItemDetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ItemDetailRow extends StatelessWidget {
  const _ItemDetailRow({
    required this.label,
    required this.value,
    this.emptyText = '',
  });

  final String label;
  final String value;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayValue = value.trim().isEmpty
        ? (emptyText.trim().isEmpty
            ? context.l10n.adminText('profile.entered')
            : emptyText)
        : value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 6,
            child: Text(
              displayValue,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCustomersSection extends StatelessWidget {
  const _ItemCustomersSection({
    required this.customers,
    required this.enabled,
    required this.onManage,
  });

  final List<CustomerDirectoryEntry> customers;
  final bool enabled;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _ItemDetailSection(
      title: customers.length > 1
          ? l10n.adminText('detail.customers')
          : l10n.adminText('detail.customer'),
      children: customers.isEmpty
          ? [
              _ItemDetailRow(
                label: l10n.adminText('detail.customer'),
                value: '',
                emptyText: l10n.adminText('detail.unassigned'),
              ),
              _CustomerManageButton(onPressed: enabled ? onManage : null),
            ]
          : [
              for (final customer in customers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const CircleAvatar(
                      child: Icon(Icons.business_rounded),
                    ),
                    title: Text(customer.name),
                    subtitle: Text(
                      [customer.ref, customer.phone]
                          .where((value) => value.trim().isNotEmpty)
                          .join(' • '),
                    ),
                  ),
                ),
              _CustomerManageButton(onPressed: enabled ? onManage : null),
            ],
    );
  }
}

class _ItemDeleteSection extends StatelessWidget {
  const _ItemDeleteSection({
    required this.deleting,
    required this.enabled,
    required this.onDelete,
  });

  final bool deleting;
  final bool enabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return _ItemDetailSection(
      title: l10n.adminText('detail.item_delete_title'),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            l10n.adminText('detail.delete_description'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('admin-item-detail-delete'),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error),
              ),
              onPressed: enabled && !deleting ? onDelete : null,
              icon: deleting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever_rounded),
              label: Text(
                deleting
                    ? l10n.adminText('detail.delete_in_progress')
                    : l10n.adminText('detail.item_delete_title'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
