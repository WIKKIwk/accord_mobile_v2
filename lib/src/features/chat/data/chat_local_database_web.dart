import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void configureChatLocalDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWeb;
}

Future<String> chatLocalDatabasePath() async => 'accord_chat_v1.db';
