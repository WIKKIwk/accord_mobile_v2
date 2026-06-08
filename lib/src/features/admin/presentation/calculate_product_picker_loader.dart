import '../../shared/models/app_models.dart';

typedef CalculateAllProductPageLoader = Future<List<SupplierItem>> Function({
  String query,
  String group,
  int limit,
  int offset,
});

typedef CalculateCustomerProductPageLoader = Future<List<SupplierItem>>
    Function({
  required String customerRef,
  String query,
  int limit,
  int offset,
});

Future<List<SupplierItem>> loadCalculateProductPickerPage({
  required String customerRef,
  required String query,
  required int offset,
  required int limit,
  required CalculateCustomerProductPageLoader customerItems,
  required CalculateAllProductPageLoader allItems,
}) {
  final ref = customerRef.trim();
  if (ref.isNotEmpty) {
    return customerItems(
      customerRef: ref,
      query: query,
      offset: offset,
      limit: limit,
    );
  }
  return allItems(
    query: query,
    offset: offset,
    limit: limit,
  );
}
