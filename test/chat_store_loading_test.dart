import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/chat/models/chat_models.dart';
import 'package:accord_mobile_v2/src/features/chat/state/chat_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

const _conversationId = 'loading-regression';
const _conversation = ChatConversation(
  conversationId: _conversationId,
  kind: 'dm',
  title: 'Loading regression',
  peer: null,
  lastMessage: null,
  lastMessageSequence: 20,
  unreadCount: 0,
  updatedAtUnix: 1700000000,
);

void _setSession([String ref = 'loading-test']) {
  AppSession.instance
    ..token = 'token-$ref'
    ..profile = SessionProfile(
      role: UserRole.admin,
      ref: ref,
      displayName: ref,
      legalName: ref,
      phone: '',
      avatarUrl: '',
    );
  ChatStore.instance
    ..clearMemory()
    ..profileKey = 'admin:$ref'
    ..conversations = [_conversation];
}

http.Response _messages(List<int> sequences, {bool hasMore = false}) {
  return http.Response(
    jsonEncode({
      'items': [
        for (final sequence in sequences)
          {
            'message_id': 'message-$sequence',
            'conversation_id': _conversationId,
            'sender_principal_id': 'peer',
            'sender_role': 'admin',
            'sender_ref': 'peer',
            'sender_display_name': 'Peer',
            'client_message_id': 'client-$sequence',
            'sequence': sequence,
            'type': 'text',
            'body': 'Message $sequence',
            'created_at_unix': 1700000000 + sequence,
          },
      ],
      'has_more': hasMore,
    }),
    200,
  );
}

http.Response _directory(String name) => http.Response(
      jsonEncode({
        'items': [
          {'role': 'admin', 'ref': name, 'display_name': name},
        ],
      }),
      200,
    );

Future<void> _withApi(
  FutureOr<http.Response> Function(http.Request) handler,
  Future<void> Function() body,
) async {
  await http.runWithClient(
    () async {
      try {
        await body();
      } finally {
        ChatStore.instance.clearMemory();
        // Receipt/outbox work is intentionally fire-and-forget in the store.
        // Let its platform futures finish while the mocks are still installed.
        await Future<void>.delayed(Duration.zero);
      }
    },
    () => MockClient((request) async {
      if (request.url.path.endsWith('/socket-ticket')) {
        return http.Response('{"error":"offline"}', 503);
      }
      if (request.url.path.endsWith('/messages') ||
          request.url.path.endsWith('/directory')) {
        return handler(request);
      }
      return http.Response('{"events":[],"items":[],"has_more":false}', 200);
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => databaseFactory = databaseFactorySqflitePlugin);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _setSession();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.tekartik.sqflite'),
      (call) async => switch (call.method) {
        'getDatabasesPath' => '/chat-loading-test',
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.tekartik.sqflite'), null);
  });

  test('concurrent initial loads share completion and one HTTP request',
      () async {
    final response = Completer<http.Response>();
    final requested = Completer<void>();
    var requestCount = 0;
    await _withApi((_) {
      requestCount++;
      requested.complete();
      return response.future;
    }, () async {
      final store = ChatStore.instance;
      final first = store.loadMessages(_conversationId);
      final second = store.loadMessages(_conversationId);
      expect(identical(first, second), isTrue);
      expect(store.loadingMessagesFor(_conversationId), isTrue);
      await requested.future;
      expect(requestCount, 1);
      response.complete(_messages([10, 11], hasMore: true));
      await Future.wait([first, second]);
      expect(store.messagesFor(_conversationId).map((item) => item.sequence),
          [10, 11]);
      expect(store.loadingMessagesFor(_conversationId), isFalse);
      expect(store.messageErrorFor(_conversationId), isEmpty);
    });
  });

  test('initial load errors stay in their conversation and clear on retry',
      () async {
    var fail = true;
    await _withApi((_) {
      return fail
          ? http.Response('{"error":"chat_unavailable"}', 503)
          : _messages([10]);
    }, () async {
      final store = ChatStore.instance;
      await store.loadMessages(_conversationId);
      expect(store.messageErrorFor(_conversationId), isNotEmpty);
      expect(store.messageErrorFor('other-conversation'), isEmpty);
      expect(store.loadingMessagesFor(_conversationId), isFalse);
      fail = false;
      final retry = store.loadMessages(_conversationId);
      expect(store.messageErrorFor(_conversationId), isEmpty);
      await retry;
      expect(store.messagesFor(_conversationId), hasLength(1));
    });
  });

  test('history loads deduplicate and retain messages received while loading',
      () async {
    final historyResponse = Completer<http.Response>();
    final historyRequested = Completer<void>();
    var newest = 11;
    var historyRequests = 0;
    await _withApi((request) {
      if (request.url.queryParameters.containsKey('before_sequence')) {
        expect(request.url.queryParameters['before_sequence'], '10');
        historyRequests++;
        historyRequested.complete();
        return historyResponse.future;
      }
      return _messages([10, newest], hasMore: true);
    }, () async {
      final store = ChatStore.instance;
      await store.loadMessages(_conversationId);
      final first = store.loadOlderMessages(_conversationId);
      final second = store.loadOlderMessages(_conversationId);
      expect(identical(first, second), isTrue);
      expect(store.loadingOlderMessagesFor(_conversationId), isTrue);
      await historyRequested.future;
      newest = 12;
      await store.loadMessages(_conversationId);
      historyResponse.complete(_messages([8, 9]));
      await Future.wait([first, second]);
      expect(historyRequests, 1);
      expect(store.messagesFor(_conversationId).map((item) => item.sequence),
          [8, 9, 10, 11, 12]);
      expect(store.loadingOlderMessagesFor(_conversationId), isFalse);
      expect(store.hasMoreMessages(_conversationId), isFalse);
      await store.loadMessages(_conversationId);
      expect(store.hasMoreMessages(_conversationId), isFalse,
          reason: 'Refreshing newest messages must retain exhausted history');
    });
  });

  test('history failure preserves messages and allows retry at the same cursor',
      () async {
    var fail = true;
    final cursors = <String?>[];
    await _withApi((request) {
      if (!request.url.queryParameters.containsKey('before_sequence')) {
        return _messages([10, 11], hasMore: true);
      }
      cursors.add(request.url.queryParameters['before_sequence']);
      return fail
          ? http.Response('{"error":"chat_unavailable"}', 503)
          : _messages([8, 9]);
    }, () async {
      final store = ChatStore.instance;
      await store.loadMessages(_conversationId);
      await store.loadOlderMessages(_conversationId);
      expect(store.olderMessagesErrorFor(_conversationId), isNotEmpty);
      expect(store.olderMessagesErrorFor('other-conversation'), isEmpty);
      expect(store.messageErrorFor(_conversationId), isEmpty);
      expect(store.loadingOlderMessagesFor(_conversationId), isFalse);
      expect(store.messagesFor(_conversationId), hasLength(2));
      expect(store.hasMoreMessages(_conversationId), isTrue);
      fail = false;
      final retry = store.loadOlderMessages(_conversationId);
      expect(store.olderMessagesErrorFor(_conversationId), isEmpty);
      await retry;
      expect(cursors, ['10', '10']);
      expect(store.messagesFor(_conversationId), hasLength(4));
    });
  });

  test('older directory responses and failures cannot replace a newer search',
      () async {
    final staleResponse = Completer<http.Response>();
    final freshResponse = Completer<http.Response>();
    await _withApi((request) {
      return request.url.queryParameters['q'] == 'stale'
          ? staleResponse.future
          : freshResponse.future;
    }, () async {
      final store = ChatStore.instance;
      final stale = store.searchDirectory('stale');
      final fresh = store.searchDirectory('fresh');
      staleResponse.complete(http.Response('{"error":"offline"}', 503));
      await stale;
      expect(store.loadingDirectory, isTrue);
      expect(store.error, isEmpty);
      freshResponse.complete(_directory('Fresh result'));
      await fresh;
      expect(store.directory.single.displayName, 'Fresh result');
      expect(store.loadingDirectory, isFalse);
    });
  });

  test('a late directory result cannot replace the completed latest search',
      () async {
    final staleResponse = Completer<http.Response>();
    await _withApi((request) {
      return request.url.queryParameters['q'] == 'stale'
          ? staleResponse.future
          : _directory('Fresh result');
    }, () async {
      final store = ChatStore.instance;
      final stale = store.searchDirectory('stale');
      await store.searchDirectory('fresh');
      staleResponse.complete(_directory('Stale result'));
      await stale;
      expect(store.directory.single.displayName, 'Fresh result');
    });
  });

  test('a previous session cannot overwrite messages or clear a current load',
      () async {
    final oldResponse = Completer<http.Response>();
    final oldRequested = Completer<void>();
    final newResponse = Completer<http.Response>();
    final newRequested = Completer<void>();
    var requests = 0;
    await _withApi((_) {
      requests++;
      if (requests == 1) {
        oldRequested.complete();
        return oldResponse.future;
      }
      newRequested.complete();
      return newResponse.future;
    }, () async {
      final store = ChatStore.instance;
      final oldLoad = store.loadMessages(_conversationId);
      await oldRequested.future;
      // The same account can log out and in while an earlier request is pending.
      _setSession();
      final newLoad = store.loadMessages(_conversationId);
      await newRequested.future;
      oldResponse.complete(_messages([1, 2]));
      await oldLoad;
      expect(store.messagesFor(_conversationId), isEmpty);
      expect(store.loadingMessagesFor(_conversationId), isTrue);
      newResponse.complete(_messages([10, 11]));
      await newLoad;
      expect(store.messagesFor(_conversationId).map((item) => item.sequence),
          [10, 11]);
      expect(store.loadingMessagesFor(_conversationId), isFalse);
    });
  });

  test('account switch discards history errors and stale directory results',
      () async {
    final historyResponse = Completer<http.Response>();
    final directoryResponse = Completer<http.Response>();
    await _withApi((request) {
      if (request.url.path.endsWith('/directory')) {
        return directoryResponse.future;
      }
      if (request.url.queryParameters.containsKey('before_sequence')) {
        return historyResponse.future;
      }
      return _messages([10], hasMore: true);
    }, () async {
      final store = ChatStore.instance;
      await store.loadMessages(_conversationId);
      final history = store.loadOlderMessages(_conversationId);
      final search = store.searchDirectory('old account');
      _setSession('other-account');
      historyResponse.complete(http.Response('{"error":"offline"}', 503));
      directoryResponse.complete(_directory('Old account result'));
      await Future.wait([history, search]);
      expect(store.messagesFor(_conversationId), isEmpty);
      expect(store.olderMessagesErrorFor(_conversationId), isEmpty);
      expect(store.directory, isEmpty);
      expect(store.loadingOlderMessagesFor(_conversationId), isFalse);
      expect(store.loadingDirectory, isFalse);
    });
  });
}
