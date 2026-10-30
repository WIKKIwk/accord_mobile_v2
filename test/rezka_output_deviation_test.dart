import 'package:accord_mobile_v2/src/core/production/rezka_output_deviation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rezka measurement deviation', () {
    test('reports omitted decimal and both deviation directions', () {
      expect(
        rezkaOutputDeviationPercent(reference: 12.6, actual: 126),
        closeTo(900, 1e-9),
      );
      expect(
        rezkaOutputDeviationPercent(reference: 12.6, actual: 1.26),
        closeTo(-90, 1e-9),
      );
    });

    test('accepts equal measurements and inclusive ten percent boundaries', () {
      for (final (reference, actual) in <(double, double)>[
        (12.6, 12.6),
        (12.6, 11.34),
        (12.6, 13.86),
        (0.1, 0.09),
        (0.1, 0.11),
        (0.000001, 0.0000009),
        (0.000001, 0.0000011),
        (1000, 900),
        (1000, 1100),
      ]) {
        expect(
          rezkaOutputDeviationPercent(reference: reference, actual: actual),
          isNull,
          reason: '$actual should be inside the band around $reference',
        );
      }
    });

    test('warns immediately outside either boundary at stored precision', () {
      expect(
        rezkaOutputDeviationPercent(reference: 12.6, actual: 13.860001),
        greaterThan(10),
      );
      expect(
        rezkaOutputDeviationPercent(reference: 12.6, actual: 11.339999),
        lessThan(-10),
      );
    });

    test('leaves invalid and missing measurements to form validation', () {
      for (final invalid in <double?>[
        null,
        0,
        -1,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          rezkaOutputDeviationPercent(reference: invalid, actual: 12.6),
          isNull,
        );
        expect(
          rezkaOutputDeviationPercent(reference: 12.6, actual: invalid),
          isNull,
        );
      }
    });

    test('keeps extreme positive deviations finite for the warning display',
        () {
      final percentage = rezkaOutputDeviationPercent(
        reference: 1e-300,
        actual: 1e300,
      );
      expect(percentage, isNotNull);
      expect(percentage!.isFinite, isTrue);
      expect(percentage, greaterThan(10));
    });
  });
}
