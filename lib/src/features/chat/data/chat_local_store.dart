import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/chat_media_models.dart';
import '../models/chat_models.dart';

class ChatLocalStore {
  ChatLocalStore._();

  static final ChatLocalStore instance = ChatLocalStore._();
  static const int _initialCacheLimit = 100;

  Database? _database;

  Future<Database> _open() async {
    final existing = _database;
    if (existing != null) return existing;
    final root = await getDatabasesPath();
    final database = await openDatabase(
      '$root/accord_chat_v1.db',
      version: 3,
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
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) await _createPendingTable(db);
        if (oldVersion < 3) await _createPendingMediaTable(db);
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
        'created_at_unix': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
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
}

class ChatPendingMessage {
  const ChatPendingMessage({
    required this.conversationId,
    required this.clientMessageId,
    required this.body,
  });

  final String conversationId;
  final String clientMessageId;
  final String body;
}
