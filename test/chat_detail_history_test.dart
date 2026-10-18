import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/chat/models/chat_models.dart';
import 'package:accord_mobile_v2/src/features/chat/presentation/chat_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:accord_mobile_v2/src/features/chat/state/chat_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

const _conversation = ChatConversation(
  conversationId: 'history-regression',
  kind: 'dm',
  title: 'History regression',
  peer: null,
  lastMessage: null,
  lastMessageSequence: 130,
  unreadCount: 0,
  updatedAtUnix: 1700000130,
);

http.Response _page(int first, int last, {bool hasMore = false}) =>
    http.Response(
      jsonEncode({
        'items': [
          for (var sequence = first; sequence <= last; sequence++)
            {
              'message_id': 'message-$sequence',
              'conversation_id': _conversation.conversationId,
              'sender_principal_id': 'peer',
              'sender_role': 'admin',
              'sender_ref': 'peer',
              'sender_display_name': 'Peer',
              'client_message_id': 'client-$sequence',
              'sequence': sequence,
              'type': 'text',
              'body': 'Message $sequence ${'line\n' * (sequence % 5)}',
              'created_at_unix': 1700000000 + sequence,
            },
        ],
        'has_more': hasMore,
      }),
      200,
    );

Future<void> _mount(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.android,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ChatDetailScreen(conversation: _conversation),
    ),
  );
  await tester.pumpAndSettle();
  ChatStore.instance.pauseRealtime();
}

Future<void> _withApi(
  WidgetTester tester,
  FutureOr<http.Response> Function(http.Request) handler,
  Future<void> Function() body,
) async {
  await http.runWithClient(
    () async {
      try {
        await body();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        ChatStore.instance.clearMemory();
      }
    },
    () => MockClient((request) async {
      if (request.url.path.endsWith('/socket-ticket')) {
        return http.Response('{"error":"offline"}', 503);
      }
      if (request.url.path.endsWith('/messages')) return handler(request);
      return http.Response('{"events":[],"items":[],"has_more":false}', 200);
    }),
  );
}

({Finder finder, int sequence, double y}) _visibleAnchor(WidgetTester tester) {
  final viewport = tester.getRect(find.byKey(const ValueKey('chat-timeline')));
  for (final element in find.byType(ChatMessageBubble).evaluate()) {
    final bubble = element.widget as ChatMessageBubble;
    final finder = find.byKey(ValueKey(bubble.message.messageId));
    final rect = tester.getRect(finder);
    if (rect.top >= viewport.top + 20 && rect.bottom <= viewport.bottom - 20) {
      return (finder: finder, sequence: bubble.message.sequence, y: rect.top);
    }
  }
  throw StateError('No complete message is visible in the timeline');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => databaseFactory = databaseFactorySqflitePlugin);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance
      ..token = 'history-test-token'
      ..profile = const SessionProfile(
        role: UserRole.admin,
        ref: 'history-test',
        displayName: 'History test',
        legalName: 'History test',
        phone: '',
        avatarUrl: '',
      );
    ChatStore.instance
      ..clearMemory()
      ..profileKey = 'admin:history-test'
      ..conversations = [_conversation];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.tekartik.sqflite'),
      (call) async => switch (call.method) {
        'getDatabasesPath' => '/chat-history-test',
        'openDatabase' => {'id': 1, 'recovered': true},
        'query' || 'batch' => <Object?>[],
        'insert' || 'update' => 1,
        _ => null,
      },
    );
  });

  tearDown(() {
    ChatStore.instance.clearMemory();
    AppSession.instance
      ..token = null
      ..profile = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('com.llfbandit.record/messages'), null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('com.tekartik.sqflite'), null);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform prepended pages preserve offset and visible bubbles',
        (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final historyCursors = <String>[];
      await _withApi(tester, (request) {
        final before = request.url.queryParameters['before_sequence'];
        if (before == null) return _page(101, 130, hasMore: true);
        historyCursors.add(before);
        return before == '101' ? _page(61, 100, hasMore: true) : _page(1, 60);
      }, () async {
        await _mount(tester, platform: platform);
        final timeline = find.byKey(const ValueKey('chat-timeline'));
        final controller =
            tester.widget<CustomScrollView>(timeline).controller!;
        expect(controller.position.extentAfter, lessThan(1));

        controller.jumpTo(240);
        await tester.pumpAndSettle();
        final initialAnchor = _visibleAnchor(tester);
        final initialOffset = controller.offset;
        expect(initialAnchor.sequence, greaterThanOrEqualTo(101));
        await ChatStore.instance
            .loadOlderMessages(_conversation.conversationId);
        await tester.pumpAndSettle();
        expect(controller.offset, closeTo(initialOffset, 0.01));
        expect(tester.getTopLeft(initialAnchor.finder).dy,
            closeTo(initialAnchor.y, 0.01));

        controller.jumpTo(-1800);
        await tester.pumpAndSettle();
        final olderAnchor = _visibleAnchor(tester);
        final olderOffset = controller.offset;
        expect(olderAnchor.sequence, inInclusiveRange(61, 100));
        await ChatStore.instance
            .loadOlderMessages(_conversation.conversationId);
        await tester.pumpAndSettle();
        expect(controller.offset, closeTo(olderOffset, 0.01));
        expect(tester.getTopLeft(olderAnchor.finder).dy,
            closeTo(olderAnchor.y, 0.01));
        expect(historyCursors, ['101', '61']);
        expect(ChatStore.instance.messagesFor(_conversation.conversationId),
            hasLength(130));
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('initial failure offers retry and never presents an empty chat',
      (tester) async {
    var fail = true;
    await _withApi(tester, (_) {
      return fail
          ? http.Response('{"error":"chat_unavailable"}', 503)
          : _page(101, 103);
    }, () async {
      await _mount(tester);
      expect(find.byKey(const ValueKey('chat-retry-messages')), findsOneWidget);
      expect(find.textContaining('Xabarlarni yuklab bo‘lmadi'), findsOneWidget);
      expect(find.text('Birinchi xabaringizni yozing.'), findsNothing);
      fail = false;
      await tester.tap(find.byKey(const ValueKey('chat-retry-messages')));
      await tester.pumpAndSettle();
      ChatStore.instance.pauseRealtime();
      expect(find.byKey(const ValueKey('chat-retry-messages')), findsNothing);
      expect(find.byKey(const ValueKey('chat-timeline')), findsOneWidget);
      expect(ChatStore.instance.messagesFor(_conversation.conversationId),
          hasLength(3));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('history loader exposes progress, failure and successful retry',
      (tester) async {
    final pending = Completer<http.Response>();
    var historyRequests = 0;
    await _withApi(tester, (request) {
      if (!request.url.queryParameters.containsKey('before_sequence')) {
        return _page(101, 130, hasMore: true);
      }
      historyRequests++;
      return historyRequests == 1 ? pending.future : _page(91, 100);
    }, () async {
      await _mount(tester);
      final timeline = find.byKey(const ValueKey('chat-timeline'));
      final controller = tester.widget<CustomScrollView>(timeline).controller!;
      controller.jumpTo(controller.position.minScrollExtent);
      await tester.pumpAndSettle();
      final loadOlder = find.byKey(const ValueKey('chat-load-older'));
      expect(loadOlder, findsOneWidget);
      await tester.tap(loadOlder);
      await tester.pump();
      await tester.pump();
      expect(
          ChatStore.instance
              .loadingOlderMessagesFor(_conversation.conversationId),
          isTrue);
      expect(loadOlder, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(http.Response('{"error":"chat_unavailable"}', 503));
      await tester.pumpAndSettle();
      expect(find.textContaining('Xabarlarni yuklab bo‘lmadi'), findsOneWidget);
      expect(loadOlder, findsOneWidget);
      expect(find.text('Qayta yuklash'), findsOneWidget);
      await tester.ensureVisible(loadOlder);
      await tester.tap(loadOlder);
      await tester.pumpAndSettle();
      expect(historyRequests, 2);
      expect(ChatStore.instance.messagesFor(_conversation.conversationId),
          hasLength(40));
      expect(find.textContaining('Xabarlarni yuklab bo‘lmadi'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('closing and reopening a conversation restores its unsent draft',
      (tester) async {
    await _withApi(tester, (_) => _page(101, 103), () async {
      await _mount(tester);
      await tester.enterText(
          find.byType(TextField), 'Unsent conversation draft');
      // Leave before the persistence debounce expires.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mount(tester);
      final input = tester.widget<TextField>(find.byType(TextField));
      expect(input.controller!.text, 'Unsent conversation draft');
      expect(tester.takeException(), isNull);
    });
  });
}
