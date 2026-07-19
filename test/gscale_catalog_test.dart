import 'package:accord_mobile_v2/src/features/gscale/gscale_catalog.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    AppSession.instance.profile = null;
    AppSession.instance.token = null;
  });

  tearDown(() {
    AppSession.instance.profile = null;
    AppSession.instance.token = null;
  });

  test('customer options expose exact item warehouses only', () {
    final warehouses = gscaleWarehousesFromCustomerOptions(
      [
        _option(itemCode: 'ITEM-001', warehouse: 'Stores - A'),
        _option(itemCode: 'ITEM-001', warehouse: 'Stores - A'),
        _option(itemCode: 'ITEM-001', warehouse: 'Stores - B'),
        _option(itemCode: 'ITEM-002', warehouse: 'Stores - C'),
      ],
      itemCode: 'ITEM-001',
      query: 'b',
    );

    expect(warehouses, hasLength(1));
    expect(warehouses.single.warehouse, 'Stores - B');
  });

  test('admin supplier items map default warehouse for selected item', () {
    final warehouses = gscaleWarehousesFromSupplierItems(const [
      SupplierItem(
        code: 'ITEM-001',
        name: 'Rice',
        uom: 'kg',
        warehouse: 'Stores - CH',
      ),
      SupplierItem(
        code: 'ITEM-002',
        name: 'Sugar',
        uom: 'kg',
        warehouse: 'Stores - B',
      ),
    ], itemCode: 'ITEM-001');

    expect(warehouses, hasLength(1));
    expect(warehouses.single.warehouse, 'Stores - CH');
  });

  test('admin catalog item read wins over gscale catalog read', () {
    const profile = SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['catalog.item.read', 'gscale.catalog.read'],
    );

    expect(
      gscaleCatalogItemSourceForProfile(profile),
      GScaleCatalogItemSource.adminItems,
    );
  });

  test('admin item warehouses include mini erp warehouses', () {
    final warehouses = mergeGScaleCatalogWarehouses(
      const [
        GScaleCatalogWarehouse(warehouse: 'Stores - CH'),
      ],
      const [
        GScaleCatalogWarehouse(warehouse: 'Kalidor'),
        GScaleCatalogWarehouse(warehouse: 'Ombor'),
      ],
    );

    expect(
      warehouses.map((warehouse) => warehouse.warehouse),
      ['Stores - CH', 'Kalidor', 'Ombor'],
    );
  });

  test('material taminotchi create item groups use assigned scope', () {
    const profile = SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Materialchi',
      legalName: '',
      ref: 'MAT-001',
      phone: '',
      avatarUrl: '',
      assignedItemGroups: ['Kraska', 'Kley', 'Kraska', ' '],
    );

    expect(gscaleCreateItemGroupsForProfile(profile), ['Kley', 'Kraska']);
  });

  test('material receipt uses scoped admin warehouses', () {
    const profile = SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Materialchi',
      legalName: '',
      ref: 'MAT-001',
      phone: '',
      avatarUrl: '',
      capabilities: ['gscale.catalog.read', 'raw_material.assign'],
      assignedWarehouses: ['Sklad U'],
    );

    expect(gscaleUsesScopedAdminWarehousesForProfile(profile), isTrue);
    expect(gscaleMergesDefaultWarehousesForProfile(profile), isTrue);
  });

  test('werka receipt uses its assigned admin warehouse scope', () {
    const profile = SessionProfile(
      role: UserRole.werka,
      displayName: 'Werka',
      legalName: '',
      ref: 'WERKA-001',
      phone: '',
      avatarUrl: '',
      capabilities: ['gscale.catalog.read'],
      assignedWarehouses: ['Kalidor'],
    );

    expect(gscaleUsesScopedAdminWarehousesForProfile(profile), isTrue);
    expect(gscaleMergesDefaultWarehousesForProfile(profile), isTrue);
  });

  test('werka warehouse catalog keeps only profile assignments', () {
    const profile = SessionProfile(
      role: UserRole.werka,
      displayName: 'Werka',
      legalName: '',
      ref: 'WERKA-001',
      phone: '',
      avatarUrl: '',
      capabilities: ['gscale.catalog.read'],
      assignedWarehouses: ['Kalidor', 'Tayyor mahsulot'],
    );

    final warehouses = gscaleScopeWarehousesForProfile(
      const [
        GScaleCatalogWarehouse(warehouse: 'Kalidor'),
        GScaleCatalogWarehouse(warehouse: 'Boshqa ombor'),
        GScaleCatalogWarehouse(warehouse: 'Tayyor mahsulot'),
      ],
      profile,
    );

    expect(
      warehouses.map((warehouse) => warehouse.warehouse),
      ['Kalidor', 'Tayyor mahsulot'],
    );
  });

  test('werka item picker ignores the legacy item warehouse', () async {
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.werka,
      displayName: 'Werka',
      legalName: '',
      ref: 'WERKA-001',
      phone: '',
      avatarUrl: '',
      capabilities: ['gscale.catalog.read'],
      assignedWarehouses: ['Xomashyo ombori - DEMO'],
    );

    final warehouses = await fetchGScaleItemWarehouses(
      itemCode: 'DEMO-HOTLUNCH',
    );

    expect(
      warehouses.map((warehouse) => warehouse.warehouse),
      ['Xomashyo ombori - DEMO'],
    );
    expect(
      warehouses.map((warehouse) => warehouse.warehouse),
      isNot(contains('Tayyor mahsulot ombori - DEMO')),
    );
  });

  test('werka assigned warehouse fallback is searchable and unique', () {
    const profile = SessionProfile(
      role: UserRole.werka,
      displayName: 'Werka',
      legalName: '',
      ref: 'WERKA-001',
      phone: '',
      avatarUrl: '',
      assignedWarehouses: ['Kalidor', ' kalidor ', 'Tayyor mahsulot'],
    );

    final warehouses = gscaleAssignedWarehousesForProfile(
      profile,
      query: 'kal',
    );

    expect(warehouses, hasLength(1));
    expect(warehouses.single.warehouse, 'Kalidor');
  });

  test('werka without assignments fails closed', () {
    const profile = SessionProfile(
      role: UserRole.werka,
      displayName: 'Werka',
      legalName: '',
      ref: 'WERKA-001',
      phone: '',
      avatarUrl: '',
    );

    final warehouses = gscaleScopeWarehousesForProfile(
      const [GScaleCatalogWarehouse(warehouse: 'Boshqa ombor')],
      profile,
    );

    expect(warehouses, isEmpty);
  });

  test('non material create item group keeps default catalog group', () {
    const profile = SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
    );

    expect(gscaleCreateItemGroupsForProfile(profile), ['All Item Groups']);
  });
}

CustomerItemOption _option({
  required String itemCode,
  String itemName = 'Item',
  required String warehouse,
}) {
  return CustomerItemOption(
    customerRef: 'CUST-001',
    customerName: 'Customer',
    customerPhone: '+998',
    itemCode: itemCode,
    itemName: itemName,
    uom: 'kg',
    warehouse: warehouse,
  );
}
