import 'package:erpnext_stock_mobile/src/core/api/mobile_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
          'width_sm': 64.5,
          'base_length': 9302.33,
          'waste_length': 465.12,
          'rounded_length': 10000,
        }
      ],
    });

    expect(response.rubberSizeMm, 650);
  });
}
