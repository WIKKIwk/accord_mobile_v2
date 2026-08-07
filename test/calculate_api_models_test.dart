import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await TestModeController.instance.setEnabled(true);
    resetMobileApiCalculateTestModeData();
  });

  tearDown(() async {
    await TestModeController.instance.setEnabled(false);
  });

  test('calculate response parses rubber size', () {
    final response = CalculateResponse.fromJson(const {
      'ok': true,
      'kg': 300,
      'width_mm': 645,
      'rubber_size_mm': 650,
      'waste_percent': 5,
      'layers': [],
      'results': [
        {
          'first_coeff': 1,
          'other_coeff': 2,
          'coeff_sum': 3,
          'film_gsm': 44.4,
          'adhesive_gsm': 2.5,
          'total_gsm': 46.9,
          'width_sm': 64.5,
          'base_length': 9302.33,
          'waste_length': 465.12,
          'rounded_length': 10000,
        },
      ],
    });

    expect(response.rubberSizeMm, 650);
    expect(response.results.single.totalGsm, 46.9);
  });

  test('material parses density and optional actual GSM', () {
    final material = CalculateMaterial.fromJson(const {
      'id': 'pet',
      'name': 'PET',
      'aliases': ['pet'],
      'active': true,
      'density_g_cm3': 1.4,
      'variants': [
        {'micron': 12},
        {'micron': 20, 'actual_gsm': 27.5},
      ],
    });

    expect(material.densityGCm3, 1.4);
    expect(material.variants.first.actualGsm, isNull);
    expect(material.variants.last.actualGsm, 27.5);
    expect(material.toJson()['density_g_cm3'], 1.4);
  });

  test('1000 kg PET 12 + PET 12 uses physical GSM formula', () async {
    final response = await MobileApi.instance.calculate(
      const CalculateRequest(
        kg: 1000,
        frameProductSizeMm: 250,
        frameCount: 3,
        wastePercent: 5,
        layers: [
          CalculateLayerInput(
            materialId: 'builtin-pet',
            material: 'PET',
            micron: '12',
          ),
          CalculateLayerInput(
            materialId: 'builtin-pet',
            material: 'PET',
            micron: '12',
          ),
        ],
      ),
    );

    final result = response.results.single;
    expect(response.widthMm, 765);
    expect(result.filmGsm, closeTo(33.6, 0.001));
    expect(result.adhesiveGsm, 2.5);
    expect(result.totalGsm, closeTo(36.1, 0.001));
    expect(result.baseLength, closeTo(36210.2366, 0.001));
    expect(result.wasteLength, closeTo(1905.8019, 0.001));
    expect(result.roundedLength, 38500);
  });
}
