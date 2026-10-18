import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/features/chat/models/chat_media_models.dart';
import 'package:accord_mobile_v2/src/features/chat/models/chat_models.dart';
import 'package:accord_mobile_v2/src/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:accord_mobile_v2/src/features/chat/state/chat_audio_playback_controller.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _audio = ChatMessageAttachment(
  attachmentId: 'audio-attachment',
  mediaId: 'audio-media',
  kind: ChatMediaKind.audio,
  contentType: 'audio/mp4',
  sizeBytes: 4096,
  widthPixels: 0,
  heightPixels: 0,
  durationMs: 30000,
  contentUrl: '/audio',
  thumbnailUrl: '',
);

ChatMessage _message({
  String body = 'Xabar matni',
  ChatMessageAttachment? attachment,
}) =>
    ChatMessage(
      messageId: 'message-1',
      conversationId: 'conversation-1',
      senderPrincipalId: 'peer-1',
      senderRole: UserRole.customer,
      senderRef: 'customer-1',
      senderDisplayName: 'Akmal',
      clientMessageId: 'client-1',
      sequence: 1,
      type: attachment == null ? 'text' : 'audio',
      body: body,
      createdAtUnix: 1700000000,
      editedAtUnix: 1700000060,
      attachment: attachment,
    );

Widget _app(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

Finder _bubbleGesture() => find.descendant(
      of: find.byType(ChatMessageBubble),
      matching: find.byWidgetPredicate(
          (widget) => widget is GestureDetector && widget.onLongPress != null),
    );

void main() {
  testWidgets(
      'long press copies exact text and shows only known message details',
      (tester) async {
    const body = '  Birinchi qator\nIkkinchi qator  ';
    final playback = ChatAudioPlaybackController();
    addTearDown(playback.dispose);
    String? copiedText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(_app(ListView(children: [
      ChatMessageBubble(
          message: _message(body: body), mine: false, playback: playback),
    ])));
    await tester.pumpAndSettle();
    await tester.longPress(_bubbleGesture());
    await tester.pumpAndSettle();

    expect(find.text('Akmal'), findsOneWidget);
    expect(find.textContaining('Yuborilgan:'), findsOneWidget);
    expect(find.textContaining('Tahrirlangan:'), findsOneWidget);
    expect(find.textContaining('O‘qilgan'), findsNothing);
    expect(find.textContaining('Yetkazilgan'), findsNothing);
    await tester.tap(find.text('Nusxa olish'));
    await tester.pumpAndSettle();
    expect(copiedText, body);
    expect(find.text('Matn nusxalandi'), findsOneWidget);
  });

  testWidgets('full text opens selectable scrollable dialog on a small screen',
      (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(360, 640);
    addTearDown(tester.view.reset);
    final body = List.generate(80, (index) => 'Qator $index').join('\n');
    final playback = ChatAudioPlaybackController();
    addTearDown(playback.dispose);
    await tester.pumpWidget(_app(ListView(children: [
      ChatMessageBubble(
          message: _message(body: body), mine: false, playback: playback),
    ])));
    await tester.pumpAndSettle();
    await tester.longPressAt(const Offset(80, 70));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matnni tanlash'));
    await tester.pumpAndSettle();

    expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data, body);
    expect(find.text('Xabar matni'), findsOneWidget);
    final dialogScroll = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(SingleChildScrollView),
    );
    await tester.drag(dialogScroll, const Offset(0, -200));
    await tester.pumpAndSettle();
    final scrollState = tester.state<ScrollableState>(find
        .descendant(
          of: dialogScroll,
          matching: find.byType(Scrollable),
        )
        .first);
    expect(scrollState.position.pixels, greaterThan(100));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Yopish'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('audio caption can be copied and horizontal seeking still works',
      (tester) async {
    final playback = _TestAudioPlayback();
    addTearDown(playback.dispose);
    String? copiedText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(_app(ListView(children: [
      ChatMessageBubble(
        message: _message(body: 'Ovozli xabar izohi', attachment: _audio),
        mine: false,
        playback: playback,
      ),
    ])));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Eshitish'));
    expect(playback.toggles, 1);
    final slider = find.byWidgetPredicate((widget) =>
        widget is GestureDetector && widget.onHorizontalDragUpdate != null);
    await tester.drag(slider, const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(playback.seeks, isNotEmpty);
    expect(playback.seeks.last, greaterThan(0));
    expect(find.byType(BottomSheet), findsNothing);

    await tester.pumpAndSettle();
    await tester.longPress(_bubbleGesture());
    await tester.pumpAndSettle();
    expect(find.text('Nusxa olish'), findsOneWidget);
    expect(find.text('Matnni tanlash'), findsOneWidget);
    await tester.tap(find.text('Nusxa olish'));
    await tester.pumpAndSettle();
    expect(copiedText, 'Ovozli xabar izohi');
  });

  testWidgets(
      'media without a caption offers details without empty text actions',
      (tester) async {
    final playback = ChatAudioPlaybackController();
    addTearDown(playback.dispose);
    await tester.pumpWidget(_app(ListView(children: [
      ChatMessageBubble(
        message: _message(body: '', attachment: _audio),
        mine: false,
        playback: playback,
      ),
    ])));
    await tester.pumpAndSettle();
    await tester.longPress(_bubbleGesture());
    await tester.pumpAndSettle();
    expect(find.textContaining('Yuborilgan:'), findsOneWidget);
    expect(find.text('Nusxa olish'), findsNothing);
    expect(find.text('Matnni tanlash'), findsNothing);
  });

  testWidgets('bubble actions preserve scrolling in a centered chat timeline',
      (tester) async {
    final playback = ChatAudioPlaybackController();
    final scroll = ScrollController();
    addTearDown(playback.dispose);
    addTearDown(scroll.dispose);
    const centerKey = ValueKey('timeline-center');
    await tester.pumpWidget(_app(CustomScrollView(
      controller: scroll,
      center: centerKey,
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        SliverList.builder(
          key: centerKey,
          itemCount: 40,
          itemBuilder: (_, index) => ChatMessageBubble(
            message: _message(body: 'Xabar $index'),
            mine: false,
            playback: playback,
          ),
        ),
      ],
    )));
    await tester.pumpAndSettle();
    final gesture =
        await tester.startGesture(tester.getCenter(_bubbleGesture().at(5)));
    for (var index = 0; index < 5; index++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(60));
    expect(find.byType(BottomSheet), findsNothing);

    final beforeSheet = scroll.offset;
    await tester.longPress(_bubbleGesture().hitTestable().at(2));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.drag(find.byType(BottomSheet), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(scroll.offset, closeTo(beforeSheet, 0.5));
    await tester.drag(
        _bubbleGesture().hitTestable().at(2), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(beforeSheet + 50));
  });
}

class _TestAudioPlayback extends ChatAudioPlaybackController {
  final seeks = <double>[];
  int toggles = 0;

  @override
  bool isCurrent(ChatMessage message) => true;

  @override
  Duration get currentDuration => const Duration(seconds: 30);

  @override
  Future<void> toggle(ChatMessage message) async => toggles++;

  @override
  Future<void> seek(double milliseconds) async => seeks.add(milliseconds);
}
