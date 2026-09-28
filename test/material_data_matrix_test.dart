import 'package:accord_mobile_v2/src/core/printing/material_data_matrix.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final epc in ['30D97A14CEB04D30B156968F', '30D97C6BFC81E170627AE591']) {
    for (final size in [104, 174, 261]) {
      test('ECC 200 fills the $size dot print bounds for $epc', () {
        final bars = materialDataMatrixBars(epc);
        final pixels = List.generate(size, (_) => List.filled(size, false));
        var minX = size, minY = size, maxX = 0, maxY = 0;
        for (final bar in bars) {
          expect(bar, hasLength(4));
          expect(
              bar.every((value) => value.isFinite && value >= 0 && value <= 1),
              isTrue);
          // Same edge rounding as the Android and iOS printer renderers.
          final left = (bar[0] * size).round();
          final top = (bar[1] * size).round();
          final right = (bar[2] * size).round();
          final bottom = (bar[3] * size).round();
          expect(right, greaterThan(left));
          expect(bottom, greaterThan(top));
          if (left < minX) minX = left;
          if (top < minY) minY = top;
          if (right > maxX) maxX = right;
          if (bottom > maxY) maxY = bottom;
          for (var y = top; y < bottom; y++) {
            for (var x = left; x < right; x++) {
              expect(pixels[y][x], isFalse, reason: 'Bars must not overlap');
              pixels[y][x] = true;
            }
          }
        }
        expect([minX, minY, maxX, maxY], [0, 0, size, size]);
        // A continuous L finder pattern must span the entire printed symbol.
        expect(pixels.every((row) => row.first), isTrue);
        expect(pixels.last.every((pixel) => pixel), isTrue);
        expect(pixels.first, contains(false));
      });
    }
  }
}
