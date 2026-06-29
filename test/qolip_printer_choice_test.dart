import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('qolip printer choice uses printer kind before display label', () {
    final printer = qolipPrinterChoiceForDriver(
      kind: 'godex',
      label: 'ulangan',
    );

    expect(printer, 'godex');
  });
}
