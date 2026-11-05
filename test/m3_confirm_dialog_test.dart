import 'package:accord_mobile_v2/src/core/widgets/feedback/m3_confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('long confirmation message fits a short viewport', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 480);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    bool? confirmed;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              confirmed = await showM3ConfirmDialog(
                context: context,
                title: 'Confirm',
                message: List.filled(100, 'Confirmation details.').join(' '),
                cancelLabel: 'Cancel',
                confirmLabel: 'Continue',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final confirm = find.widgetWithText(FilledButton, 'Continue');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });

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
