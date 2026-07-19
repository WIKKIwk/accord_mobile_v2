import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/chat_media_models.dart';
import '../models/chat_models.dart';
import 'chat_local_database.dart';

class ChatLocalStore {
  ChatLocalStore._();

  static final ChatLocalStore instance = ChatLocalStore._();
  static const int _initialCacheLimit = 100;

  Database? _database;

  Future<Database> _open() async {
    final existing = _database;
    if (existing != null) return existing;
    configureChatLocalDatabaseFactory();
    final path = await chatLocalDatabasePath();
    final database = await openDatabase(
      path,
      version: 6,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE chat_conversations (
            profile_key TEXT NOT NULL,
            conversation_id TEXT NOT NULL,
            updated_at_unix INTEGER NOT NULL,
            payload_json TEXT NOT NULL,
            PRIMARY KEY (profile_key, conversation_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE chat_messages (
            profile_key TEXT NOT NULL,
            conversation_id TEXT NOT NULL,
            message_sequence INTEGER NOT NULL,
            message_id TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            PRIMARY KEY (profile_key, conversation_id, message_sequence)
          )
        ''');
        await db.execute('''
          CREATE UNIQUE INDEX chat_messages_id_unique
          ON chat_messages(profile_key, message_id)
        ''');
        await _createPendingTable(db);
        await _createPendingMediaTable(db);
        await _createSyncStateTable(db);
        await _createReceiptTable(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) await _createPendingTable(db);
        if (oldVersion < 3) await _createPendingMediaTable(db);
        if (oldVersion >= 2 && oldVersion < 4) {
          await db.execute(
            'ALTER TABLE chat_pending_messages ADD COLUMN attempts INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE chat_pending_messages ADD COLUMN next_attempt_at_unix INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            "ALTER TABLE chat_pending_messages ADD COLUMN last_error TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 4) await _createSyncStateTable(db);
        if (oldVersion < 5) await _createReceiptTable(db);
        if (oldVersion >= 2 && oldVersion < 6) {
          await db.execute(
            'ALTER TABLE chat_pending_messages ADD COLUMN auto_retry INTEGER NOT NULL DEFAULT 1',
          );
        }
      },
    );
    _database = database;
    return database;
  }

  Future<List<ChatConversation>> loadConversations(String profileKey) async {
    final db = await _open();
    final rows = await db.query(
      'chat_conversations',
      where: 'profile_key = ?',
      whereArgs: [profileKey],
      orderBy: 'updated_at_unix DESC',
      limit: _initialCacheLimit,
    );
    return rows
        .map((row) => ChatConversation.fromJson(
              (jsonDecode(row['payload_json']! as String) as Map)
                  .cast<String, dynamic>(),
            ))
        .toList(growable: false);
  }

  Future<void> saveConversations(
    String profileKey,
    Iterable<ChatConversation> conversations,
  ) async {
    final db = await _open();
    await db.transaction((transaction) async {
      final batch = transaction.batch();
      for (final conversation in conversations) {
        batch.insert(
          'chat_conversations',
          {
            'profile_key': profileKey,
            'conversation_id': conversation.conversationId,
            'updated_at_unix': conversation.updatedAtUnix,
            'payload_json': jsonEncode(conversation.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<ChatMessage>> loadMessages(
    String profileKey,
    String conversationId,
  ) async {
    final db = await _open();
    final rows = await db.query(
      'chat_messages',
      where: 'profile_key = ? AND conversation_id = ?',
      whereArgs: [profileKey, conversationId],
      orderBy: 'message_sequence DESC',
      limit: _initialCacheLimit,
    );
    return rows.reversed
        .map((row) => ChatMessage.fromJson(
              (jsonDecode(row['payload_json']! as String) as Map)
                  .cast<String, dynamic>(),
            ))
        .toList(growable: false);
  }

  Future<void> saveMessages(
    String profileKey,
    Iterable<ChatMessage> messages,
  ) async {
    final db = await _open();
    final batch = db.batch();
    for (final message in messages) {
      batch.insert(
        'chat_messages',
        {
          'profile_key': profileKey,
          'conversation_id': message.conversationId,
          'message_sequence': message.sequence,
          'message_id': message.messageId,
          'payload_json': jsonEncode(message.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> latestMessageSequence(
    String profileKey,
    String conversationId,
  ) async {
    final db = await _open();
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(MAX(message_sequence), 0) AS latest_sequence
      FROM chat_messages
      WHERE profile_key = ? AND conversation_id = ?
      ''',
      [profileKey, conversationId],
    );
    return (rows.single['latest_sequence'] as int?) ?? 0;
  }

  Future<List<ChatPendingMessage>> loadPendingMessages(
    String profileKey, {
    String? conversationId,
  }) async {
    final db = await _open();
    final rows = await db.query(
      'chat_pending_messages',
      where: conversationId == null
          ? 'profile_key = ?'
          : 'profile_key = ? AND conversation_id = ?',
      whereArgs: [profileKey, if (conversationId != null) conversationId],
      orderBy: 'created_at_unix ASC',
    );
    return rows
        .map(
          (row) => ChatPendingMessage(
            conversationId: row['conversation_id']! as String,
            clientMessageId: row['client_message_id']! as String,
            body: row['body']! as String,
            createdAtUnix: row['created_at_unix']! as int,
            attempts: (row['attempts'] as int?) ?? 0,
            nextAttemptAtUnix: (row['next_attempt_at_unix'] as int?) ?? 0,
            lastError: (row['last_error'] as String?) ?? '',
            autoRetry: ((row['auto_retry'] as int?) ?? 1) != 0,
          ),
        )
        .toList(growable: false);
  }

  Future<void> savePendingMessage(
    String profileKey,
    ChatPendingMessage message,
  ) async {
    final db = await _open();
    await db.insert(
      'chat_pending_messages',
      {
        'profile_key': profileKey,
        'conversation_id': message.conversationId,
        'client_message_id': message.clientMessageId,
        'body': message.body,
        'created_at_unix': message.createdAtUnix,
        'attempts': message.attempts,
        'next_attempt_at_unix': message.nextAttemptAtUnix,
        'last_error': message.lastError,
        'auto_retry': message.autoRetry ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removePendingMessage(
    String profileKey,
    String clientMessageId,
  ) async {
    final db = await _open();
    await db.delete(
      'chat_pending_messages',
      where: 'profile_key = ? AND client_message_id = ?',
      whereArgs: [profileKey, clientMessageId],
    );
  }

  Future<ChatPendingMessage?> loadPendingMessage(
    String profileKey,
    String clientMessageId,
  ) async {
    final db = await _open();
    final rows = await db.query(
      'chat_pending_messages',
      where: 'profile_key = ? AND client_message_id = ?',
      whereArgs: [profileKey, clientMessageId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return ChatPendingMessage(
      conversationId: row['conversation_id']! as String,
      clientMessageId: row['client_message_id']! as String,
      body: row['body']! as String,
      createdAtUnix: row['created_at_unix']! as int,
      attempts: (row['attempts'] as int?) ?? 0,
      nextAttemptAtUnix: (row['next_attempt_at_unix'] as int?) ?? 0,
      lastError: (row['last_error'] as String?) ?? '',
      autoRetry: ((row['auto_retry'] as int?) ?? 1) != 0,
    );
  }

  Future<int> loadSyncCursor(String profileKey) async {
    final db = await _open();
    final rows = await db.query(
      'chat_sync_state',
      columns: ['event_cursor'],
      where: 'profile_key = ?',
      whereArgs: [profileKey],
      limit: 1,
    );
    return rows.isEmpty ? 0 : (rows.single['event_cursor'] as int?) ?? 0;
  }

  Future<void> saveSyncCursor(String profileKey, int cursor) async {
    final db = await _open();
    await db.insert(
      'chat_sync_state',
      {
        'profile_key': profileKey,
        'event_cursor': cursor,
        'updated_at_unix': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ChatPendingReceipt>> loadPendingReceipts(
      String profileKey) async {
    final db = await _open();
    final rows = await db.query(
      'chat_pending_receipts',
      where: 'profile_key = ?',
      whereArgs: [profileKey],
      orderBy: 'updated_at_unix ASC',
    );
    return rows
        .map(
          (row) => ChatPendingReceipt(
            conversationId: row['conversation_id']! as String,
            deliveredSequence: row['delivered_sequence']! as int,
            readSequence: row['read_sequence']! as int,
          ),
        )
        .toList(growable: false);
  }

  Future<void> savePendingReceipt(
    String profileKey,
    ChatPendingReceipt receipt,
  ) async {
    final db = await _open();
    await db.rawInsert(
      '''
      INSERT INTO chat_pending_receipts
        (profile_key, conversation_id, delivered_sequence, read_sequence, updated_at_unix)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(profile_key, conversation_id) DO UPDATE SET
        delivered_sequence = MAX(delivered_sequence, excluded.delivered_sequence),
        read_sequence = MAX(read_sequence, excluded.read_sequence),
        updated_at_unix = excluded.updated_at_unix
      ''',
      [
        profileKey,
        receipt.conversationId,
        receipt.deliveredSequence,
        receipt.readSequence,
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ],
    );
  }

  Future<void> removePendingReceipt(
    String profileKey,
    String conversationId,
  ) async {
    final db = await _open();
    await db.delete(
      'chat_pending_receipts',
      where: 'profile_key = ? AND conversation_id = ?',
      whereArgs: [profileKey, conversationId],
    );
  }

  Future<void> acknowledgePendingReceipt(
    String profileKey,
    String conversationId, {
    int deliveredSequence = 0,
    int readSequence = 0,
  }) async {
    final db = await _open();
    await db.transaction((transaction) async {
      await transaction.rawUpdate(
        '''
        UPDATE chat_pending_receipts
        SET delivered_sequence = CASE
              WHEN delivered_sequence <= ? THEN 0
              ELSE delivered_sequence
            END,
            read_sequence = CASE
              WHEN read_sequence <= ? THEN 0
              ELSE read_sequence
            END
        WHERE profile_key = ? AND conversation_id = ?
        ''',
        [deliveredSequence, readSequence, profileKey, conversationId],
      );
      await transaction.delete(
        'chat_pending_receipts',
        where: '''
          profile_key = ? AND conversation_id = ?
          AND delivered_sequence = 0 AND read_sequence = 0
        ''',
        whereArgs: [profileKey, conversationId],
      );
    });
  }

  Future<List<ChatPendingMedia>> loadPendingMedia(
    String profileKey, {
    String? conversationId,
  }) async {
    final db = await _open();
    final rows = await db.query(
      'chat_pending_media',
      where: conversationId == null
          ? 'profile_key = ?'
          : 'profile_key = ? AND conversation_id = ?',
      whereArgs: [profileKey, if (conversationId != null) conversationId],
      orderBy: 'created_at_unix ASC',
    );
    return rows
        .map(
          (row) => ChatPendingMedia.fromJson(
            (jsonDecode(row['payload_json']! as String) as Map)
                .cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }

  Future<void> savePendingMedia(
    String profileKey,
    ChatPendingMedia media,
  ) async {
    final db = await _open();
    await db.insert(
      'chat_pending_media',
      {
        'profile_key': profileKey,
        'local_id': media.localId,
        'conversation_id': media.conversationId,
        'created_at_unix': media.createdAtUnix,
        'payload_json': jsonEncode(media.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removePendingMedia(String profileKey, String localId) async {
    final db = await _open();
    await db.delete(
      'chat_pending_media',
      where: 'profile_key = ? AND local_id = ?',
      whereArgs: [profileKey, localId],
    );
  }

  Future<List<ChatPendingMedia>> clearPendingMedia(String profileKey) async {
    final pending = await loadPendingMedia(profileKey);
    final db = await _open();
    await db.delete(
      'chat_pending_media',
      where: 'profile_key = ?',
      whereArgs: [profileKey],
    );
    return pending;
  }

  static Future<void> _createPendingTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_pending_messages (
        profile_key TEXT NOT NULL,
        conversation_id TEXT NOT NULL,
        client_message_id TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at_unix INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        next_attempt_at_unix INTEGER NOT NULL DEFAULT 0,
        last_error TEXT NOT NULL DEFAULT '',
        auto_retry INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY (profile_key, client_message_id)
      )
    ''');
  }

  static Future<void> _createPendingMediaTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_pending_media (
        profile_key TEXT NOT NULL,
        local_id TEXT NOT NULL,
        conversation_id TEXT NOT NULL,
        created_at_unix INTEGER NOT NULL,
        payload_json TEXT NOT NULL,
        PRIMARY KEY (profile_key, local_id)
      )
    ''');
  }

  static Future<void> _createSyncStateTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_sync_state (
        profile_key TEXT PRIMARY KEY,
        event_cursor INTEGER NOT NULL DEFAULT 0,
        updated_at_unix INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _createReceiptTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_pending_receipts (
        profile_key TEXT NOT NULL,
        conversation_id TEXT NOT NULL,
        delivered_sequence INTEGER NOT NULL DEFAULT 0,
        read_sequence INTEGER NOT NULL DEFAULT 0,
        updated_at_unix INTEGER NOT NULL,
        PRIMARY KEY (profile_key, conversation_id)
      )
    ''');
  }
}

class ChatPendingMessage {
  const ChatPendingMessage({
    required this.conversationId,
    required this.clientMessageId,
    required this.body,
    required this.createdAtUnix,
    this.attempts = 0,
    this.nextAttemptAtUnix = 0,
    this.lastError = '',
    this.autoRetry = true,
  });

  final String conversationId;
  final String clientMessageId;
  final String body;
  final int createdAtUnix;
  final int attempts;
  final int nextAttemptAtUnix;
  final String lastError;
  final bool autoRetry;

  ChatPendingMessage copyWith({
    int? attempts,
    int? nextAttemptAtUnix,
    String? lastError,
    bool? autoRetry,
  }) {
    return ChatPendingMessage(
      conversationId: conversationId,
      clientMessageId: clientMessageId,
      body: body,
      createdAtUnix: createdAtUnix,
      attempts: attempts ?? this.attempts,
      nextAttemptAtUnix: nextAttemptAtUnix ?? this.nextAttemptAtUnix,
      lastError: lastError ?? this.lastError,
      autoRetry: autoRetry ?? this.autoRetry,
    );
  }
}

class ChatPendingReceipt {
  const ChatPendingReceipt({
    required this.conversationId,
    required this.deliveredSequence,
    required this.readSequence,
  });

  final String conversationId;
  final int deliveredSequence;
  final int readSequence;
}
