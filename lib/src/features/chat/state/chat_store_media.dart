part of 'chat_store.dart';

const Duration _mediaStatusPollInterval = Duration(seconds: 1);
const int _mediaStatusPollLimit = 3600;

extension ChatStoreMedia on ChatStore {}
