class MaterialLinkRoll {
  MaterialLinkRoll.fromJson(Map<String, dynamic> json)
      : barcode = json['barcode']?.toString() ?? '',
        itemName = json['item_name']?.toString() ?? '',
        qty = (json['qty'] as num?)?.toDouble() ?? 0,
        uom = json['uom']?.toString() ?? '',
        locationName = json['location_name']?.toString() ?? '';

  final String barcode;
  final String itemName;
  final double qty;
  final String uom;
  final String locationName;
}

class MaterialLinkRequest {
  MaterialLinkRequest.fromJson(Map<String, dynamic> json)
      : id = json['request_id']?.toString() ?? '',
        status = json['status']?.toString() ?? '',
        revision = (json['event_sequence'] as num?)?.toInt() ?? 0,
        orderId = json['order_id']?.toString() ?? '',
        orderNumber = json['order_number']?.toString() ?? '',
        apparatusId = json['apparatus_id']?.toString() ?? '',
        apparatusName = json['apparatus_name']?.toString() ?? '',
        requesterRef = json['requester_ref']?.toString() ?? '',
        requesterName = json['requester_display_name']?.toString() ?? '',
        moverRef = json['mover_ref']?.toString() ?? '',
        moverName = json['mover_display_name']?.toString() ?? '',
        decidedBy = json['decided_by_name']?.toString() ?? '',
        decidedAt = (json['decided_at_unix'] as num?)?.toInt() ?? 0,
        reason = json['reason']?.toString() ?? '',
        expiresAt = (json['expires_at_unix'] as num?)?.toInt() ?? 0,
        rolls = (json['candidates'] as List? ?? const [])
            .whereType<Map>()
            .map((row) =>
                MaterialLinkRoll.fromJson(Map<String, dynamic>.from(row)))
            .toList(),
        selectedBarcodes = (json['selected_barcodes'] as List? ?? const [])
            .map((value) => value.toString())
            .toList();

  final String id, status, orderId, orderNumber, apparatusId, apparatusName;
  final String requesterRef,
      requesterName,
      moverRef,
      moverName,
      decidedBy,
      reason;
  final int revision, decidedAt, expiresAt;
  final List<MaterialLinkRoll> rolls;
  final List<String> selectedBarcodes;
  bool get pending => status == 'pending';
  String get statusLabel => switch (status) {
        'pending' => 'Tasdiq kutilmoqda',
        'approved' => 'Tasdiqlangan',
        'cancelled' => 'Bekor qilingan',
        'stale' => 'Holati o‘zgargan — so‘rov yopilgan',
        'expired' => 'So‘rov muddati tugagan',
        _ => 'Holatni yangilang',
      };
}

class MaterialLinkOverview {
  MaterialLinkOverview.fromJson(Map<String, dynamic> json)
      : availableCount = (json['available_count'] as num?)?.toInt() ?? 0,
        candidates = (json['candidates'] as List? ?? const [])
            .whereType<Map>()
            .map((row) =>
                MaterialLinkRoll.fromJson(Map<String, dynamic>.from(row)))
            .toList(),
        requests = (json['requests'] as List? ?? const [])
            .whereType<Map>()
            .map((row) =>
                MaterialLinkRequest.fromJson(Map<String, dynamic>.from(row)))
            .toList();
  final int availableCount;
  final List<MaterialLinkRoll> candidates;
  final List<MaterialLinkRequest> requests;
}
