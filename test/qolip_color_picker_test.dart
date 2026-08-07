import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('qolip has fifteen default color options including new colors', () {
    expect(qolipDefaultColors, hasLength(15));
    expect(qolipDefaultColors.map((option) => option.value).toSet(),
        hasLength(15));
    expect(
      qolipDefaultColors,
      contains(const QolipColorOption(name: 'Oq', value: '#FFFFFF')),
    );
    expect(
      qolipDefaultColors,
      contains(const QolipColorOption(name: 'Tilla', value: '#D4A72C')),
    );
    expect(
      qolipDefaultColors,
      contains(const QolipColorOption(name: 'Matlak', value: '#B7BCC2')),
    );
  });

  test('qolip Panton numbers support the batch limit', () {
    expect(qolipPantonNumber('PANTON 1'), 1);
    expect(qolipPantonNumber('PANTON 7'), 7);
    expect(qolipPantonNumber('PANTON 8'), 8);
    expect(qolipPantonNumber('PANTON 100'), 100);
    expect(qolipPantonNumber('PANTON 101'), isNull);
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

  testWidgets('qolip color picker returns white when white is selected',
      (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QolipColorPicker(
            selectedColor: selected,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Oq'));

    expect(selected, '#FFFFFF');
  });

  testWidgets('qolip color picker returns the added colors', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QolipColorPicker(
            selectedColor: selected,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tilla'));
    expect(selected, '#D4A72C');
    await tester.tap(find.text('Matlak'));
    expect(selected, '#B7BCC2');
  });

  testWidgets('qolip color picker supports a limited multi-selection',
      (tester) async {
    var selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => QolipColorPicker(
              selectedColors: selected,
              maxSelectedColors: 2,
              onColorsChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Qizil'));
    await tester.pump();
    await tester.tap(find.text('To‘q sariq'));
    await tester.pump();
    await tester.tap(find.text('Sariq'));
    await tester.pump();

    expect(selected, ['#E53935', '#FB8C00']);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('qolip color picker adds and selects dynamic Panton colors',
      (tester) async {
    var selected = <String>[];
    var pantonNumbers = <int>[1];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => QolipColorPicker(
              selectedColors: selected,
              pantonNumbers: pantonNumbers,
              maxSelectedColors: 5,
              onAddPanton: () => setState(
                () =>
                    pantonNumbers = [...pantonNumbers, pantonNumbers.last + 1],
              ),
              onColorsChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('qolip-add-panton')));
    await tester.pump();
    await tester.tap(find.text('Panton 2'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('qolip-add-panton')));
    await tester.pump();

    expect(find.text('Panton 2'), findsOneWidget);
    expect(find.text('Panton 3'), findsOneWidget);
    expect(selected, ['PANTON 2']);
    expect(find.text('1'), findsOneWidget);
  });
}
