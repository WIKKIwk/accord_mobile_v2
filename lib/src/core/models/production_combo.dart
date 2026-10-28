/// Immutable catalog revision of a combined printing layout.
/// Child SKUs remain the physical finished-goods outputs.
class ProductionComboReference {
  const ProductionComboReference({
    required this.id,
    required this.itemCode,
    required this.name,
    required this.revision,
    required this.layoutFingerprint,
  });

  final String id;
  final String itemCode;
  final String name;
  final int revision;
  final String layoutFingerprint;

  static ProductionComboReference? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = value.cast<String, dynamic>();
    return ProductionComboReference(
      id: json['id']?.toString() ?? '',
      itemCode: json['item_code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      layoutFingerprint: json['layout_fingerprint']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'item_code': itemCode,
        'name': name,
        'revision': revision,
        'layout_fingerprint': layoutFingerprint,
      };
}
