import 'package:accord_mobile_v2/src/core/production/roll_weight_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tare bound preserves valid, equal, precise and unknown weights', () {
    expect(bobinaExceedsGross(55, 0.808), isFalse);
    expect(bobinaExceedsGross(55, 55), isFalse);
    expect(bobinaExceedsGross(55, 808), isTrue);
    expect(bobinaExceedsGross(55.0000001, 55.0000002), isFalse);
    expect(bobinaExceedsGross(55, 55.000001), isTrue);
    expect(bobinaExceedsGross(55, null), isFalse);
    expect(bobinaExceedsGross(null, 808), isFalse);
    expect(bobinaExceedsGross(double.nan, 808), isFalse);
  });

  test('correction bound uses measured gross until kg actually changes', () {
    double? gross(double? kg, {Object? measured = 12}) => correctedRollGrossKg(
          previousFinishedGoodsKg: 10,
          finishedGoodsKg: kg,
          previousGrossQty: measured,
        );
    expect(gross(10), 12);
    expect(bobinaExceedsGross(gross(10), 11), isFalse);
    expect(bobinaExceedsGross(gross(10), 12), isFalse);
    expect(bobinaExceedsGross(gross(10), 13), isTrue);
    expect(gross(9), 9);
    expect(bobinaExceedsGross(gross(9), 11), isTrue);
    expect(gross(10.0000002), 12);
    expect(gross(null), isNull);
    expect(gross(10, measured: null), 10);
    expect(gross(10, measured: 'invalid'), isNull);
  });
}
