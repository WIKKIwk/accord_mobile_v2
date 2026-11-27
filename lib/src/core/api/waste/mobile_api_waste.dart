part of '../mobile_api.dart';

String newWasteRequestId() {
  final random = waste_math.Random.secure();
  final suffix = List.generate(16, (_) => random.nextInt(256))
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'waste-$suffix';
}

const wasteBinQrPrefix = 'ACCORD-WASTE:';

bool isWasteBinQr(String value) {
  if (!value.trim().toUpperCase().startsWith(wasteBinQrPrefix)) return false;
  try {
    wasteBinCode(value);
    return true;
  } on FormatException {
    return false;
  }
}

String wasteBinCode(String value) {
  final input = value.trim().toUpperCase();
  final code = input.startsWith(wasteBinQrPrefix)
      ? input.substring(wasteBinQrPrefix.length)
      : input;
  if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]{0,39}$').hasMatch(code)) {
    throw const FormatException('Chiqindi qutisining QR kodini kiriting');
  }
  return code;
}

enum WasteBinStatus { empty, open, sealed, received, reset }

class WasteBinApparatusOption {
  const WasteBinApparatusOption({required this.id, required this.name});

  final String id, name;
}

class WasteBinOptions {
  WasteBinOptions.fromJson(Map<String, dynamic> json)
      : apparatuses = List.unmodifiable(
          (json['apparatuses'] as List).map(
            (row) => WasteBinApparatusOption(
              id: row['id'] as String,
              name: row['name'] as String,
            ),
          ),
        );

  final List<WasteBinApparatusOption> apparatuses;
}

class WasteBinConfiguration {
  const WasteBinConfiguration({
    required this.name,
    required this.apparatusIds,
  });

  final String name;
  final List<String> apparatusIds;

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'apparatus_ids': apparatusIds,
      };
}

class WasteWarehouse {
  WasteWarehouse.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        warehouse = json['warehouse'] as String,
        onHandKg = _wasteKg(json['on_hand_kg']),
        receiptCount = json['receipt_count'] as int;

  final String id;
  final String warehouse;
  final double onHandKg;
  final int receiptCount;
}

class WasteBin {
  WasteBin.fromJson(Map<String, dynamic> json)
      : code = json['code'] as String,
        _name = (json['name'] as String?)?.trim() ?? '',
        qrPayload = json['qr_payload'] as String,
        tareKg = _wasteKg(json['tare_kg']),
        toleranceKg = _wasteKg(json['tolerance_kg']),
        status = WasteBinStatus.values.byName(json['status'] as String),
        configured = json['configured'] as bool? ?? false,
        apparatusIds =
            List<String>.unmodifiable(json['apparatus_ids'] as List? ?? []),
        cycle = json['cycle'] == null
            ? null
            : WasteCycle.fromJson(json['cycle'] as Map<String, dynamic>);

  final String code;
  final String _name;
  final String qrPayload;
  final double tareKg;
  final double toleranceKg;
  final WasteBinStatus status;
  final bool configured;
  final List<String> apparatusIds;
  final WasteCycle? cycle;

  String get name => _name.isEmpty ? code : _name;
  String get label => name == code ? code : '$name · $code';
  bool get canBeReceived =>
      cycle != null &&
      (status == WasteBinStatus.open || status == WasteBinStatus.sealed);
}

class WasteCycle {
  WasteCycle.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        apparatusId = json['apparatus_id'] as String,
        apparatusName = (json['apparatus_name'] as String?)?.trim() ?? '',
        status = WasteBinStatus.values.byName(json['status'] as String),
        expectedKg = _wasteKg(json['expected_kg']),
        entries = List.unmodifiable(
          (json['entries'] as List<dynamic>? ?? const []).map(
            (row) => WasteEntry.fromJson(row as Map<String, dynamic>),
          ),
        ),
        receipt = json['receipt'] == null
            ? null
            : WasteReceipt.fromJson(json['receipt'] as Map<String, dynamic>),
        openedAt = _wasteDate(json['opened_at_unix']),
        sealedAt = _wasteDate(json['sealed_at_unix']),
        resetAt = _wasteDate(json['reset_at_unix']),
        openedBy = json['opened_by_display_name'] as String? ?? '',
        sealedBy = json['sealed_by_display_name'] as String? ?? '',
        sealedOnReceipt = json['sealed_on_receipt'] == true,
        resetBy = json['reset_by_display_name'] as String? ?? '';

  final String id, apparatusId, apparatusName;
  final WasteBinStatus status;
  final double expectedKg;
  final List<WasteEntry> entries;
  final WasteReceipt? receipt;
  final DateTime? openedAt, sealedAt, resetAt;
  final String openedBy, sealedBy, resetBy;
  final bool sealedOnReceipt;
}

class WasteEntry {
  WasteEntry.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        actorRef = json['actor_ref'] as String? ?? '',
        actorName = json['actor_display_name'] as String? ?? '',
        orderId = json['order_id'] as String? ?? '',
        reason = json['reason'] as String? ?? '',
        kg = _wasteKg(json['kg']),
        createdAt = _wasteDate(json['created_at_unix']);

  final String id, actorRef, actorName, orderId, reason;
  final double kg;
  final DateTime? createdAt;
}

class WasteReceipt {
  WasteReceipt.fromJson(Map<String, dynamic> json)
      : grossKg = _wasteKg(json['gross_kg']),
        tareKg = _wasteKg(json['tare_kg']),
        netKg = _wasteKg(json['net_kg']),
        expectedKg = _wasteKg(json['expected_kg']),
        differenceKg = _wasteKg(json['difference_kg']),
        measurementSource = json['measurement_source'] as String,
        note = json['note'] as String? ?? '',
        receivedBy = json['received_by_display_name'] as String? ?? '',
        receivedAt = _wasteDate(json['received_at_unix']),
        warehouseId = json['warehouse_id'] as String?,
        warehouse = json['warehouse'] as String?,
        outsideTolerance = json['outside_tolerance'] as bool? ?? false;

  final double grossKg, tareKg, netKg, expectedKg, differenceKg;
  final String measurementSource, note, receivedBy;
  final DateTime? receivedAt;
  final String? warehouseId, warehouse;
  final bool outsideTolerance;
}

double _wasteKg(Object? value) {
  final kg = value is num
      ? value.toDouble()
      : value is String
          ? double.tryParse(value)
          : null;
  if (kg == null || !kg.isFinite) {
    throw const FormatException('Chiqindi vazni tasdiqlanmadi');
  }
  return kg;
}

DateTime? _wasteDate(Object? value) => value == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch((value as int) * 1000, isUtc: true)
        .toLocal();

class WasteActiveBins {
  WasteActiveBins.fromJson(Map<String, dynamic> json)
      : bin = json['bin'] == null
            ? null
            : WasteBin.fromJson(json['bin'] as Map<String, dynamic>),
        pending = List.unmodifiable(
          (json['pending'] as List<dynamic>).map(
            (row) => WasteEntry.fromJson(row as Map<String, dynamic>),
          ),
        );

  final WasteBin? bin;
  final List<WasteEntry> pending;
}

extension MobileApiWaste on MobileApi {
  Future<WasteBinOptions> wasteBinOptions() async =>
      WasteBinOptions.fromJson(await _wasteRequest('bins/options', query: {
        'apparatus_only': 'true',
      }));

  Future<List<WasteWarehouse>> wasteWarehouses() async {
    final data = await _wasteRequest('warehouses');
    return (data['warehouses'] as List)
        .map((row) => WasteWarehouse.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<WasteBin>> wasteBins({
    String? apparatusId,
    WasteBinStatus? status,
  }) async {
    final data = await _wasteRequest('bins', query: {
      if (apparatusId != null) 'apparatus_id': apparatusId,
      if (status != null) 'status': status.name,
    });
    return (data['bins'] as List)
        .map((row) => WasteBin.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<WasteActiveBins> activeWasteBin(String apparatusId) async =>
      WasteActiveBins.fromJson(await _wasteRequest('bins/active', query: {
        'apparatus_id': apparatusId,
      }));

  Future<WasteBin> wasteBinDetail(String code, {String? cycleId}) async =>
      WasteBin.fromJson(await _wasteRequest('bins/detail', query: {
        'code': wasteBinCode(code),
        if (cycleId != null) 'cycle_id': cycleId,
      }));

  Future<List<WasteCycle>> wasteBinHistory(String code) async {
    final data = await _wasteRequest('bins/history', query: {
      'code': wasteBinCode(code),
    });
    return (data['cycles'] as List)
        .map((row) => WasteCycle.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<WasteBin> registerWasteBin({
    required String requestId,
    required double tareKg,
    required WasteBinConfiguration configuration,
    double? toleranceKg,
  }) =>
      _wasteBinMutation('register', {
        'request_id': requestId,
        'tare_kg': tareKg,
        if (toleranceKg != null) 'tolerance_kg': toleranceKg,
        ...configuration.toJson(),
      });

  Future<WasteBin> configureWasteBin({
    required String code,
    required WasteBinConfiguration configuration,
  }) =>
      _wasteBinMutation('configure', {
        'code': wasteBinCode(code),
        ...configuration.toJson(),
      });

  Future<WasteBin> assignWasteBin(String code, String apparatusId) =>
      _wasteBinMutation('assign', {
        'code': wasteBinCode(code),
        'apparatus_id': apparatusId,
      });

  Future<WasteBin> submitWasteBin({
    required WasteBin bin,
    required String apparatusId,
    String? replacementCode,
  }) =>
      _wasteBinMutation('submit', {
        ..._wasteIdentity(bin),
        'apparatus_id': apparatusId,
        if (replacementCode != null)
          'replacement_code': wasteBinCode(replacementCode),
      });

  Future<WasteBin> reconcileWasteEntries({
    required WasteBin bin,
    required String apparatusId,
    required List<String> entryIds,
  }) =>
      _wasteBinMutation('reconcile', {
        ..._wasteIdentity(bin),
        'apparatus_id': apparatusId,
        'entry_ids': entryIds,
      });

  Future<WasteBin> receiveWasteBin({
    required WasteBin bin,
    required String warehouseId,
    required double grossKg,
    required String source,
    required String note,
  }) =>
      _wasteBinMutation('receive', {
        ..._wasteIdentity(bin),
        'warehouse_id': warehouseId,
        'gross_kg': grossKg,
        if (bin.status == WasteBinStatus.open)
          'checked_expected_kg': bin.cycle!.expectedKg,
        'measurement_source': source,
        if (note.isNotEmpty) 'note': note,
      });

  Future<WasteBin> assignWasteReceiptDestination({
    required WasteBin bin,
    required String warehouseId,
  }) =>
      _wasteBinMutation('destination', {
        ..._wasteIdentity(bin),
        'warehouse_id': warehouseId,
      });

  Future<WasteBin> resetWasteBin(WasteBin bin) =>
      _wasteBinMutation('reset', _wasteIdentity(bin));

  Map<String, String> _wasteIdentity(WasteBin bin) => {
        'code': bin.code,
        'cycle_id': bin.cycle!.id,
      };

  Future<WasteBin> _wasteBinMutation(
    String action,
    Map<String, dynamic> body,
  ) async =>
      WasteBin.fromJson(await _wasteRequest('bins/$action', body: body));

  Future<Map<String, dynamic>> _wasteRequest(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final scope = currentSessionReadScope();
    final uri = Uri.parse('${MobileApi.baseUrl}/v1/mobile/waste/$path')
        .replace(queryParameters: query);
    final response = await _sendAuthorized(() {
      if (scope != currentSessionReadScope()) {
        throw StateError('Akkaunt o‘zgardi. Amalni qaytadan boshlang.');
      }
      final headers = _headers(requireToken());
      return body == null
          ? _get(uri, headers: headers)
          : _post(uri,
              headers: headers..['Content-Type'] = 'application/json',
              body: jsonEncode(body),
              invalidatesSnapshots: false);
    });
    if (scope != currentSessionReadScope()) {
      throw StateError('Akkaunt o‘zgardi. Amalni qaytadan boshlang.');
    }
    Object? decoded;
    try {
      decoded = await decodeJsonPayload(response.body);
    } on FormatException {
      decoded = null;
    }
    if (scope != currentSessionReadScope()) {
      throw StateError('Akkaunt o‘zgardi. Amalni qaytadan boshlang.');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map<String, dynamic>) {
      final error = decoded is Map ? decoded['error'] : null;
      final code = decoded is Map ? decoded['code'] : null;
      throw MobileApiException(
        code: code is String ? code : 'waste_request_failed',
        statusCode: response.statusCode,
        message:
            error is String ? error : 'Chiqindi so‘rovini bajarib bo‘lmadi',
      );
    }
    return decoded;
  }
}
