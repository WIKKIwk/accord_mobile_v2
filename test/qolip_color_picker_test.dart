import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('qolip has twelve default color options', () {
    expect(qolipDefaultColors, hasLength(12));
    expect(qolipDefaultColors.map((option) => option.value).toSet(),
        hasLength(12));
  });

  test('qolip has seven Panton color options', () {
    expect(qolipPantonColors, hasLength(7));
    expect(qolipPantonColors.map((option) => option.name),
        orderedEquals(const [
          'Panton 1',
          'Panton 2',
          'Panton 3',
          'Panton 4',
          'Panton 5',
          'Panton 6',
          'Panton 7',
        ]));
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
      expect(find.bySemanticsLabel(option.name), findsOneWidget);
    }
    for (final option in qolipPantonColors) {
      expect(find.bySemanticsLabel(option.name), findsOneWidget);
    }
  });
}
