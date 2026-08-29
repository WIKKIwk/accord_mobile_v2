import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_warehouses_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/inventory_movement_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'admin_warehouses_screen_test_helpers_part_01.dart';
part 'admin_warehouses_screen_test_cases_resplit_part_01.dart';
part 'admin_warehouses_screen_test_cases_resplit_part_02.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access', 'catalog.item.read'],
    );
    seedMobileApiInventoryMovementTestData(
      locations: const [
        InventoryLocation(
          id: 'inventory_location:warehouse:demo-raw',
          kind: InventoryLocationKind.warehouse,
          name: 'Xomashyo ombori - DEMO',
          warehouseId: 'warehouse:demo-raw',
        ),
      ],
      assets: const [
        InventoryAsset(
          kind: InventoryAssetKind.rawMaterial,
          assetRef: 'raw:30aa',
          custodyWarehouseId: 'warehouse:demo-raw',
          custodyWarehouse: 'Xomashyo ombori - DEMO',
          itemCode: 'DEMO-RAW-001',
          itemName: 'Demo xomashyo rulon',
          identifier: '30AA',
          qty: 12,
          uom: 'Kg',
          status: 'available',
          physicalLocation: InventoryLocationReference(
            id: 'inventory_location:warehouse:demo-raw',
            kind: InventoryLocationKind.warehouse,
            name: 'Xomashyo ombori - DEMO',
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  _registeradmin_warehouses_screen_testCases01();

  _registeradmin_warehouses_screen_testCases02();
}

const _warehouseFilterKey = ValueKey('admin-warehouse-filter-chip');
const _primaryNavigationButtonKey = ValueKey('app-primary-navigation-button');
