import 'package:sqflite/sqflite.dart';

void configureChatLocalDatabaseFactory() {}

Future<String> chatLocalDatabasePath() async {
  final root = await getDatabasesPath();
  return '$root/accord_chat_v1.db';
}
