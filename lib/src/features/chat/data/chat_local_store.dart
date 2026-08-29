import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/chat_media_models.dart';
import '../models/chat_models.dart';
import 'chat_local_database.dart';

part 'chat_local_store_ChatLocalStore_methods_01.dart';
part 'chat_local_store_declarations_part_01.dart';

class ChatLocalStore {
  ChatLocalStore._();

  static final ChatLocalStore instance = ChatLocalStore._();
  static const int _initialCacheLimit = 100;

  Database? _database;

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
