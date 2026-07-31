import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    resetMobileApiTestModeData();
  });

  tearDown(() async {
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(false);
  });

  test('test mode returns demo admin users without server', () async {
    await TestModeController.instance.setEnabled(true);

    final suppliers = await MobileApi.instance.adminSuppliers();
    final customers = await MobileApi.instance.adminCustomers();
    final settings = await MobileApi.instance.adminSettings();

    expect(settings.werkaName, 'Demo omborchi');
    expect(suppliers.map((item) => item.ref), contains('demo-supplier-1'));
    expect(customers.map((item) => item.ref), contains('demo-customer-1'));
  });

  test('test mode can be switched off', () async {
    await TestModeController.instance.setEnabled(true);
    expect(await TestModeController.instance.isEnabled(), isTrue);

    await TestModeController.instance.setEnabled(false);
    expect(await TestModeController.instance.isEnabled(), isFalse);
  });

  test('test mode returns searchable demo products without server', () async {
    await TestModeController.instance.setEnabled(true);

    final allItems = await MobileApi.instance.adminItemsPage();
    final filtered = await MobileApi.instance.adminItemsPage(query: 'cpp');

    expect(allItems.map((item) => item.code), contains('DEMO-HOTLUNCH'));
    expect(filtered, hasLength(1));
    expect(filtered.single.code, 'DEMO-CPP');
  });

  test('test mode item deletion removes it from detail and list', () async {
    await TestModeController.instance.setEnabled(true);

    expect((await MobileApi.instance.adminItemDetail('DEMO-INK')).code,
        'DEMO-INK');
    await MobileApi.instance.adminDeleteItem('DEMO-INK');

    final items = await MobileApi.instance.adminItemsPage();
    expect(items.map((item) => item.code), isNot(contains('DEMO-INK')));
    await expectLater(
      MobileApi.instance.adminItemDetail('DEMO-INK'),
      throwsA(
        isA<MobileApiException>()
            .having((error) => error.statusCode, 'statusCode', 404)
            .having((error) => error.message, 'message', 'Item topilmadi'),
      ),
    );
  });

  test('test mode returns demo warehouses without server', () async {
    await TestModeController.instance.setEnabled(true);

    final warehouses = await MobileApi.instance.adminWarehouses(query: 'xom');

    expect(warehouses, hasLength(1));
    expect(warehouses.single.warehouse, 'Xomashyo ombori - DEMO');
  });

  test('test mode filters apparatus warehouses by parent', () async {
    await TestModeController.instance.setEnabled(true);

    final warehouses = await MobileApi.instance.adminWarehouses(
      parent: 'aparat - A',
    );

    expect(warehouses.map((item) => item.warehouse), [
      'Godex aparat - DEMO',
      '7 ta rangli bosma aparat',
      '8 ta rangli bosma aparat',
      '9 ta rangli bosma aparat',
      'Laminatsiya 1',
      'Laminatsiya 2',
    ]);
  });

  test('test mode exposes apparatus through its own typed catalog', () async {
    await TestModeController.instance.setEnabled(true);

    final apparatus = await MobileApi.instance.adminApparatus(query: 'laminat');

    expect(
      apparatus.map((item) => item.name),
      ['Laminatsiya 1', 'Laminatsiya 2'],
    );
  });

  test('apparatus catalog preserves semantic master metadata', () async {
    await TestModeController.instance.setEnabled(true);

    final apparatus = await MobileApi.instance.adminApparatus();
    final flexo = apparatus.singleWhere((item) => item.name == 'Flexo pechat');
    final sevenColor = apparatus.singleWhere(
      (item) => item.name == '7 ta rangli bosma aparat',
    );

    expect(flexo.family, 'pechat');
    expect(flexo.kind, 'flexo');
    expect(flexo.isPechat, isTrue);
    expect(flexo.isFlexo, isTrue);
    expect(sevenColor.kind, 'color_pechat');
    expect(sevenColor.colorStations, 7);
  });

  test('warehouse and apparatus can safely have the same name', () async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance.adminCreateApparatus('Xomashyo ombori - DEMO');

    final warehouses = await MobileApi.instance.adminWarehouses(
      query: 'Xomashyo ombori - DEMO',
    );
    final apparatus = await MobileApi.instance.adminApparatus(
      query: 'Xomashyo ombori - DEMO',
    );

    expect(warehouses.map((item) => item.warehouse), [
      'Xomashyo ombori - DEMO',
    ]);
    expect(apparatus.map((item) => item.name), [
      'Xomashyo ombori - DEMO',
    ]);
  });
}
