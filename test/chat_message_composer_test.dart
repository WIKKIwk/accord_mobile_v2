import 'package:accord_mobile_v2/src/features/chat/presentation/widgets/chat_message_composer.dart';
import 'package:accord_mobile_v2/src/features/chat/presentation/widgets/chat_role_dock.dart';
import 'package:accord_mobile_v2/src/core/widgets/navigation/app_navigation_bar.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('send action follows draft and sending state', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var sends = 0;

    Future<void> pump({bool sending = false, String error = ''}) {
      return _pumpApp(
        tester,
        _testApp(
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

    await _pumpApp(
      tester,
      _testApp(
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

    await _pumpApp(
      tester,
      _testApp(
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
      return _pumpApp(
        tester,
        _testApp(
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

    await _pumpApp(
      tester,
      _testApp(
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

    await _pumpApp(
      tester,
      _testApp(
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

    await _pumpApp(
      tester,
      _testApp(
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
      return _testApp(
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

    await _pumpApp(tester, appWithInset(0));
    await tester.pumpAndSettle();
    final dock = find.byKey(const ValueKey('keyboard-aware-chat-dock'));
    expect(tester.getRect(dock).bottom, 600);
    expect(find.text('inner:0.0'), findsOneWidget);

    await _pumpApp(tester, appWithInset(300));
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

  testWidgets(
      'sending disables attachment and voice actions without losing text',
      (tester) async {
    final controller = TextEditingController(text: 'Xabar');
    addTearDown(controller.dispose);
    var sends = 0;
    var voiceActions = 0;

    await _pumpApp(
        tester,
        _testApp(
          home: Scaffold(
            body: ChatMessageComposer(
              controller: controller,
              sending: true,
              errorText: '',
              onSend: () => sends++,
              onDraftChanged: () {},
              onAttach: () {},
              onVoiceAction: () => voiceActions++,
            ),
          ),
        ));

    expect(
        tester.widget<IconButton>(_iconButton('Yuborish')).onPressed, isNull);
    expect(
        tester.widget<IconButton>(_iconButton('Media biriktirish')).onPressed,
        isNull);
    await tester.enterText(find.byType(TextField), 'Yangi xabar');
    await tester.pump();
    expect(controller.text, 'Yangi xabar');
    expect(voiceActions, 0);
    expect(sends, 0);

    controller.clear();
    await tester.pump();
    expect(
        tester.widget<IconButton>(_iconButton('Ovozli xabar yozish')).onPressed,
        isNull);
  });

  testWidgets('keyboard send respects modifier, sending, and IME composition',
      (tester) async {
    final controller = TextEditingController(text: 'Birinchi\nIkkinchi');
    addTearDown(controller.dispose);
    var sends = 0;

    Future<void> pump({bool sending = false, bool voiceBusy = false}) {
      return _pumpApp(
          tester,
          _testApp(
            home: Scaffold(
              body: ChatMessageComposer(
                controller: controller,
                sending: sending,
                voiceBusy: voiceBusy,
                errorText: '',
                onSend: () => sends++,
                onDraftChanged: () {},
              ),
            ),
          ));
    }

    Future<void> sendWith(LogicalKeyboardKey modifier) async {
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(modifier);
    }

    await pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).textInputAction,
        TextInputAction.newline);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sends, 0);
    await sendWith(LogicalKeyboardKey.controlLeft);
    await sendWith(LogicalKeyboardKey.metaLeft);
    expect(sends, 2);

    await pump(sending: true);
    await sendWith(LogicalKeyboardKey.controlLeft);
    expect(sends, 2);
    await pump(voiceBusy: true);
    await sendWith(LogicalKeyboardKey.metaLeft);
    expect(sends, 2);
    await pump();
    controller.value = const TextEditingValue(
      text: 'Composing',
      selection: TextSelection.collapsed(offset: 9),
      composing: TextRange(start: 0, end: 9),
    );
    await tester.pump();
    await sendWith(LogicalKeyboardKey.controlLeft);
    expect(sends, 2);

    controller.clear();
    await tester.pump();
    await sendWith(LogicalKeyboardKey.controlLeft);
    expect(sends, 2);
  });

  testWidgets('compact failure exposes an accessible retry inside the dock',
      (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final controller = TextEditingController(text: 'Qayta yubor');
    addTearDown(controller.dispose);
    var retries = 0;
    final semantics = tester.ensureSemantics();

    await _pumpApp(
        tester,
        _testApp(
          home: Scaffold(
            bottomNavigationBar: ChatRoleDock(
              composerController: controller,
              messageComposer: ChatMessageComposer(
                controller: controller,
                sending: false,
                errorText: 'Ulanish uzildi',
                onSend: () => retries++,
                onDraftChanged: () {},
                embeddedInDock: true,
              ),
            ),
          ),
        ));

    final retry = find.byTooltip('Qayta yuborish');
    expect(retry, findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('Ulanish uzildi'), findsWidgets);
    final dockRect =
        tester.getRect(find.byKey(const ValueKey('app-navigation-bar-shell')));
    expect(dockRect.contains(tester.getCenter(retry)), isTrue);
    expect(dockRect.height, ChatRoleDock.messageComposerHeight);
    expect(tester.takeException(), isNull);
    await tester.tap(retry);
    expect(retries, 1);
    semantics.dispose();
  });

  testWidgets('near-limit feedback counts emoji as single characters',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pumpApp(
        tester,
        _testApp(
          home: Scaffold(
            body: ChatMessageComposer(
              controller: controller,
              sending: false,
              errorText: '',
              onSend: () {},
              onDraftChanged: () {},
            ),
          ),
        ));

    await tester.enterText(find.byType(TextField), '😀' * 3600);
    await tester.pump();
    expect(find.text('3600/4000'), findsOneWidget);
    expect(tester.widget<IconButton>(_iconButton('Yuborish')).onPressed,
        isNotNull);
    controller.text = '😀' * 4001;
    await tester.pump();
    expect(
        tester.widget<IconButton>(_iconButton('Yuborish')).onPressed, isNull);
  });
}

Widget _testApp({ThemeData? theme, required Widget home}) {
  return MaterialApp(
    theme: theme,
    locale: const Locale('uz'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

Future<void> _pumpApp(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump();
}

Finder _iconButton(String tooltip) => find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == tooltip,
    );
