part of '../mobile_api.dart';

class QolipReworkEntry {
  const QolipReworkEntry({
    required this.id,
    required this.qolipCode,
    required this.setId,
    required this.warehouse,
    required this.itemCode,
    required this.itemName,
    required this.color,
    required this.size,
    required this.sentAt,
    this.returnedAt,
  });

  final String id;
  final String qolipCode;
  final String setId;
  final String warehouse;
  final String itemCode;
  final String itemName;
  final String color;
  final int size;
  final String sentAt;
  final String? returnedAt;
  bool get isOpen => returnedAt == null;

  factory QolipReworkEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final code = json['qolip_code'] as String;
    final sentAt = json['sent_at'] as String;
    final returnedAt = json['returned_at'] as String?;
    if (id.trim().isEmpty ||
        code.trim().isEmpty ||
        DateTime.tryParse(sentAt) == null ||
        (returnedAt != null && DateTime.tryParse(returnedAt) == null)) {
      throw const FormatException('Invalid mold rework record');
    }
    return QolipReworkEntry(
      id: id,
      qolipCode: code,
      setId: json['qolip_set_id']?.toString() ?? '',
      warehouse: json['warehouse']?.toString() ?? '',
      itemCode: json['item_code']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      sentAt: sentAt,
      returnedAt: returnedAt,
    );
  }

  QolipReworkEntry returned(String at) => QolipReworkEntry(
      id: id,
      qolipCode: qolipCode,
      setId: setId,
      warehouse: warehouse,
      itemCode: itemCode,
      itemName: itemName,
      color: color,
      size: size,
      sentAt: sentAt,
      returnedAt: at);
}

class QolipMileageCycle {
  const QolipMileageCycle(
      {required this.id,
      required this.startedAt,
      required this.endedAt,
      required this.meter,
      required this.reworkId});
  final String id;
  final String startedAt;
  final String? endedAt;
  final double meter;
  final String reworkId;

  factory QolipMileageCycle.fromJson(Map<String, dynamic> json) =>
      QolipMileageCycle(
          id: json['id'] as String,
          startedAt: json['started_at'] as String,
          endedAt: json['ended_at'] as String?,
          meter: (json['meter'] as num).toDouble(),
          reworkId: json['rework_id'] as String);
}

class QolipMileage {
  const QolipMileage(
      {required this.qolipCode,
      required this.trackingEnabled,
      required this.currentMeter,
      required this.cycles});
  final String qolipCode;
  final bool trackingEnabled;
  final double? currentMeter;
  final List<QolipMileageCycle> cycles;

  factory QolipMileage.fromJson(Map<String, dynamic> json) => QolipMileage(
      qolipCode: json['qolip_code'] as String,
      trackingEnabled: json['tracking_enabled'] == true,
      currentMeter: (json['current_meter'] as num?)?.toDouble(),
      cycles: (json['cycles'] as List)
          .map((row) =>
              QolipMileageCycle.fromJson((row as Map).cast<String, dynamic>()))
          .toList(growable: false));
}

final _testModeQolipReworks = <String, QolipReworkEntry>{};
final _testModeQolipReworkRequests =
    <String, (String, List<QolipReworkEntry>)>{};
final _testModeQolipMileage = <String, List<QolipMileageCycle>>{};
final _qolipReworkRandom = math.Random.secure();

String newQolipReworkRequestId() =>
    'qolip-rework-${DateTime.now().toUtc().microsecondsSinceEpoch}-'
    '${_qolipReworkRandom.nextInt(1 << 32).toRadixString(16).padLeft(8, '0')}'
    '${_qolipReworkRandom.nextInt(1 << 32).toRadixString(16).padLeft(8, '0')}';

List<QolipReworkEntry> _decodeQolipReworks(Map<String, dynamic> data) =>
    (data['reworks'] as List)
        .map((row) =>
            QolipReworkEntry.fromJson((row as Map).cast<String, dynamic>()))
        .toList(growable: false);

void _requireQolipRequestScope(String scope) {
  if (scope != currentSessionReadScope()) {
    throw const MobileApiException(
        code: 'session_scope_changed',
        message: 'Sessiya o‘zgardi. Sahifani yangilang.');
  }
}

Future<void> _requireTestModeOrderQolipsAvailable(String orderId) async {
  final away = _testModeQolipReworks.values
      .where((entry) => entry.isOpen)
      .map((entry) => entry.qolipCode.trim().toLowerCase())
      .toSet();
  if (away.isEmpty) return;
  final saved = _testModeProductionMaps
      .where((row) => row.map.id == orderId.trim())
      .firstOrNull;
  if (saved == null) return;
  final products = {
    saved.map.productCode.trim().toLowerCase(),
    ...saved.map.products.map((row) => row.itemCode.trim().toLowerCase()),
  }..remove('');
  final molds =
      await MobileApi.instance.qolipProducts(limit: 20000, withQolipOnly: true);
  if (molds.any((mold) =>
      products.contains(mold.code.trim().toLowerCase()) &&
      away.contains(mold.qolipCode.trim().toLowerCase()))) {
    throw const MobileApiException(
        code: 'qolip_in_rework', message: 'Buyurtma qoliplari peredelkada');
  }
}

extension MobileApiQolipReworks on MobileApi {
  Future<List<QolipReworkEntry>> qolipReworks({String status = 'open'}) async {
    final scope = currentSessionReadScope();
    if (!const {'open', 'returned', 'all'}.contains(status)) {
      throw const FormatException('Invalid mold rework status');
    }
    final testMode = await TestModeController.instance.isEnabled();
    _requireQolipRequestScope(scope);
    if (testMode) {
      return _testModeQolipReworks.values
          .where((row) =>
              status == 'all' || (status == 'open' ? row.isOpen : !row.isOpen))
          .toList()
        ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    }
    final response = await _sendAuthorized(() {
      _requireQolipRequestScope(scope);
      return _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/reworks')
            .replace(queryParameters: {'status': status}),
        headers: _headers(requireToken()),
      );
    });
    _requireQolipRequestScope(scope);
    if (response.statusCode != 200) {
      throw _qolipApiException(response,
          fallbackCode: 'qolip_rework_failed',
          fallbackMessage: 'Peredelkadagi qoliplar yuklanmadi');
    }
    final data = await decodeJsonMapPayload(response.body);
    _requireQolipRequestScope(scope);
    return _decodeQolipReworks(data);
  }

  Future<List<QolipReworkEntry>> qolipSendToRework({
    required String requestId,
    required List<String> qolipCodes,
  }) async {
    final scope = currentSessionReadScope();
    final codes = qolipCodes
        .map((code) => code.trim().toLowerCase())
        .toSet()
        .toList()
      ..sort();
    if (requestId.trim().isEmpty ||
        codes.isEmpty ||
        codes.length > 1000 ||
        codes.any((code) => code.isEmpty)) {
      throw const FormatException('Select mold codes');
    }
    final body = {'request_id': requestId, 'qolip_codes': codes};
    List<QolipReworkEntry> result;
    final testMode = await TestModeController.instance.isEnabled();
    _requireQolipRequestScope(scope);
    if (testMode) {
      final key = '${AppSession.instance.profile?.ref}:send:$requestId';
      final signature = jsonEncode(body);
      final old = _testModeQolipReworkRequests[key];
      if (old != null) {
        if (old.$1 != signature) {
          throw const MobileApiException(
              code: 'qolip_rework_request_conflict', message: 'conflict');
        }
        return old.$2;
      }
      final molds = await qolipProducts(limit: 20000, withQolipOnly: true);
      _requireQolipRequestScope(scope);
      final now = DateTime.now().toUtc().toIso8601String();
      result = [];
      for (final code in codes) {
        if (_testModeQolipReworks.values
            .any((row) => row.isOpen && row.qolipCode.toLowerCase() == code)) {
          throw const MobileApiException(
              code: 'qolip_in_rework', message: 'qolip_in_rework');
        }
        final mold = molds
            .where((m) => m.qolipCode.trim().toLowerCase() == code)
            .firstOrNull;
        if (mold == null) {
          throw const MobileApiException(
              code: 'qolip_code_not_found', message: 'qolip_code_not_found');
        }
        if (mold.isInUse ||
            _testModeQolipCheckouts.any((checkout) =>
                checkout.isOpen && checkout.qolipCode.toLowerCase() == code)) {
          throw const MobileApiException(
              code: 'qolip_in_use', message: 'qolip_in_use');
        }
        result.add(QolipReworkEntry(
            id: '$requestId:$code',
            qolipCode: mold.qolipCode,
            setId: mold.setId,
            warehouse: mold.warehouse,
            itemCode: mold.code,
            itemName: mold.name,
            color: mold.qolipColor,
            size: mold.qolipSize,
            sentAt: now));
      }
      for (final row in result) {
        _testModeQolipReworks[row.id] = row;
      }
      _testModeQolipReworkRequests[key] =
          (signature, List.unmodifiable(result));
    } else {
      final response = await _sendAuthorized(() {
        _requireQolipRequestScope(scope);
        return _post(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/reworks/send'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode(body),
        );
      });
      _requireQolipRequestScope(scope);
      if (response.statusCode != 200) {
        throw _qolipApiException(response,
            fallbackCode: 'qolip_rework_failed',
            fallbackMessage: 'Qoliplar peredelkaga berilmadi');
      }
      final data = await decodeJsonMapPayload(response.body);
      _requireQolipRequestScope(scope);
      result = _decodeQolipReworks(data);
      final returned = result.map((row) => row.qolipCode.toLowerCase()).toSet();
      if (result.length != codes.length ||
          returned.length != codes.length ||
          !returned.containsAll(codes) ||
          result.any((row) => !row.isOpen)) {
        throw const FormatException('Incomplete mold rework response');
      }
    }
    _requireQolipRequestScope(scope);
    _qolipProductsSnapshot = null;
    QolipCatalogStore.instance.applyResponse(const {}, scope);
    return result;
  }

  Future<List<QolipReworkEntry>> qolipReturnFromRework({
    required String requestId,
    required List<String> reworkIds,
  }) async {
    final scope = currentSessionReadScope();
    final ids = reworkIds.map((id) => id.trim()).toSet().toList()..sort();
    if (requestId.trim().isEmpty ||
        ids.isEmpty ||
        ids.length > 1000 ||
        ids.any((id) => id.isEmpty)) {
      throw const FormatException('Select rework records');
    }
    final body = {'request_id': requestId, 'rework_ids': ids};
    List<QolipReworkEntry> result;
    final testMode = await TestModeController.instance.isEnabled();
    _requireQolipRequestScope(scope);
    if (testMode) {
      final key = '${AppSession.instance.profile?.ref}:return:$requestId';
      final signature = jsonEncode(body);
      final old = _testModeQolipReworkRequests[key];
      if (old != null) {
        if (old.$1 != signature) {
          throw const MobileApiException(
              code: 'qolip_rework_request_conflict', message: 'conflict');
        }
        return old.$2;
      }
      final rows = ids.map((id) => _testModeQolipReworks[id]).toList();
      if (rows.any((row) => row == null || !row.isOpen)) {
        throw const MobileApiException(
            code: 'qolip_rework_conflict', message: 'conflict');
      }
      final now = DateTime.now().toUtc().toIso8601String();
      result = [];
      for (final row in rows.cast<QolipReworkEntry>()) {
        final saved = row.returned(now);
        _testModeQolipReworks[row.id] = saved;
        result.add(saved);
        final cycles = _testModeQolipMileage.putIfAbsent(
            row.qolipCode.toLowerCase(), () => []);
        if (cycles.isNotEmpty) {
          final previous = cycles.removeLast();
          cycles.add(QolipMileageCycle(
              id: previous.id,
              startedAt: previous.startedAt,
              endedAt: now,
              meter: previous.meter,
              reworkId: previous.reworkId));
        }
        cycles.add(QolipMileageCycle(
            id: 'cycle:${row.id}',
            startedAt: now,
            endedAt: null,
            meter: 0,
            reworkId: row.id));
      }
      _testModeQolipReworkRequests[key] =
          (signature, List.unmodifiable(result));
    } else {
      final response = await _sendAuthorized(() {
        _requireQolipRequestScope(scope);
        return _post(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/reworks/return'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode(body),
        );
      });
      _requireQolipRequestScope(scope);
      if (response.statusCode != 200) {
        throw _qolipApiException(response,
            fallbackCode: 'qolip_rework_failed',
            fallbackMessage: 'Qoliplar qaytarilmadi');
      }
      final data = await decodeJsonMapPayload(response.body);
      _requireQolipRequestScope(scope);
      result = _decodeQolipReworks(data);
      final returned = result.map((row) => row.id).toSet();
      if (result.length != ids.length ||
          returned.length != ids.length ||
          !returned.containsAll(ids) ||
          result.any((row) => row.isOpen)) {
        throw const FormatException('Incomplete mold return response');
      }
    }
    _requireQolipRequestScope(scope);
    _qolipProductsSnapshot = null;
    QolipCatalogStore.instance.applyResponse(const {}, scope);
    return result;
  }

  Future<QolipMileage> qolipMileage(String qolipCode) async {
    final scope = currentSessionReadScope();
    final code = qolipCode.trim();
    final testMode = await TestModeController.instance.isEnabled();
    _requireQolipRequestScope(scope);
    if (testMode) {
      final cycles = _testModeQolipMileage[code.toLowerCase()] ??
          const <QolipMileageCycle>[];
      return QolipMileage(
          qolipCode: code,
          trackingEnabled: cycles.isNotEmpty,
          currentMeter: cycles.isEmpty ? null : cycles.last.meter,
          cycles: List.unmodifiable(cycles));
    }
    final response = await _sendAuthorized(() {
      _requireQolipRequestScope(scope);
      return _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/mileage')
            .replace(queryParameters: {'qolip_code': code}),
        headers: _headers(requireToken()),
      );
    });
    _requireQolipRequestScope(scope);
    if (response.statusCode != 200) {
      throw _qolipApiException(response,
          fallbackCode: 'qolip_mileage_failed',
          fallbackMessage: 'Probeg yuklanmadi');
    }
    final data = await decodeJsonMapPayload(response.body);
    _requireQolipRequestScope(scope);
    final result =
        QolipMileage.fromJson((data['mileage'] as Map).cast<String, dynamic>());
    if (result.qolipCode.toLowerCase() != code.toLowerCase()) {
      throw const FormatException('Mold mileage identity changed');
    }
    return result;
  }
}
