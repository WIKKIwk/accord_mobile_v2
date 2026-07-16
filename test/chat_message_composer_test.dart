import 'package:accord_mobile_v2/src/features/chat/presentation/widgets/chat_message_composer.dart';
import 'package:accord_mobile_v2/src/core/widgets/navigation/app_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('send action follows draft and sending state', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var sends = 0;

    Future<void> pump({bool sending = false, String error = ''}) {
      return tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: ChatMessageComposer(
              controller: controller,
              sending: sending,
              errorText: error,
              onSend: () => sends++,
              onDraftChanged: () {},
            ),
          ),
        ),
      );
    }

    await pump();
    final sendButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Yuborish',
    );
    IconButton button = tester.widget(sendButton);
    expect(button.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Salom');
    await tester.pump();
    button = tester.widget(sendButton);
    expect(button.onPressed, isNotNull);
    await tester.tap(sendButton);
    expect(sends, 1);

    await pump(sending: true);
    button = tester.widget(sendButton);
    expect(button.onPressed, isNull);
  });

  testWidgets('failed draft exposes an inline retry action', (tester) async {
    final controller = TextEditingController(text: 'Qayta yubor');
    addTearDown(controller.dispose);
    var retries = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: ChatMessageComposer(
            controller: controller,
            sending: false,
            errorText: 'Ulanish uzildi',
            onSend: () => retries++,
            onDraftChanged: () {},
          ),
        ),
      ),
    );

    expect(find.text('Ulanish uzildi'), findsOneWidget);
    await tester.tap(find.text('Qayta yuborish'));
    expect(retries, 1);
  });

  testWidgets('embedded composer fits the shared navigation dock', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          bottomNavigationBar: AppNavigationBar(
            height: 60,
            destinations: const [],
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            content: ChatMessageComposer(
              controller: controller,
              sending: false,
              errorText: '',
              onSend: () {},
              onDraftChanged: () {},
              embeddedInDock: true,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('app-navigation-bar-shell'))),
      const Size(800, 60),
    );
  });
}
