import 'package:accord_mobile_v2/src/core/widgets/display/marquee_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child, {double width = 200}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(width: width, child: child),
    ),
  );
}

void main() {
  testWidgets('short text stays static with ellipsis, no marquee',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const OverflowMarqueeText(
          text: 'Qisqa nom',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
    await tester.pump();
    // Sig'gan matnda ClipRect (marquee) bo'lmasligi kerak.
    expect(find.byType(ClipRect), findsNothing);
    expect(find.text('Qisqa nom'), findsOneWidget);
  });

  testWidgets('long text becomes marquee and scrolls forth and back',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const OverflowMarqueeText(
          text: 'Xotluch sochnay juda uzun nomli zakaz matni davomi bor',
          style: TextStyle(fontSize: 16),
          startDelay: Duration(milliseconds: 100),
          endPause: Duration(milliseconds: 100),
          returnPause: Duration(milliseconds: 100),
          minScrollDuration: Duration(milliseconds: 200),
        ),
        width: 120,
      ),
    );
    await tester.pump();
    // Sig'magan matnda marquee (ClipRect) paydo bo'ladi.
    expect(find.byType(ClipRect), findsWidgets);
    // Animatsiya oldinga-borib orqaga qaytishi kerak (xatoliksiz).
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Xotluch'), findsOneWidget);
  });
}
