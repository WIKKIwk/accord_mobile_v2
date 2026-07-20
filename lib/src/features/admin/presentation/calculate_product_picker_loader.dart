import '../../../core/search/search_normalizer.dart';
import '../../shared/models/app_models.dart';

typedef CalculateAllProductPageLoader = Future<List<SupplierItem>> Function({
  String query,
  String group,
  int limit,
  int offset,
});

typedef CalculateCustomerDetailLoader = Future<AdminCustomerDetail> Function(
    String customerRef);

typedef CalculateCustomersForItemLoader = Future<List<CustomerDirectoryEntry>>
    Function({
  required String itemCode,
  String itemName,
  String query,
  int limit,
  int offset,
});

const String kCalculateFinishedProductGroup = 'Tayyor mahsulot';

class CalculateProductPickerOption {
  const CalculateProductPickerOption({
    required this.item,
    required this.customerName,
  });

  final SupplierItem item;
  final String customerName;
}

Future<List<SupplierItem>> loadCalculateProductPickerPage({
  required String customerRef,
  required String query,
  required int offset,
  required int limit,
  required CalculateCustomerDetailLoader customerDetail,
  required CalculateAllProductPageLoader allItems,
}) async {
  final ref = customerRef.trim();
  if (ref.isNotEmpty) {
    final detail = await customerDetail(ref);
    final normalizedQuery = query.trim().toLowerCase();
    final filtered = detail.assignedItems
        .where(
          (item) =>
              _isCalculateFinishedProduct(item) &&
              (normalizedQuery.isEmpty ||
                  searchMatches(normalizedQuery, [
                    item.name,
                    item.code,
                    item.uom,
                    item.warehouse,
                  ])),
        )
        .toList(growable: false);
    if (offset >= filtered.length) {
      return const <SupplierItem>[];
    }
    final end = limit <= 0 || offset + limit > filtered.length
        ? filtered.length
        : offset + limit;
    return filtered.sublist(offset, end);
  }
  final items = await allItems(
    query: query,
    group: kCalculateFinishedProductGroup,
    offset: offset,
    limit: limit,
  );
  return items.where(_isCalculateFinishedProduct).toList(growable: false);
}

bool _isCalculateFinishedProduct(SupplierItem item) =>
    item.itemGroup.trim().toLowerCase() ==
    kCalculateFinishedProductGroup.toLowerCase();

Future<List<CalculateProductPickerOption>>
    loadCalculateProductPickerOptionsPage({
  required String customerRef,
  required String customerName,
  required String query,
  required int offset,
  required int limit,
  required CalculateCustomerDetailLoader customerDetail,
  required CalculateAllProductPageLoader allItems,
  required CalculateCustomersForItemLoader customersForItem,
}) async {
  final items = await loadCalculateProductPickerPage(
    customerRef: customerRef,
    query: query,
    offset: offset,
    limit: limit,
    customerDetail: customerDetail,
    allItems: allItems,
  );
  if (items.isEmpty) {
    return const <CalculateProductPickerOption>[];
  }

  final selectedCustomerName = customerName.trim();
  if (selectedCustomerName.isNotEmpty) {
    return items
        .map(
          (item) => CalculateProductPickerOption(
            item: item,
            customerName: selectedCustomerName,
          ),
        )
        .toList(growable: false);
  }

  return Future.wait(
    items.map((item) async {
      final customers = await customersForItem(
        itemCode: item.code,
        itemName: item.name,
        limit: 200,
        offset: 0,
      );
      final customerNames = customers
          .map((customer) => customer.name.trim().isEmpty
              ? customer.ref.trim()
              : customer.name.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList(growable: false);
      return CalculateProductPickerOption(
        item: item,
        customerName: customerNames.isEmpty
            ? 'Mijoz biriktirilmagan'
            : customerNames.join(', '),
      );
    }),
  );
}
