import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('qolip has twelve default color options', () {
    expect(qolipDefaultColors, hasLength(12));
    expect(qolipDefaultColors.map((option) => option.value).toSet(),
        hasLength(12));
  });

  test('qolip Panton numbers are limited to one through seven', () {
    expect(qolipPantonNumber('PANTON 1'), 1);
    expect(qolipPantonNumber('PANTON 7'), 7);
    expect(qolipPantonNumber('PANTON 8'), isNull);
  });

  testWidgets('qolip color picker renders every default color', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QolipColorPicker(
            selectedColor: null,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(QolipColorPicker), findsOneWidget);
    for (final option in qolipDefaultColors) {
      expect(find.text(option.name), findsOneWidget);
    }
    expect(find.text('Panton 1'), findsOneWidget);
    expect(find.text('Panton 2'), findsNothing);
  });
}
