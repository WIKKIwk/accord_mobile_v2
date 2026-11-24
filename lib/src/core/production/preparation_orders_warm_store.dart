import 'dart:async';
import 'dart:convert';

import '../../features/shared/models/app_models.dart';
import '../api/mobile_api.dart';
import '../cache/production_snapshot_store.dart';
import '../session/session_read_scope.dart';
import '../session/state/app_session.dart';

typedef PreparationOrdersWindowLoader = Future<PreparationOrderListWindow>
    Function({
  required String search,
  String? cursor,
  PreparationOrderListWindow? baseline,
  required bool refresh,
});

bool preparationOrdersWarmEnabled() {
  final session = AppSession.instance;
  return session.isLoggedIn &&
      !session.isTestModeSession &&
      session.profile?.role == UserRole.tayyorlovMasteri &&
      session.can('preparation.access');
}

/// Bounded, display-only prefixes for one preparation account. The visible
/// page confirms them through HTTP or its live subscription before details.
/// Storage and network reads are independent, so storage cannot delay a cold
/// request and a slow restore cannot replace a newer server response.
class PreparationOrdersWarmStore {
  PreparationOrdersWarmStore({
    PreparationOrdersWindowLoader? loader,
    ProductionSnapshotStore? snapshots,
  })  : _loader = loader ?? MobileApi.instance.preparationOrders,
        _snapshots = snapshots ?? ProductionSnapshotStore.instance;

  static final _instance = PreparationOrdersWarmStore();
  static PreparationOrdersWarmStore? debugOverride;
  static PreparationOrdersWarmStore get instance => debugOverride ?? _instance;

  final PreparationOrdersWindowLoader _loader;
  final ProductionSnapshotStore _snapshots;
  final _windows = <String, PreparationOrderListWindow>{};
  final _pending = <String, Future<PreparationOrderListWindow>>{};
  final _forcedReads = <String>{};
  final _restores = <String, Future<PreparationOrderListWindow?>>{};
  final _readSerials = <String, int>{};
  String? _owner;
  int _generation = 0;
  int _serverSerial = 0;
  int _nextReadSerial = 0;
  bool _prepared = false;
  bool _denied = false;

  String get _currentOwner => jsonEncode([
        currentSessionReadScope(),
        _snapshots.generation,
      ]);

  String _key(String search) => jsonEncode([
        'preparation-all-orders-v1',
        search.trim().toLowerCase(),
      ]);

  void _synchronize() {
    final owner = _currentOwner;
    if (owner == _owner) return;
    reset();
    _owner = owner;
  }

  bool _current(String owner, int generation) =>
      preparationOrdersWarmEnabled() &&
      owner == _owner &&
      owner == _currentOwner &&
      generation == _generation;

  Future<void> prepare() async {
    _synchronize();
    if (!preparationOrdersWarmEnabled() || _prepared || _denied) return;
    _prepared = true;
    try {
      // Restore labels while the single shared network request is running.
      unawaited(restore());
      await read(fresh: true);
    } catch (_) {
      // The foreground page retries optional preload failures. No timer or
      // repeated HTTP refresh is started by this store.
    }
  }

  PreparationOrderListWindow? peek({String search = ''}) {
    _synchronize();
    if (!preparationOrdersWarmEnabled() || _denied) return null;
    return _windows[_key(search)];
  }

  Future<PreparationOrderListWindow?> restore({String search = ''}) {
    _synchronize();
    if (!preparationOrdersWarmEnabled() || _denied) return Future.value();
    final ready = peek(search: search);
    if (ready != null) return Future.value(ready);
    final normalizedSearch = search.trim().toLowerCase();
    final key = _key(normalizedSearch);
    final pending = _restores[key];
    if (pending != null) return pending;
    final owner = _owner!;
    final generation = _generation;
    final serverSerial = _serverSerial;
    final scope = currentSessionReadScope();
    late final Future<PreparationOrderListWindow?> future;
    future = () async {
      final saved = await _snapshots.read(scope: scope, key: key);
      if (!_current(owner, generation) || _denied) return null;
      if (_serverSerial != serverSerial) {
        return peek(search: normalizedSearch);
      }
      if (saved == null) return null;
      try {
        if (saved['schema'] != 1 ||
            saved['search'] != normalizedSearch ||
            saved['window'] is! Map) {
          throw const FormatException();
        }
        final window = PreparationOrderListWindow.fromJson(
            (saved['window'] as Map).cast<String, dynamic>());
        if (window.search != normalizedSearch) {
          throw const FormatException();
        }
        _remember(window, search: normalizedSearch, persist: false);
        return window;
      } catch (_) {
        unawaited(_snapshots.remove(scope: scope, key: key));
        return null;
      }
    }()
        .whenComplete(() {
      if (identical(_restores[key], future)) _restores.remove(key);
    });
    _restores[key] = future;
    return future;
  }

  Future<PreparationOrderListWindow> read({
    String search = '',
    String? cursor,
    PreparationOrderListWindow? baseline,
    bool fresh = false,
    bool force = false,
  }) {
    _synchronize();
    final normalizedSearch = search.trim().toLowerCase();
    final key = _key(normalizedSearch);
    final ready = peek(search: normalizedSearch);
    if (!fresh && !force && cursor == null && ready != null) {
      return Future.value(ready);
    }
    final pendingKey = jsonEncode([key, cursor]);
    final pending = _pending[pendingKey];
    if (pending != null) {
      if (force && !_forcedReads.contains(pendingKey)) {
        return pending.then((_) => read(
            search: normalizedSearch,
            cursor: cursor,
            baseline: baseline,
            fresh: true,
            force: true));
      }
      return pending;
    }
    final owner = _owner!;
    final generation = _generation;
    final serial = ++_nextReadSerial;
    _readSerials[key] = serial;
    void requireCurrent() {
      if (!_current(owner, generation)) {
        throw const MobileApiException(
            code: 'session_changed',
            message: 'Buyurtmalar hisob doirasi o‘zgardi.');
      }
    }

    late final Future<PreparationOrderListWindow> future;
    future = () async {
      requireCurrent();
      try {
        final window = await _loader(
            search: normalizedSearch,
            cursor: cursor,
            baseline: _denied || cursor != null ? null : baseline ?? ready,
            refresh: force);
        requireCurrent();
        if (_readSerials[key] != serial) {
          final latest = peek(search: normalizedSearch);
          if (cursor == null && latest != null) return latest;
          throw const MobileApiException(
              code: 'preparation_orders_resync',
              statusCode: 409,
              message: 'Buyurtmalar o‘zgardi. Qayta yuklang.');
        }
        if (window.search != normalizedSearch) {
          throw const MobileApiException(
              code: 'preparation_orders_invalid',
              message: 'Buyurtmalar so‘rovi mos kelmadi.');
        }
        _denied = false;
        if (cursor == null) {
          _serverSerial++;
          _remember(window, search: normalizedSearch);
        }
        return window;
      } catch (error) {
        if (_current(owner, generation) &&
            error is MobileApiException &&
            (error.statusCode == 401 ||
                error.statusCode == 403 ||
                const {'unauthorized', 'forbidden'}.contains(error.code))) {
          unawaited(forget(search: normalizedSearch));
        }
        rethrow;
      }
    }()
        .whenComplete(() {
      if (identical(_pending[pendingKey], future)) {
        _pending.remove(pendingKey);
        _forcedReads.remove(pendingKey);
      }
      if (_readSerials[key] == serial) _readSerials.remove(key);
    });
    _pending[pendingKey] = future;
    if (force) _forcedReads.add(pendingKey);
    return future;
  }

  /// Remember only a contiguous prefix after the page's ownership guard has
  /// passed. Live confirmation also retires older reads for this query.
  void remember(PreparationOrderListWindow window, {String search = ''}) {
    _synchronize();
    if (!preparationOrdersWarmEnabled()) return;
    final normalizedSearch = search.trim().toLowerCase();
    final key = _key(normalizedSearch);
    final previous = _windows[key];
    if (previous?.scope == window.scope &&
        previous?.epoch == window.epoch &&
        previous!.revision > window.revision) {
      return;
    }
    _readSerials[key] = ++_nextReadSerial;
    _serverSerial++;
    _denied = false;
    _remember(window.copyWith(search: normalizedSearch),
        search: normalizedSearch);
  }

  void _remember(
    PreparationOrderListWindow window, {
    required String search,
    bool persist = true,
  }) {
    final key = _key(search);
    final previous = _windows.remove(key);
    _windows[key] = window;
    if (persist &&
        (previous?.version != window.version ||
            previous?.epoch != window.epoch ||
            previous?.scope != window.scope ||
            previous?.rows.length != window.rows.length)) {
      unawaited(_snapshots.write(
          scope: currentSessionReadScope(),
          key: key,
          value: {'schema': 1, 'search': search, 'window': window.toJson()}));
    }
    while (_windows.length > 8) {
      final oldest = _windows.keys.first;
      _windows.remove(oldest);
      _readSerials.remove(oldest);
    }
  }

  /// Withdraw all current preparation baselines after an authorization error.
  /// Disk saves queued by an older request are invalidated synchronously.
  Future<void> forget({String search = ''}) {
    _synchronize();
    final scope = currentSessionReadScope();
    final keys = {..._windows.keys, _key(search)};
    _generation++;
    _serverSerial++;
    _windows.clear();
    _pending.clear();
    _forcedReads.clear();
    _readSerials.clear();
    _restores.clear();
    _denied = true;
    return Future.wait([
      for (final key in keys) _snapshots.remove(scope: scope, key: key),
    ]).then((_) {});
  }

  void reset() {
    _generation++;
    _serverSerial++;
    _owner = null;
    _windows.clear();
    _pending.clear();
    _forcedReads.clear();
    _restores.clear();
    _readSerials.clear();
    _prepared = false;
    _denied = false;
  }
}
