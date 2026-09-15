part of '../mobile_api.dart';

class PendingOrder {
  const PendingOrder(
      {required this.id,
      required this.template,
      this.managerName = '',
      this.completed = false});
  final String id;
  final CalculateOrderTemplate template;
  final String managerName;
  final bool completed;
  factory PendingOrder.fromJson(Map<String, dynamic> json) => PendingOrder(
        id: json['id'] as String,
        template: CalculateOrderTemplate.fromJson(
            (json['template'] as Map).cast<String, dynamic>()),
        managerName: json['manager_name'] as String? ?? '',
        completed: json['completion'] != null,
      );
  bool matches(String query) {
    final key = query.trim().toLowerCase();
    return key.isEmpty ||
        [template.orderNumber, template.customer, template.product, managerName]
            .any((v) => v.toLowerCase().contains(key));
  }
}

extension MobileApiPendingOrders on MobileApi {
  Future<List<PendingOrder>> pendingOrders() async {
    if (await TestModeController.instance.isEnabled()) {
      return const [];
    }
    final response = await _sendAuthorized(() => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/pending-orders'),
        headers: _headers(requireToken())));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'pending_orders');
    }
    return (jsonDecode(response.body) as List)
        .map((v) => PendingOrder.fromJson((v as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Uint8List> pendingOrderImage(String id) async {
    final response = await _sendAuthorized(() => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/pending-orders/image')
            .replace(queryParameters: {'id': id}),
        headers: _headers(requireToken())));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'pending_order_image');
    }
    return response.bodyBytes;
  }
}
