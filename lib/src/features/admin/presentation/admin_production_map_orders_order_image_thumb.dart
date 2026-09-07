part of 'admin_production_map_orders_screen.dart';

/// Ish xaritasi qatorlari uchun tezkor buyurtma rasmini reuse qiladi.
///
/// Rasm [CalculateOrderTemplateStore] dagi template orqali topiladi
/// (order -> sourceMapId bog'lanishi). Store yangilanganda
/// [AnimatedBuilder] orqali qator o'zi qayta chiziladi, shuning uchun
/// ota widgetlarga qo'shimcha plumbing kerak emas.
class _ProductionMapOrderImageThumb extends StatelessWidget {
  const _ProductionMapOrderImageThumb({required this.map});

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
        return AdminOrderImageThumb(
          imageUrl: template?.imageUrl ?? '',
          displayName: title,
          heroTag: 'production-order-image-${map.id.trim()}',
        );
      },
    );
  }
}
