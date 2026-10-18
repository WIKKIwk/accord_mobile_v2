import 'dart:convert';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/chat/models/chat_models.dart';
import 'package:accord_mobile_v2/src/features/chat/presentation/chat_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/chat/state/chat_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

const _conversation = ChatConversation(
  conversationId: 'scroll-regression',
  kind: 'dm',
  title: 'Scroll regression',
  peer: null,
  lastMessage: null,
  lastMessageSequence: 80,
  unreadCount: 0,
  updatedAtUnix: 1700000000,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => databaseFactory = databaseFactorySqflitePlugin);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance
      ..token = 'scroll-test-token'
      ..profile = const SessionProfile(
        role: UserRole.admin,
        ref: 'scroll-test',
        displayName: 'Scroll test',
        legalName: 'Scroll test',
        phone: '',
        avatarUrl: '',
      );
    ChatStore.instance
      ..clearMemory()
      ..profileKey = 'admin:scroll-test'
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
        'getDatabasesPath' => '/chat-test',
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
    testWidgets('$platform chat keeps scrolling through repeated touch moves',
        (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      var messageCount = 80;

      Future<void> receiveMessage() async {
        messageCount++;
        await ChatStore.instance.loadMessages(_conversation.conversationId);
        ChatStore.instance.pauseRealtime();
      }

      await http.runWithClient(
        () async {
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
          expect(ChatStore.instance.messagesFor(_conversation.conversationId),
              hasLength(80));
          ChatStore.instance.pauseRealtime();

          final list = find.byKey(const ValueKey('chat-timeline'));
          final controller = tester.widget<CustomScrollView>(list).controller!;
          expect(controller.position.extentAfter, lessThan(1));

          final bottom = controller.offset;
          final shortSwipe = await tester.startGesture(tester.getCenter(list));
          await shortSwipe.moveBy(const Offset(0, 24));
          await tester.pump();
          await shortSwipe.moveBy(const Offset(0, 8));
          await tester.pump();
          await shortSwipe.moveBy(const Offset(0, 8));
          await tester.pump(const Duration(milliseconds: 100));
          await shortSwipe.up();
          await tester.pumpAndSettle();
          expect(controller.offset, lessThan(bottom - 5),
              reason: 'A short completed swipe must not snap back to bottom');

          controller.jumpTo(controller.position.maxScrollExtent);
          await tester.pumpAndSettle();
          await receiveMessage();
          await tester.pumpAndSettle();
          expect(controller.position.extentAfter, lessThan(1),
              reason: 'An idle chat at bottom follows new messages');
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          await tester.pumpAndSettle();
          expect(controller.position.extentAfter, lessThan(1),
              reason: 'Opening the keyboard keeps an idle chat at bottom');

          for (var swipe = 0; swipe < 3; swipe++) {
            final gesture = await tester.startGesture(tester.getCenter(list));
            // Cross touch slop, then move in small increments as on a phone.
            await gesture.moveBy(const Offset(0, 24));
            await tester.pump();
            await gesture.moveBy(const Offset(0, 8));
            await tester.pump();
            await tester.pump();
            for (var move = 0; move < 10; move++) {
              final before = controller.offset;
              if (swipe == 1 && move == 1) {
                await receiveMessage();
                await tester.pump();
                await tester.pump();
                expect(controller.offset, closeTo(before, 0.5),
                    reason: 'An incoming message must not interrupt a drag');
              }
              await gesture.moveBy(const Offset(0, 8));
              if (swipe == 0 && move == 1) {
                tester.view.viewInsets = const FakeViewPadding();
              }
              await tester.pump();
              // Metrics notifications schedule their correction on a later frame.
              await tester.pump();
              expect(
                controller.offset,
                lessThan(before - 4),
                reason:
                    'Swipe $swipe, move $move must keep the touch drag alive',
              );
            }
            await gesture.up();
            await tester.pumpAndSettle();
          }

          final historyOffset = controller.offset;
          await receiveMessage();
          await tester.pumpAndSettle();
          expect(controller.offset, closeTo(historyOffset, 0.5),
              reason:
                  'Incoming messages preserve the history reading position');
          expect(find.byTooltip('2 ta yangi xabar'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('chat-jump-to-latest')));
          await tester.pumpAndSettle();
          expect(controller.position.extentAfter, lessThan(1));
          expect(
              find.byKey(const ValueKey('chat-jump-to-latest')), findsNothing);
          AppSession.instance.profile = null;
          AppSession.instance.revision.value++;
          await tester.pumpAndSettle();
          expect(find.text('Hisob o‘zgardi. Chatni qayta oching.'),
              findsOneWidget);
          expect(find.byType(TextField), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          ChatStore.instance.clearMemory();
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('/socket-ticket')) {
            return http.Response('{"error":"offline"}', 503);
          }
          if (request.url.path.endsWith('/messages')) {
            return http.Response(
              jsonEncode({
                'items': List.generate(
                  messageCount,
                  (index) => {
                    'message_id': 'message-$index',
                    'conversation_id': _conversation.conversationId,
                    'sender_principal_id': 'peer',
                    'sender_role': 'admin',
                    'sender_ref': 'peer',
                    'sender_display_name': 'Peer',
                    'client_message_id': 'client-$index',
                    'sequence': index + 1,
                    'type': 'text',
                    'body': 'Message $index ${'line\n' * (index % 4)}',
                    'created_at_unix': 1700000000 + index,
                  },
                ),
                'has_more': false,
              }),
              200,
            );
          }
          return http.Response('{"events":[],"has_more":false}', 200);
        }),
      );
    });
  }
}
