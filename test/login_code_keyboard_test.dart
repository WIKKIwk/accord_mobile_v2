import 'package:accord_mobile_v2/src/features/auth/presentation/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('worker and system user prefixes use the numeric keyboard', () {
    expect(loginCodeUsesNumericKeyboard(''), isTrue);
    expect(loginCodeUsesNumericKeyboard('4'), isTrue);
    expect(loginCodeUsesNumericKeyboard('40XXXXXXXXXX'), isTrue);
    expect(loginCodeUsesNumericKeyboard('50XXXXXXXXXX'), isTrue);
    expect(loginCodeUsesNumericKeyboard('80XXXXXXXXXX'), isTrue);
  });

  test('other role prefixes keep alphanumeric code input', () {
    expect(loginCodeUsesNumericKeyboard('10CUSTOM'), isFalse);
    expect(loginCodeUsesNumericKeyboard('20ABCDEF1234'), isFalse);
    expect(loginCodeUsesNumericKeyboard('30CUSTOM'), isFalse);
    expect(loginCodeUsesNumericKeyboard('60ABCDEF1234'), isFalse);
    expect(loginCodeUsesNumericKeyboard('70ABCDEF1234'), isFalse);
  });
}
