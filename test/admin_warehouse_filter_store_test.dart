import 'package:accord_mobile_v2/src/features/admin/state/admin_warehouse_filter_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AdminWarehouseFilterStore.instance.clearCache();
  });

  const warehouses = ['Asosiy ombor', 'Qoliplar ombori', 'Xomashyo ombori'];

  test('saves and restores selected warehouse', () async {
    final store = AdminWarehouseFilterStore.instance;

    await store.saveWarehouse('Asosiy ombor');
    expect(store.cachedWarehouse, 'Asosiy ombor');

    final resolved = store.resolveWarehouse(warehouses);
    expect(resolved, 'Asosiy ombor');

    store.clearCache();
    expect(store.cachedWarehouse, isNull);

    await store.loadSavedWarehouse();
    expect(store.cachedWarehouse, 'Asosiy ombor');
    expect(store.resolveWarehouse(warehouses), 'Asosiy ombor');
  });

  test('resolves case-insensitively and returns null if not available', () {
    final store = AdminWarehouseFilterStore.instance;

    expect(
      store.resolveWarehouse(warehouses, preferred: 'asosiy ombor'),
      'Asosiy ombor',
    );
    expect(
      store.resolveWarehouse(warehouses, preferred: 'Noma’lum ombor'),
      isNull,
    );
  });
}
