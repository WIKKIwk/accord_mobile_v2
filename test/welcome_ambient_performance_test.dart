import 'package:accord_mobile_v2/src/features/auth/presentation/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ambient animation repaints without rebuilding its widget tree', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 800,
          child: AuthAmbientOutlineBackground(
            outlineColor: Colors.white,
            accentColor: Colors.blue,
            backgroundColor: Colors.black,
            isDarkBackground: true,
          ),
        ),
      ),
    );

    final finder = find.descendant(
      of: find.byType(AuthAmbientOutlineBackground),
      matching: find.byType(CustomPaint),
    );
    final before = tester.widget<CustomPaint>(finder);

    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.widget<CustomPaint>(finder), same(before));
  });
}
