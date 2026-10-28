part of '../mobile_api.dart';

class QolipStoragePage<T> {
  const QolipStoragePage(this.items, this.nextOffset);
  final List<T> items;
  final int? nextOffset;
}

class QolipPaddon {
  QolipPaddon.fromJson(Map<String, dynamic> json)
      : code = json['code'] as String,
        warehouse = json['warehouse'] as String,
        location = json['location'] as String? ?? '',
        note = json['note'] as String? ?? '',
        archiveEntryId = json['archive_entry_id'] as String?,
        locked = json['locked'] as bool,
        archived = json['archived'] as bool,
        revision = (json['revision'] as num).toInt(),
        totalQuantity = (json['total_quantity'] as num?)?.toInt() ??
            (json['item_count'] as num).toInt(),
        itemCount = (json['item_count'] as num).toInt() {
    if (code.isEmpty || warehouse.isEmpty || revision < 0 || itemCount < 0) {
      throw const FormatException('Invalid mold pallet');
    }
  }
  final String code, warehouse, location, note;
  final String? archiveEntryId;
  final bool locked, archived;
  final int revision, itemCount, totalQuantity;
  bool get editable => !locked && !archived;
}

class QolipStorageMold {
  QolipStorageMold.fromJson(Map<String, dynamic> json)
      : code = json['qolip_code'] as String,
        setId = json['qolip_set_id'] as String? ?? '',
        warehouse = json['warehouse'] as String? ?? '',
        name = json['item_name'] as String? ?? '',
        color = json['color'] as String? ?? '',
        size = (json['size'] as num?)?.toInt() ?? 0,
        quantity = (json['quantity'] as num?)?.toInt() ?? 0,
        paddonCode = json['paddon_code'] as String? ?? '',
        archived = json['archived'] == true,
        inUse = json['is_in_use'] == true,
        inRework = json['is_in_rework'] == true,
        transferring = json['is_transferring'] == true,
        custodyMismatch = json['is_custody_mismatch'] == true,
        products = List<Map<String, dynamic>>.unmodifiable(
            (json['products'] as List? ?? const [])
                .map((e) => Map<String, dynamic>.from(e as Map))) {
    if (code.trim().isEmpty) throw const FormatException('Invalid mold');
  }
  final String code, setId, warehouse, name, color, paddonCode;
  final int size, quantity;
  final bool archived, inUse, inRework, transferring, custodyMismatch;
  final List<Map<String, dynamic>> products;
  bool get available =>
      !archived && !inUse && !inRework && !transferring && paddonCode.isEmpty;
  String get productNames =>
      products.isEmpty ? name : products.map((e) => e['name']).join(', ');
}

class QolipPaddonDetail {
  QolipPaddonDetail.fromJson(Map<String, dynamic> json)
      : paddon = QolipPaddon.fromJson(
            Map<String, dynamic>.from(json['paddon'] as Map)),
        items = List<QolipStorageMold>.unmodifiable((json['items'] as List).map(
            (e) => QolipStorageMold.fromJson(
                Map<String, dynamic>.from(e as Map)))),
        history = List<Map<String, dynamic>>.unmodifiable(
            (json['history'] as List? ?? const [])
                .map((e) => Map<String, dynamic>.from(e as Map))),
        inspection = json['inspection'] is Map
            ? Map<String, dynamic>.from(json['inspection'] as Map)
            : null;
  final QolipPaddon paddon;
  final List<QolipStorageMold> items;
  final List<Map<String, dynamic>> history;
  final Map<String, dynamic>? inspection;
}

class QolipArchiveEntry {
  QolipArchiveEntry.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        kind = json['kind'] as String,
        code = json['code'] as String,
        warehouse = json['warehouse'] as String,
        archivedAt = json['archived_at'] as String,
        restoredAt = json['restored_at'] as String?,
        archivedBy = json['archived_by_name'] as String? ?? '',
        restoredBy = json['restored_by_name'] as String? ?? '',
        note = json['note'] as String? ?? '',
        snapshot = Map<String, dynamic>.from(json['snapshot'] as Map) {
    if (id.isEmpty || !const ['qolip', 'paddon'].contains(kind)) {
      throw const FormatException('Invalid archive entry');
    }
  }
  final String id,
      kind,
      code,
      warehouse,
      archivedAt,
      archivedBy,
      restoredBy,
      note;
  final String? restoredAt;
  final Map<String, dynamic> snapshot;
  bool get isOpen => restoredAt == null;
}

/// Retains a key for an unchanged intent after a network error. A changed
/// selection, revision or action always starts a different operation.
class QolipStorageIntent {
  String? _signature, _id;
  String keyFor(Map<String, dynamic> intent) {
    final signature = jsonEncode(intent);
    if (_signature != signature) {
      _signature = signature;
      _id = newQolipReworkRequestId();
    }
    return _id!;
  }

  void complete() {
    _signature = null;
    _id = null;
  }
}

extension MobileApiQolipStorage on MobileApi {
  Future<Map<String, dynamic>> _qolipStorageRequest(String path,
      {Map<String, String> query = const {},
      Map<String, dynamic>? body}) async {
    final scope = currentSessionReadScope();
    final uri = Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/$path')
        .replace(queryParameters: query.isEmpty ? null : query);
    void requireScope() {
      if (scope != currentSessionReadScope()) {
        throw const MobileApiException(
            code: 'session_scope_changed', message: 'Session changed');
      }
    }

    final response = await _sendAuthorized(() {
      requireScope();
      return body == null
          ? _get(uri, headers: _headers(requireToken()))
          : _post(uri,
              headers: _headers(requireToken()), body: jsonEncode(body));
    });
    requireScope();
    final json = await decodeJsonMapPayload(response.body);
    if (response.statusCode != 200 || json['ok'] != true) {
      throw MobileApiException(
          code: (json['error'] ?? json['code'] ?? 'qolip_storage_failed')
              .toString(),
          message: (json['message'] ?? json['error'] ?? 'Qolip storage failed')
              .toString(),
          statusCode: response.statusCode);
    }
    if (body != null && !path.endsWith('/qr/print')) {
      QolipCatalogStore.instance.applyResponse(json, scope);
    }
    return json;
  }

  Future<QolipStoragePage<QolipPaddon>> qolipPaddons(
      {bool archived = false, String query = '', int offset = 0}) async {
    final json = await _qolipStorageRequest('paddons', query: {
      'archived': '$archived',
      'q': query,
      'limit': '100',
      'offset': '$offset'
    });
    return QolipStoragePage(
        (json['paddons'] as List)
            .map((e) =>
                QolipPaddon.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        json['has_more'] == true ? (json['next_offset'] as num).toInt() : null);
  }

  Future<QolipPaddonDetail> qolipPaddonDetail(String code) async =>
      QolipPaddonDetail.fromJson(
          await _qolipStorageRequest('paddons/detail', query: {'code': code}));
  Future<QolipStoragePage<QolipStorageMold>> qolipStorageMolds(
      {String query = '', int offset = 0}) async {
    final json = await _qolipStorageRequest('paddons/molds',
        query: {'q': query, 'limit': '100', 'offset': '$offset'});
    return QolipStoragePage(
        (json['molds'] as List)
            .map((e) =>
                QolipStorageMold.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        json['has_more'] == true ? (json['next_offset'] as num).toInt() : null);
  }

  Future<QolipPaddonDetail> qolipPaddonAction(
          Map<String, dynamic> body) async =>
      QolipPaddonDetail.fromJson(
          await _qolipStorageRequest('paddons/action', body: body));
  Future<QolipStoragePage<QolipArchiveEntry>> qolipArchive(
      {String status = 'open', String query = '', int offset = 0}) async {
    final json = await _qolipStorageRequest('archive', query: {
      'status': status,
      'q': query,
      'limit': '100',
      'offset': '$offset'
    });
    return QolipStoragePage(
        (json['entries'] as List)
            .map((e) =>
                QolipArchiveEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        json['has_more'] == true ? (json['next_offset'] as num).toInt() : null);
  }

  Future<List<QolipArchiveEntry>> qolipArchiveAction(
      Map<String, dynamic> body) async {
    final json = await _qolipStorageRequest('archive/action', body: body);
    return (json['entries'] as List)
        .map((e) =>
            QolipArchiveEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

/// Typed pallet QR payloads never reinterpret an opaque mold code as a pallet.
String? qolipPaddonCodeFromQr(String raw) {
  final value = raw.trim();
  const prefix = 'qolip-paddon:';
  if (!value.startsWith(prefix)) return null;
  final code = value.substring(prefix.length);
  return RegExp(r'^QP-[0-9]{5,}$').hasMatch(code) ? code : null;
}
