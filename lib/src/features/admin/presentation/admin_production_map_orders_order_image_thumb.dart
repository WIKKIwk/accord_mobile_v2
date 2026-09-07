part of 'admin_production_map_orders_screen.dart';

/// Ish xaritasi qatorlari uchun chap yon cover-rasm.
///
/// Rasm [CalculateOrderTemplateStore] dagi template orqali topiladi
/// (order -> sourceMapId bog'lanishi). Store yangilanganda
/// [AnimatedBuilder] orqali qator o'zi qayta chiziladi, shuning uchun
/// ota widgetlarga qo'shimcha plumbing kerak emas.
class _ProductionMapOrderCoverImage extends StatelessWidget {
  const _ProductionMapOrderCoverImage({required this.map});

  final ProductionMapDefinition map;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CalculateOrderTemplateStore.instance,
      builder: (context, _) {
        final template = _calculateTemplateForProductionMap(
          map,
          CalculateOrderTemplateStore.instance.templates,
        );
        final title = map.title.trim().isEmpty
            ? _openedOrderPrimaryTitle(map, l10n: context.l10n)
            : map.title.trim();
        return AdminOrderCoverThumb(
          imageUrl: template?.imageUrl ?? '',
          displayName: title,
          heroTag: 'production-order-cover-${map.id.trim()}',
        );
      },
    );
  }
}
