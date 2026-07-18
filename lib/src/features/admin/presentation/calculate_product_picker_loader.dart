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

const String kCalculateFinishedProductGroup = 'Tayyor mahsulot';

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
