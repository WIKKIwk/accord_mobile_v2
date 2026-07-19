import 'chat_local_database_native.dart'
    if (dart.library.js_interop) 'chat_local_database_web.dart' as platform;

void configureChatLocalDatabaseFactory() {
  platform.configureChatLocalDatabaseFactory();
}

Future<String> chatLocalDatabasePath() {
  return platform.chatLocalDatabasePath();
}
