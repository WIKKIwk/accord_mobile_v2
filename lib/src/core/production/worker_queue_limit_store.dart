import 'package:shared_preferences/shared_preferences.dart';

class WorkerQueueLimitStore {
  static const choices = [5, 10, 20, 50];
  static const defaultLimit = 10;

  static String _key(String account) => 'worker_queue_limit_v1:$account';

  static Future<int> load(String account) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getInt(_key(account));
    return choices.contains(saved) ? saved! : defaultLimit;
  }

  static Future<void> save(String account, int limit) async {
    if (!choices.contains(limit)) throw ArgumentError.value(limit, 'limit');
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_key(account), limit);
  }
}
