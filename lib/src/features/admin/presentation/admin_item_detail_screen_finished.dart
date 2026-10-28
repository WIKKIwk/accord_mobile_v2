part of 'admin_item_detail_screen.dart';

class _FinishedItemDetailView extends StatelessWidget {
  const _FinishedItemDetailView({
    required this.detail,
    required this.actionsEnabled,
    required this.onActions,
  });

  final AdminItemDetail detail;
  final bool actionsEnabled;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final orderId = detail.orderImageOrderId.trim();
    final imageUrl = orderId.isEmpty
        ? ''
        : MobileApi.instance.adminProductionMapOrderImageUrl(orderId);
    final group = detail.itemGroup.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 120),
      children: [
        _ItemDetailHeader(
          detail: detail,
          saving: false,
          disabled: !actionsEnabled,
          onEdit: () {},
          finishedImageUrl: imageUrl,
          onFinishedActions: actionsEnabled ? onActions : null,
        ),
        const SizedBox(height: 10),
        KeyedSubtree(
          key: const ValueKey('admin-finished-item-information'),
          child: _ItemDetailSection(
            title: l10n.adminText('detail.main_info'),
            children: [
              if (group.isNotEmpty && group.toLowerCase() != 'tayyor mahsulot')
                _ItemDetailRow(
                    label: l10n.adminText('item.group'), value: group),
              _ItemDetailRow(
                label: l10n.adminText('item.uom_label'),
                value: detail.uom,
              ),
              const Divider(height: 1),
              _ItemDetailRow(
                label: l10n.adminText('detail.created_at'),
                value: formatUnixSecondsLocalDateTime(detail.createdAtUnix),
                emptyText: l10n.adminText('detail.date_missing'),
              ),
              _ItemDetailRow(
                label: l10n.adminText('detail.updated_at'),
                value: formatUnixSecondsLocalDateTime(detail.updatedAtUnix),
                emptyText: l10n.adminText('detail.not_changed'),
              ),
              const Divider(height: 1),
              _ItemDetailCustomers(customers: detail.customers),
            ],
          ),
        ),
      ],
    );
  }
}
