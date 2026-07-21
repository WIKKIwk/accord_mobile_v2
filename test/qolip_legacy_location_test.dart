import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'token';
  });

  tearDown(() async {
    AppSession.instance.token = null;
    await TestModeController.instance.setEnabled(false);
  });

  test('location-only legacy qolip stays visible and can be deleted', () async {
    const qolipCode = 'Q-LEGACY-LOCATION-ONLY';
    await MobileApi.instance.qolipSaveLocation(
      block: const QolipBlock(name: 'A', warehouse: 'Qolip ombori'),
      product: const QolipProduct(
        code: 'ITEM-LEGACY-LOCATION-ONLY',
        name: 'Legacy location product',
        itemGroup: 'Tayyor mahsulot',
      ),
      qolipCode: qolipCode,
      size: 44,
      quantity: 1,
      rowLetter: 'A',
      columnNumber: 13,
    );

    final products = await MobileApi.instance.qolipProducts(
      query: qolipCode,
      limit: 20,
      withQolipOnly: true,
    );
    expect(products.map((product) => product.qolipCode), contains(qolipCode));

    final deleted = await MobileApi.instance.qolipDeleteProductSpecs(
      const [qolipCode],
    );
    expect(deleted, 1);
    expect(
      await MobileApi.instance.qolipProducts(
        query: qolipCode,
        limit: 20,
        withQolipOnly: true,
      ),
      isEmpty,
    );
  });
}
