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

  test('custom apparatus keeps its stable id while being renamed', () async {
    await TestModeController.instance.setEnabled(true);

    final created = await MobileApi.instance.adminCreateApparatus(
      'Flexo liniya 1',
      family: 'pechat',
      kind: 'flexo',
      capabilities: const ['print', 'pechat', 'flexo'],
    );
    final renamed = await MobileApi.instance.adminCreateApparatus(
      'Flexo liniya 2',
      id: created.id,
      family: 'pechat',
      kind: 'flexo',
      capabilities: const ['print', 'pechat', 'flexo'],
    );

    expect(renamed.id, created.id);
    expect(renamed.name, 'Flexo liniya 2');
    expect(renamed.isPechat, isTrue);
    expect(renamed.isFlexo, isTrue);
    expect(
      (await MobileApi.instance.adminApparatus(query: 'Flexo liniya 2'))
          .single
          .id,
      created.id,
    );
  });
}
