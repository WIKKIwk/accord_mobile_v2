part of '../mobile_api.dart';

extension MobileApiRezka on MobileApi {
  Future<RezkaSourceResponse> rezkaSource({required String barcode}) async {
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/rezka/source').replace(
          queryParameters: {'barcode': barcode.trim()},
        ),
        headers: _headers(requireToken()),
      ),
    );
    final payload = _rezkaDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _rezkaText(payload['error'], fallback: 'rezka_source_failed'),
        message: _rezkaText(
          payload['detail'],
          fallback: _rezkaText(
            payload['message'],
            fallback: 'Rezka source failed',
          ),
        ),
        statusCode: response.statusCode,
      );
    }
    return RezkaSourceResponse.fromJson(payload);
  }

  Future<RezkaSplitResponse> rezkaSplit(RezkaSplitRequest request) async {
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/rezka/split'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(request.toJson()),
      ),
    );
    final payload = _rezkaDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _rezkaText(payload['error'], fallback: 'rezka_split_failed'),
        message: _rezkaText(
          payload['detail'],
          fallback: _rezkaText(
            payload['message'],
            fallback: 'Rezka split failed',
          ),
        ),
        statusCode: response.statusCode,
      );
    }
    return RezkaSplitResponse.fromJson(payload);
  }
}

class RezkaSourceResponse {
  const RezkaSourceResponse({
    required this.ok,
    required this.source,
  });

  factory RezkaSourceResponse.fromJson(Map<String, dynamic> json) {
    final sourceJson =
        (json['source'] as Map?)?.cast<String, dynamic>() ?? const {};
    return RezkaSourceResponse(
      ok: json['ok'] == true,
      source: RezkaSourceEntry.fromJson(sourceJson),
    );
  }

  final bool ok;
  final RezkaSourceEntry source;
}

class RezkaSourceEntry {
  const RezkaSourceEntry({
    required this.barcode,
    required this.stockEntryName,
    required this.lineIndex,
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.uom,
    required this.warehouse,
    required this.company,
  });

  factory RezkaSourceEntry.fromJson(Map<String, dynamic> json) {
    return RezkaSourceEntry(
      barcode: _rezkaText(json['barcode']),
      stockEntryName: _rezkaText(json['stock_entry_name']),
      lineIndex: (_rezkaNumber(json['line_index'])).toInt(),
      itemCode: _rezkaText(json['item_code']),
      itemName: _rezkaText(json['item_name']),
      qty: _rezkaNumber(json['qty']),
      uom: _rezkaText(json['uom']),
      warehouse: _rezkaText(json['warehouse']),
      company: _rezkaText(json['company']),
    );
  }

  final String barcode;
  final String stockEntryName;
  final int lineIndex;
  final String itemCode;
  final String itemName;
  final double qty;
  final String uom;
  final String warehouse;
  final String company;

  String get displayName => itemName.trim().isEmpty ? itemCode : itemName;
}

class RezkaSplitRequest {
  const RezkaSplitRequest({
    required this.sourceBarcode,
    required this.sourceStockEntry,
    required this.sourceLineIndex,
    required this.reason,
    required this.driverUrl,
    required this.printer,
    required this.printMode,
    required this.outputs,
  });

  final String sourceBarcode;
  final String sourceStockEntry;
  final int sourceLineIndex;
  final String reason;
  final String driverUrl;
  final String printer;
  final String printMode;
  final List<RezkaSplitOutputRequest> outputs;

  Map<String, dynamic> toJson() {
    return {
      'source_barcode': sourceBarcode.trim(),
      'source_stock_entry': sourceStockEntry.trim(),
      'source_line_index': sourceLineIndex,
      'reason': reason.trim(),
      'driver_url': driverUrl.trim().trimRightSlash(),
      'printer': printer.trim(),
      'print_mode': printMode.trim(),
      'outputs': outputs.map((output) => output.toJson()).toList(),
    };
  }
}

class RezkaSplitOutputRequest {
  const RezkaSplitOutputRequest({
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.uom,
    required this.targetWarehouse,
  });

  final String itemCode;
  final String itemName;
  final double qty;
  final String uom;
  final String targetWarehouse;

  Map<String, dynamic> toJson() {
    return {
      'item_code': itemCode.trim(),
      'item_name': itemName.trim(),
      'qty': qty,
      'uom': uom.trim(),
      'target_warehouse': targetWarehouse.trim(),
    };
  }
}

class RezkaSplitResponse {
  const RezkaSplitResponse({
    required this.ok,
    required this.status,
    required this.stockEntryName,
    required this.sourceBarcode,
    required this.outputs,
  });

  factory RezkaSplitResponse.fromJson(Map<String, dynamic> json) {
    final outputsJson = json['outputs'];
    return RezkaSplitResponse(
      ok: json['ok'] == true,
      status: _rezkaText(json['status']),
      stockEntryName: _rezkaText(json['stock_entry_name']),
      sourceBarcode: _rezkaText(json['source_barcode']),
      outputs: outputsJson is List
          ? outputsJson
              .whereType<Map<String, dynamic>>()
              .map(RezkaOutputLabel.fromJson)
              .toList(growable: false)
          : const <RezkaOutputLabel>[],
    );
  }

  final bool ok;
  final String status;
  final String stockEntryName;
  final String sourceBarcode;
  final List<RezkaOutputLabel> outputs;
}

class RezkaOutputLabel {
  const RezkaOutputLabel({
    required this.epc,
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.uom,
    required this.warehouse,
  });

  factory RezkaOutputLabel.fromJson(Map<String, dynamic> json) {
    return RezkaOutputLabel(
      epc: _rezkaText(json['epc']),
      itemCode: _rezkaText(json['item_code']),
      itemName: _rezkaText(json['item_name']),
      qty: _rezkaNumber(json['qty']),
      uom: _rezkaText(json['uom']),
      warehouse: _rezkaText(json['warehouse']),
    );
  }

  final String epc;
  final String itemCode;
  final String itemName;
  final double qty;
  final String uom;
  final String warehouse;
}

Map<String, dynamic> _rezkaDecodeObject(String body) {
  try {
    return (jsonDecode(body) as Map?)?.cast<String, dynamic>() ?? const {};
  } catch (_) {
    return const {};
  }
}

double _rezkaNumber(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _rezkaText(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
