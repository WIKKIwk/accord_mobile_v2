part of '../mobile_api.dart';

final List<Map<String, dynamic>> _testModeBosmaAstatkaReports = [];

List<Map<String, dynamic>> mobileApiTestModeBosmaAstatkaReports() => [
      for (final report in _testModeBosmaAstatkaReports)
        Map<String, dynamic>.unmodifiable(report),
    ];

extension MobileApiAdminBosmaAstatka on MobileApi {
  Future<Map<String, dynamic>> adminBosmaAstatkaReport({
    required String apparatus,
    required String orderId,
    required double? totalWaste,
    required double? finishedGoodsMeter,
    required double? finishedGoodsKg,
    required double? bobinaKg,
    required List<ReturnedPaintItemInput> returnedPaintItems,
    String returnedPaintImageId = '',
    String description = '',
  }) async {
    apparatus = apparatus.trim();
    orderId = orderId.trim();
    if (!isCanonicalApparatusId(apparatus) ||
        orderId.isEmpty ||
        totalWaste == null ||
        !totalWaste.isFinite ||
        totalWaste < 0 ||
        [finishedGoodsMeter, finishedGoodsKg, bobinaKg]
            .any((value) => value == null || !value.isFinite || value <= 0) ||
        (returnedPaintItems.isEmpty && returnedPaintImageId.trim().isEmpty)) {
      throw const MobileApiException(
          code: 'progress_input_invalid',
          message: 'Astatka hisobotini to‘liq va to‘g‘ri kiriting');
    }
    final body = <String, dynamic>{
      'apparatus': apparatus,
      'order_id': orderId,
      'total_waste': totalWaste,
      'finished_goods_meter': finishedGoodsMeter,
      'finished_goods_kg': finishedGoodsKg,
      'bobina_kg': bobinaKg,
      'returned_paint_items': [
        for (final item in returnedPaintItems) item.toJson()
      ],
      'returned_paint_image_id': returnedPaintImageId.trim(),
      'description': description.trim(),
    };
    if (await TestModeController.instance.isEnabled()) {
      final queueState = _testModeApparatusQueueStates[apparatus]?[orderId];
      if (_testModeRequiredApparatus(apparatus).operation.trim() != 'print' ||
          !const {'in_progress', 'paused', 'completed'}.contains(queueState) ||
          _testModeOrderControls[orderId] == AdminOrderControlState.frozen) {
        throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Bu order uchun hisobot topshirib bo‘lmaydi');
      }
      final previous = _testModeBosmaAstatkaReports
          .where((report) =>
              report['order_id'] == orderId && report['apparatus'] == apparatus)
          .lastOrNull;
      final now = _testModeUnixSeconds();
      final report = <String, dynamic>{
        ...body,
        'report_id':
            'test-bosma-astatka-${DateTime.now().microsecondsSinceEpoch}',
        'from_at_unix':
            previous?['to_at_unix'] ?? _testModeOrderStartedAtUnix[orderId],
        'to_at_unix': now,
      };
      _testModeBosmaAstatkaReports.add(report);
      return report;
    }
    final response = await _sendAuthorized(() => _post(
          Uri.parse(
              '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/bosma-astatka'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode(body),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
          response, 'bosma_astatka_report_failed');
    }
    final payload = await decodeJsonMapPayload(response.body);
    final report = payload['report'];
    if (report is! Map || (report['report_id'] as String? ?? '').isEmpty) {
      throw const MobileApiException(
          code: 'bosma_astatka_invalid_response',
          message: 'Astatka qaydi javobi noto‘g‘ri');
    }
    return report.cast<String, dynamic>();
  }
}
