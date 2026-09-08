part of 'admin_production_map_orders_screen.dart';

/// Every viewer uses the same order-authorized image route as the detail
/// sheet. An admin's private template cache is not an order-image authority.
class _ProductionMapOrderCoverImage extends StatelessWidget {
  const _ProductionMapOrderCoverImage({required this.map});

  final ProductionMapDefinition map;

  @override
  Widget build(BuildContext context) {
    final title = map.title.trim().isEmpty
        ? _openedOrderPrimaryTitle(map, l10n: context.l10n)
        : map.title.trim();
    return AdminOrderCoverThumb(
      imageUrl: MobileApi.instance.adminProductionMapOrderImageUrl(
        map.id,
        imageId: map.imageId,
      ),
      displayName: title,
      heroTag: 'production-order-cover-${map.id.trim()}',
    );
  }
}
