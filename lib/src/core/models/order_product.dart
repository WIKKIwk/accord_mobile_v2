/// One ordered product block on a common customer's printing layout.
class OrderProduct {
  const OrderProduct({
    required this.id,
    required this.itemCode,
    required this.product,
    required this.frameProductSizeMm,
    required this.frameCount,
  });

  final String id;
  final String itemCode;
  final String product;
  final double frameProductSizeMm;
  final int frameCount;
  double get widthMm => frameProductSizeMm * frameCount;

  factory OrderProduct.fromJson(Map<String, dynamic> json) => OrderProduct(
        id: json['id'] as String? ?? '',
        itemCode: json['item_code'] as String? ?? '',
        product: json['product'] as String? ?? '',
        frameProductSizeMm:
            (json['frame_product_size_mm'] as num?)?.toDouble() ?? 0,
        frameCount: (json['frame_count'] as num?)?.toInt() ?? 0,
      );

  static List<OrderProduct> listFromJson(Object? value) =>
      (value is List ? value : const [])
          .whereType<Map>()
          .map(
            (item) => OrderProduct.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false);

  Map<String, dynamic> toJson() => {
        'id': id,
        'item_code': itemCode,
        'product': product,
        'frame_product_size_mm': frameProductSizeMm,
        'frame_count': frameCount,
      };
}
