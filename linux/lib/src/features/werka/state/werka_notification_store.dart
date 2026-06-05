import '../../../core/api/mobile_api.dart';
import '../../shared/models/app_models.dart';
import 'package:flutter/foundation.dart';

class WerkaNotificationStore extends ChangeNotifier {
  WerkaNotificationStore._();

  static final WerkaNotificationStore instance = WerkaNotificationStore._();

  bool _loading = false;
  bool _loaded = false;
  Object? _error;
  List<DispatchRecord> _items = const <DispatchRecord>[];

  bool get loading => _loading;
  bool get loaded => _loaded;
  Object? get error => _error;
  List<DispatchRecord> get items => _items;

  Future<void> bootstrap({bool force = false}) async {
    if (_loading) {
      return;
    }
    if (_loaded && !force) {
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (_loading) {
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await MobileApi.instance.werkaNotifications();
      _loaded = true;
    } catch (error) {
      _error = error;
      if (!_loaded) {
        _items = const <DispatchRecord>[];
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    _loading = false;
    _loaded = false;
    _error = null;
    _items = const <DispatchRecord>[];
    notifyListeners();
  }
}
