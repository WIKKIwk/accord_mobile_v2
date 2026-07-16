import 'package:accord_mobile_v2/src/core/widgets/feedback/m3_confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('confirm dialog can blur background when requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showM3ConfirmDialog(
                      context: context,
                      title: 'Chiqish',
                      message: 'Dasturdan chiqaymi?',
                      cancelLabel: 'Yo‘q',
                      confirmLabel: 'Ha',
                      blurBackground: true,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('Chiqish'), findsOneWidget);
  });

  testWidgets('confirm dialog accepts a themed primary confirmation color', (
    tester,
  ) async {
    const primary = Color(0xFF5B321F);
    const onPrimary = Color(0xFFFFFFFF);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showM3ConfirmDialog(
                      context: context,
                      title: 'Chiqish',
                      message: 'Dasturdan chiqaymi?',
                      cancelLabel: 'Yo‘q',
                      confirmLabel: 'Ha',
                      confirmBackgroundColor: primary,
                      confirmForegroundColor: onPrimary,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Ha'),
    );
    expect(
      confirmButton.style?.backgroundColor?.resolve({}),
      primary,
    );
    expect(
      confirmButton.style?.foregroundColor?.resolve({}),
      onPrimary,
    );
  });
}
