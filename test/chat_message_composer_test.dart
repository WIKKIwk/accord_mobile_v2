import 'package:accord_mobile_v2/src/features/chat/presentation/widgets/chat_message_composer.dart';
import 'package:accord_mobile_v2/src/features/chat/presentation/widgets/chat_role_dock.dart';
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

  testWidgets('attachment action is opt-in and keeps text sending available', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var attachments = 0;
    var sends = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: ChatMessageComposer(
            controller: controller,
            sending: false,
            errorText: '',
            onSend: () => sends++,
            onDraftChanged: () {},
            onAttach: () => attachments++,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Media biriktirish'));
    expect(attachments, 1);
    expect(sends, 0);

    await tester.enterText(find.byType(TextField), 'Matnli xabar');
    await tester.pump();
    await tester.tap(find.byTooltip('Yuborish'));
    expect(sends, 1);
  });

  testWidgets('empty composer records, sends, and cancels a voice message', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var voiceActions = 0;
    var cancellations = 0;

    Future<void> pump({bool recording = false}) {
      return tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: ChatMessageComposer(
              controller: controller,
              sending: false,
              errorText: '',
              onSend: () {},
              onDraftChanged: () {},
              onVoiceAction: () => voiceActions++,
              onCancelVoice: () => cancellations++,
              recordingVoice: recording,
              voiceDuration: const Duration(seconds: 12),
            ),
          ),
        ),
      );
    }

    await pump();
    expect(find.byTooltip('Ovozli xabar yozish'), findsOneWidget);
    await tester.tap(find.byTooltip('Ovozli xabar yozish'));
    expect(voiceActions, 1);

    await pump(recording: true);
    expect(find.text('Ovoz yozilmoqda  0:12'), findsOneWidget);
    await tester.tap(find.byTooltip('Ovozli xabarni yuborish'));
    await tester.tap(find.byTooltip('Yozuvni bekor qilish'));
    expect(voiceActions, 2);
    expect(cancellations, 1);
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
            height: 76,
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
      const Size(800, 76),
    );
  });

  testWidgets('chat dock grows with a multiline draft', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          bottomNavigationBar: ChatRoleDock(
            composerController: controller,
            messageComposer: ChatMessageComposer(
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
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const ValueKey('app-navigation-bar-shell'))),
      const Size(800, 76),
    );

    controller.text = List<String>.filled(20, 'A long draft message').join(' ');
    await tester.pump();

    final dockSize =
        tester.getSize(find.byKey(const ValueKey('app-navigation-bar-shell')));
    expect(dockSize.height, greaterThan(76));
    expect(
      dockSize.height,
      lessThanOrEqualTo(ChatRoleDock.maxMessageComposerHeight),
    );
  });

  testWidgets('composer keeps fixed boundary spacing while growing', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          bottomNavigationBar: ChatRoleDock(
            composerController: controller,
            messageComposer: ChatMessageComposer(
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

    final shell = find.byKey(const ValueKey('app-navigation-bar-shell'));
    final field = find.byType(TextField);
    final send = find.byTooltip('Yuborish');
    double? topGap;
    double? bottomGap;
    double? leftGap;
    double? sendRightGap;
    for (final draft in [
      '',
      'Hello',
      'First line\nSecond line\nThird line',
      'One\nTwo\nThree\nFour\nFive',
    ]) {
      controller.text = draft;
      await tester.pump();
      final shellRect = tester.getRect(shell);
      final fieldRect = tester.getRect(field);
      final sendRect = tester.getRect(send);
      final currentTopGap = fieldRect.top - shellRect.top;
      final currentBottomGap = shellRect.bottom - sendRect.bottom;
      final currentLeftGap = fieldRect.left - shellRect.left;
      final currentSendRightGap = shellRect.right - sendRect.right;
      topGap ??= currentTopGap;
      bottomGap ??= currentBottomGap;
      leftGap ??= currentLeftGap;
      sendRightGap ??= currentSendRightGap;
      expect(currentTopGap, closeTo(topGap, 0.5));
      expect(currentBottomGap, closeTo(bottomGap, 0.5));
      expect(currentLeftGap, closeTo(leftGap, 0.5));
      expect(currentSendRightGap, closeTo(sendRightGap, 0.5));
    }
  });

  testWidgets('chat keyboard inset lifts the dock smoothly', (tester) async {
    Widget appWithInset(double inset) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(800, 600),
            viewInsets: EdgeInsets.only(bottom: inset),
          ),
          child: ChatKeyboardInsetLayout(
            builder: (context, keyboardInset) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: keyboardInset,
                    child: const SizedBox(
                      key: ValueKey('keyboard-aware-chat-dock'),
                      height: ChatRoleDock.messageComposerHeight,
                    ),
                  ),
                  Text(
                    'inner:${MediaQuery.viewInsetsOf(context).bottom}',
                    key: const ValueKey('inner-view-inset'),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    await tester.pumpWidget(appWithInset(0));
    await tester.pumpAndSettle();
    final dock = find.byKey(const ValueKey('keyboard-aware-chat-dock'));
    expect(tester.getRect(dock).bottom, 600);
    expect(find.text('inner:0.0'), findsOneWidget);

    await tester.pumpWidget(appWithInset(300));
    await tester.pump();
    await tester.pump(
      Duration(
        milliseconds: chatKeyboardInsetAnimationDuration.inMilliseconds ~/ 2,
      ),
    );
    final midAnimationBottom = tester.getRect(dock).bottom;
    expect(midAnimationBottom, greaterThan(300));
    expect(midAnimationBottom, lessThan(600));

    await tester.pumpAndSettle();
    expect(tester.getRect(dock).bottom, closeTo(300, 0.5));
    expect(tester.getSize(dock).height, ChatRoleDock.messageComposerHeight);
  });
}
