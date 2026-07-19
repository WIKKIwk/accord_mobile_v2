@TestOn('browser')
library;

import 'package:accord_mobile_v2/src/features/chat/data/chat_local_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('web chat reliability state is persisted in sqlite wasm', () async {
    final profileKey =
        'web-test-${DateTime.now().microsecondsSinceEpoch.toString()}';
    const conversationId = 'conversation-web-test';
    const clientMessageId = 'client-message-web-test';
    final store = ChatLocalStore.instance;

    await store.savePendingMessage(
      profileKey,
      const ChatPendingMessage(
        conversationId: conversationId,
        clientMessageId: clientMessageId,
        body: 'web pending message',
        createdAtUnix: 1,
      ),
    );
    final pending = await store.loadPendingMessage(
      profileKey,
      clientMessageId,
    );
    expect(pending?.body, 'web pending message');

    await store.saveSyncCursor(profileKey, 42);
    expect(await store.loadSyncCursor(profileKey), 42);

    await store.savePendingReceipt(
      profileKey,
      const ChatPendingReceipt(
        conversationId: conversationId,
        deliveredSequence: 7,
        readSequence: 5,
      ),
    );
    final receipts = await store.loadPendingReceipts(profileKey);
    expect(receipts, hasLength(1));
    expect(receipts.single.deliveredSequence, 7);
    expect(receipts.single.readSequence, 5);

    await store.removePendingMessage(profileKey, clientMessageId);
    await store.removePendingReceipt(profileKey, conversationId);
  });
}
