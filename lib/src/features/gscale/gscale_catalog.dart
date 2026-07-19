import '../../core/api/mobile_api.dart';
import '../../core/session/session.dart';
import '../shared/models/app_models.dart';

class GScaleCatalogWarehouse {
  const GScaleCatalogWarehouse({
    required this.warehouse,
    this.actualQty,
    this.company,
  });

  final String warehouse;
  final double? actualQty;
  final String? company;
}

enum GScaleCatalogItemSource { adminItems, gscaleItems }

const gscaleDefaultCreateItemGroup = 'All Item Groups';

GScaleCatalogItemSource gscaleCatalogItemSourceForProfile(
  SessionProfile? profile,
) {
  if (profile?.hasCapability('catalog.item.read') == true) {
    return GScaleCatalogItemSource.adminItems;
  }
  return GScaleCatalogItemSource.gscaleItems;
}

List<String> gscaleCreateItemGroupsForProfile(SessionProfile? profile) {
  if (profile?.role != UserRole.materialTaminotchi) {
    return const [gscaleDefaultCreateItemGroup];
  }
  final groups = profile?.assignedItemGroups ?? const <String>[];
  final normalized = groups
      .map((group) => group.trim())
      .where((group) => group.isNotEmpty)
      .toSet()
      .toList(growable: false)
    ..sort();
  return normalized;
}

bool gscaleUsesScopedAdminWarehousesForProfile(
  SessionProfile? profile, {
  UserRole? role,
}) {
  if (role == UserRole.admin ||
      role == UserRole.werka ||
      role == UserRole.materialTaminotchi) {
    return true;
  }
  if (role != null) {
    return false;
  }
  return profile?.hasCapability('admin.access') == true ||
      profile?.hasCapability('production.map.manage') == true ||
      profile?.hasCapability('catalog.item.read') == true ||
      (profile?.role == UserRole.werka &&
          profile?.hasCapability('gscale.catalog.read') == true) ||
      (profile?.role == UserRole.materialTaminotchi &&
          profile?.hasCapability('raw_material.assign') == true);
}

bool gscaleMergesDefaultWarehousesForProfile(
  SessionProfile? profile, {
  UserRole? role,
}) {
  if (role != null) {
    return role == UserRole.werka || role == UserRole.materialTaminotchi;
  }
  return profile?.role == UserRole.werka ||
      profile?.role == UserRole.materialTaminotchi;
}

bool _gscaleIsWerkaProfile(
  SessionProfile? profile, {
  UserRole? role,
}) {
  if (role != null) {
    return role == UserRole.werka;
  }
  return profile?.role == UserRole.werka;
}

List<GScaleCatalogWarehouse> gscaleAssignedWarehousesForProfile(
  SessionProfile? profile, {
  String query = '',
}) {
  return _uniqueWarehouses(
    profile?.assignedWarehouses ?? const <String>[],
    query: query,
  );
}

List<GScaleCatalogWarehouse> gscaleScopeWarehousesForProfile(
  Iterable<GScaleCatalogWarehouse> warehouses,
  SessionProfile? profile, {
  UserRole? role,
}) {
  final values = warehouses.toList(growable: false);
  if (!_gscaleIsWerkaProfile(profile, role: role)) {
    return values;
  }
  final allowed = (profile?.assignedWarehouses ?? const <String>[])
      .map((warehouse) => warehouse.trim().toLowerCase())
      .where((warehouse) => warehouse.isNotEmpty)
      .toSet();
  if (allowed.isEmpty) {
    return const [];
  }
  return values
      .where(
        (warehouse) =>
            allowed.contains(warehouse.warehouse.trim().toLowerCase()),
      )
      .toList(growable: false);
}

Future<List<GScaleCatalogWarehouse>> fetchGScaleItemWarehouses({
  required String itemCode,
  String query = '',
  int limit = 12,
  MobileApi? api,
  UserRole? role,
}) async {
  final client = api ?? MobileApi.instance;
  final profile = AppSession.instance.profile;
  final canReadAdminCatalog = role == UserRole.admin ||
      (role == null && profile?.hasCapability('catalog.item.read') == true);
  final canReadGScaleCatalog = role == UserRole.werka ||
      (role == null && profile?.hasCapability('gscale.catalog.read') == true);
  if (canReadAdminCatalog) {
    final items = await client.adminItemsPage(query: itemCode, limit: 50);
    final exactItems = items.where((item) {
      return item.code.trim().toLowerCase() == itemCode.trim().toLowerCase();
    }).toList(growable: false);
    if (exactItems.isEmpty) {
      return const [];
    }
    final warehouses = gscaleWarehousesFromSupplierItems(
      exactItems,
      itemCode: itemCode,
      query: query,
    );
    final defaults = await fetchGScaleDefaultWarehouses(
      query: query,
      limit: limit,
      api: client,
      role: role,
    );
    return gscaleScopeWarehousesForProfile(
      mergeGScaleCatalogWarehouses(warehouses, defaults),
      profile,
      role: role,
    ).take(limit).toList();
  }
  if (canReadGScaleCatalog) {
    final items = await client.gscaleItemsPage(query: itemCode, limit: 50);
    final warehouses = gscaleWarehousesFromSupplierItems(
      items,
      itemCode: itemCode,
      query: query,
    );
    if (warehouses.isNotEmpty &&
        !gscaleMergesDefaultWarehousesForProfile(profile, role: role)) {
      return warehouses.take(limit).toList();
    }
    final defaults = await fetchGScaleDefaultWarehouses(
      query: query,
      limit: limit,
      api: client,
      role: role,
    );
    return gscaleScopeWarehousesForProfile(
      mergeGScaleCatalogWarehouses(warehouses, defaults),
      profile,
      role: role,
    ).take(limit).toList();
  }
  throw Exception('GScale omborlari faqat admin yoki werka uchun mavjud');
}

List<GScaleCatalogWarehouse> mergeGScaleCatalogWarehouses(
  Iterable<GScaleCatalogWarehouse> first,
  Iterable<GScaleCatalogWarehouse> second,
) {
  final seen = <String>{};
  final out = <GScaleCatalogWarehouse>[];
  for (final warehouse in [...first, ...second]) {
    final name = warehouse.warehouse.trim();
    if (name.isEmpty || !seen.add(name.toLowerCase())) {
      continue;
    }
    out.add(warehouse);
  }
  return out;
}

Future<List<GScaleCatalogWarehouse>> fetchGScaleDefaultWarehouses({
  String query = '',
  int limit = 30,
  MobileApi? api,
  UserRole? role,
}) async {
  final client = api ?? MobileApi.instance;
  final profile = AppSession.instance.profile;
  final canReadAdminWarehouses = gscaleUsesScopedAdminWarehousesForProfile(
    profile,
    role: role,
  );
  final canReadGScaleCatalog = role == UserRole.werka ||
      (role == null && profile?.hasCapability('gscale.catalog.read') == true);
  if (canReadAdminWarehouses) {
    try {
      final warehouses = await client.adminWarehouses(
        query: query,
        limit: limit,
      );
      final mapped = warehouses
          .map(
            (warehouse) => GScaleCatalogWarehouse(
              warehouse: warehouse.warehouse,
              company:
                  warehouse.company.trim().isEmpty ? null : warehouse.company,
            ),
          )
          .where((warehouse) => warehouse.warehouse.trim().isNotEmpty);
      return gscaleScopeWarehousesForProfile(
        mapped,
        profile,
        role: role,
      ).take(limit).toList(growable: false);
    } catch (_) {
      if (!_gscaleIsWerkaProfile(profile, role: role)) {
        rethrow;
      }
      final fallback = gscaleAssignedWarehousesForProfile(
        profile,
        query: query,
      ).take(limit).toList(growable: false);
      if (fallback.isEmpty) {
        rethrow;
      }
      return fallback;
    }
  }
  if (canReadGScaleCatalog) {
    final items = await client.gscaleItemsPage(limit: 200);
    return gscaleWarehousesFromSupplierItems(
      items,
      query: query,
    ).take(limit).toList();
  }
  throw Exception('GScale omborlari faqat admin yoki werka uchun mavjud');
}

List<GScaleCatalogWarehouse> gscaleWarehousesFromSupplierItems(
  Iterable<SupplierItem> items, {
  String itemCode = '',
  String query = '',
}) {
  return _uniqueWarehouses(
    items.where((item) {
      if (itemCode.trim().isEmpty) {
        return true;
      }
      return item.code.trim().toLowerCase() == itemCode.trim().toLowerCase();
    }).map((item) => item.warehouse),
    query: query,
  );
}

List<GScaleCatalogWarehouse> gscaleWarehousesFromCustomerOptions(
  Iterable<CustomerItemOption> options, {
  String itemCode = '',
  String query = '',
}) {
  return _uniqueWarehouses(
    options.where((option) {
      if (itemCode.trim().isEmpty) {
        return true;
      }
      return option.itemCode.trim().toLowerCase() ==
          itemCode.trim().toLowerCase();
    }).map((option) => option.warehouse),
    query: query,
  );
}

List<GScaleCatalogWarehouse> gscaleWarehousesFromDefault(
  String warehouse, {
  String query = '',
}) {
  return _uniqueWarehouses([warehouse], query: query);
}

List<GScaleCatalogWarehouse> _uniqueWarehouses(
  Iterable<String> warehouses, {
  required String query,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final seen = <String>{};
  final out = <GScaleCatalogWarehouse>[];
  for (final raw in warehouses) {
    final warehouse = raw.trim();
    if (warehouse.isEmpty ||
        !warehouse.toLowerCase().contains(normalizedQuery) ||
        !seen.add(warehouse.toLowerCase())) {
      continue;
    }
    out.add(GScaleCatalogWarehouse(warehouse: warehouse));
  }
  return out;
}
