part of 'admin_production_map_orders_screen.dart';

/// Order cover rasmi (bytes) uchun sessiya ichidagi memo-kesh.
///
/// Bir order uchun serverga faqat bir marta so'rov yuboriladi: muvaffaqiyatli
/// rasm ham, 404/403 (rasm yo'q yoki rolga ruxsat yo'q) ham keshlanadi,
/// ro'yxat qayta chizilganda ortiqcha so'rov ketmaydi.
final Map<String, Future<Uint8List?>> _orderCoverBytesFutures = {};

/// Eng eski yozuvlarni tozalab, keshni chegarada ushlaydi.
void _evictOldOrderCoverBytes() {
  while (_orderCoverBytesFutures.length > 120) {
    _orderCoverBytesFutures.remove(_orderCoverBytesFutures.keys.first);
  }
}

Future<Uint8List?> _productionMapOrderCoverBytes(String orderId) {
  final key = orderId.trim();
  if (key.isEmpty) {
    return Future<Uint8List?>.value();
  }
  return _orderCoverBytesFutures.putIfAbsent(
      key,
      () => _fetchOrderCoverBytes(
            key,
          ));
}

Future<Uint8List?> _fetchOrderCoverBytes(String key) async {
  _evictOldOrderCoverBytes();
  try {
    final bytes = await MobileApi.instance.adminProductionMapOrderImage(key);
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    return Uint8List.fromList(bytes);
  } catch (_) {
    // 403/404/eski server: qator fallback ikonkada qoladi, ro'yxat buzilmaydi.
    return null;
  }
}

/// Ish xaritasi qatorlari uchun chap yon cover-rasm.
///
/// Rasm avval [CalculateOrderTemplateStore] dagi template orqali topiladi.
/// Template API admin rollarga yopiq (403) yoki store hali yuklanmagan
/// bo'lsa — server order-image endpointi orqali yuklanadi, u
/// ApparatusQueueRead/RawMaterialAssign/QolipManage rollariga ham ochiq.
/// Shuning uchun kuzatish/ketma-ketlik sahifalarida boshqa rollarda ham
/// rasmlar chiqadi.
class _ProductionMapOrderCoverImage extends StatelessWidget {
  const _ProductionMapOrderCoverImage({required this.map});

  final ProductionMapDefinition map;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CalculateOrderTemplateStore.instance,
      builder: (context, _) {
        final store = CalculateOrderTemplateStore.instance;
        final template = _calculateTemplateForProductionMap(
          map,
          store.templates,
        );
        final title = map.title.trim().isEmpty
            ? _openedOrderPrimaryTitle(map, l10n: context.l10n)
            : map.title.trim();
        final heroTag = 'production-order-cover-${map.id.trim()}';
        final imageUrl = template?.imageUrl.trim() ?? '';
        if (imageUrl.isNotEmpty) {
          return AdminOrderCoverThumb(
            imageUrl: imageUrl,
            displayName: title,
            heroTag: heroTag,
          );
        }
        if (store.isLoaded) {
          // Template ro'yxati to'liq: bu orderda rasm yo'q.
          return AdminOrderCoverImage(
            displayName: title,
            heroTag: heroTag,
          );
        }
        return FutureBuilder<Uint8List?>(
          future: _productionMapOrderCoverBytes(map.id),
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null || bytes.isEmpty) {
              return AdminOrderCoverImage(
                displayName: title,
                heroTag: heroTag,
              );
            }
            return AdminOrderCoverImage(
              image: MemoryImage(bytes),
              displayName: title,
              heroTag: heroTag,
            );
          },
        );
      },
    );
  }
}
