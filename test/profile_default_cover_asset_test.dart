import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('profile default cover is bundled', () async {
    final bytes = await rootBundle.load(
      'assets/images/profile_default_cover.webp',
    );

    expect(bytes.lengthInBytes, greaterThan(0));
  });
}
