import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../features/shared/models/inventory_movement_models.dart';
import '../api/mobile_api.dart';
import '../realtime/warehouse_live_client.dart';
import '../session/session_read_scope.dart';
import '../session/state/app_session.dart';
import 'inventory_view_query.dart';

export 'inventory_view_query.dart';

typedef InventorySnapshotLoader = Future<List<Object>> Function(
    InventoryViewQuery query);
typedef InventoryLiveLoader = Stream<Map<String, dynamic>> Function(
    InventoryViewQuery query, String? version);

/// Route-independent canonical windows. Writes remain server authoritative.
/// A retained foreground stream maintains windows even with no visible page.
class InventoryViewStore {
  InventoryViewStore({
    InventorySnapshotLoader? snapshotLoader,
    InventoryLiveLoader? liveLoader,
    String Function()? scopeReader,
    String? Function()? tokenReader,
    bool Function()? liveEnabled,
    this.firstMessageTimeout = const Duration(seconds: 10),
    this.reconnectDelay,
    this.maxIdleViews = 6,
  })  : _snapshotLoader = snapshotLoader ?? _loadSnapshot,
        _liveLoader = liveLoader ?? _openLive,
        _scopeReader = scopeReader ?? currentSessionReadScope,
        _tokenReader = tokenReader ?? (() => AppSession.instance.token),
        _liveEnabled =
            liveEnabled ?? (() => !AppSession.instance.isTestModeSession);

  static final _instance = InventoryViewStore();
  static InventoryViewStore? debugOverride;
  static InventoryViewStore get instance => debugOverride ?? _instance;

  final InventorySnapshotLoader _snapshotLoader;
  final InventoryLiveLoader _liveLoader;
  final String Function() _scopeReader;
  final String? Function() _tokenReader;
  final bool Function() _liveEnabled;
  final Duration firstMessageTimeout;
  final Duration Function(int attempt)? reconnectDelay;
  final int maxIdleViews;
  final Map<String, _InventoryViewEntry<dynamic>> _entries = {};
  String? _scope;
  String? _token;
  bool _foreground = true;
  bool _blocked = false;
  int _generation = 0;
  int _visit = 0;
  Future<void>? _reconciling;

  InventoryViewLease<InventoryLocation> locations() =>
      _acquire(InventoryViewQuery.locations());

  InventoryViewLease<InventoryAsset> assets({
    String warehouseId = '',
    String query = '',
    InventoryAssetKind? assetKind,
    bool currentUserStatesOnly = false,
    bool includeOrderAssignment = true,
    int limit = 100,
    int offset = 0,
  }) =>
      _acquire(InventoryViewQuery.assets(
        warehouseId: warehouseId,
        query: query,
        assetKind: assetKind,
        currentUserStatesOnly: currentUserStatesOnly,
        includeOrderAssignment: includeOrderAssignment,
        limit: limit,
        offset: offset,
      ));

  InventoryViewLease<InventoryTransfer> transfers({
    String direction = 'all',
    InventoryTransferStatus? status,
    int limit = 100,
    int offset = 0,
  }) =>
      _acquire(InventoryViewQuery.transfers(
          direction: direction, status: status, limit: limit, offset: offset));

  InventoryViewLease<T> _acquire<T extends Object>(InventoryViewQuery query) {
    _synchronizeScope();
    var entry = _entries[query.key] as _InventoryViewEntry<T>?;
    if (entry == null) {
      entry = _InventoryViewEntry<T>(this, query, _generation);
      if (_blocked) {
        entry.error = 'Inventar ruxsatlari o‘zgardi. Hisobni yangilang.';
      }
      _entries[query.key] = entry;
    }
    entry.users++;
    entry.visit = ++_visit;
    final lease = InventoryViewLease<T>._(entry);
    _trim();
    return lease;
  }

  /// Lifecycle/account integration. Token refreshes preserve the read scope.
  void configure({required bool foreground}) {
    _foreground = foreground;
    _synchronizeScope();
    for (final entry in _entries.values.toList()) {
      if (foreground && !_blocked) {
        unawaited(entry.ensure().catchError((Object _) {}));
      } else {
        entry.stop();
      }
    }
  }

  void _synchronizeScope() {
    final current = _scopeReader();
    final token = _tokenReader();
    if (_scope != current) {
      reset();
      _scope = current;
      _token = token;
      return;
    }
    if (_token == token) return;
    _token = token;
    // A refreshed token preserves authorization scope and decoded rows, but
    // every socket must authenticate with it. Invalidate all old callbacks
    // before opening any replacement so an expiring socket cannot reset the
    // newly authenticated windows.
    final entries = _entries.values.toList();
    for (final entry in entries) {
      entry.stop();
    }
    if (_foreground && !_blocked) {
      for (final entry in entries) {
        unawaited(entry.ensure().catchError((Object _) {}));
      }
    }
  }

  void reset() {
    _generation++;
    final previous = _entries.values.toList();
    _entries.clear();
    _scope = null;
    _token = null;
    _blocked = false;
    _reconciling = null;
    for (final entry in previous) {
      entry.clear();
    }
  }

  /// Committed writes are already published as deltas. Only a read that has
  /// not established live continuity needs repair, so it cannot publish an
  /// older pre-write HTTP receipt after the write succeeds.
  Future<void> reconcileAfterWrite() {
    if (_reconciling != null) return _reconciling!;
    final pending = <Future<void>>[];
    for (final entry in _entries.values.toList()) {
      if (!entry.trusted && _current(entry)) pending.add(entry.refresh());
    }
    if (pending.isEmpty) return Future.value();
    final generation = _generation;
    return _reconciling =
        Future.wait(pending).then<void>((_) {}).whenComplete(() {
      if (generation == _generation) _reconciling = null;
    });
  }

  void _resetAuthorization() {
    _blocked = true;
    _generation++;
    for (final entry in _entries.values.toList()) {
      entry.clear(error: 'Inventar ruxsatlari o‘zgardi. Hisobni yangilang.');
    }
    _entries.clear();
  }

  bool _current(_InventoryViewEntry<dynamic> entry) =>
      entry.generation == _generation &&
      _scope == _scopeReader() &&
      _token == _tokenReader() &&
      identical(_entries[entry.query.key], entry) &&
      !_blocked;

  void _release(_InventoryViewEntry<dynamic> entry) {
    entry.users--;
    _trim();
  }

  void _trim() {
    final idle = _entries.values.where((e) => e.users == 0).toList()
      ..sort((a, b) => b.visit.compareTo(a.visit));
    final liveBuckets = _entries.values
        .where((e) => e.users > 0)
        .map((e) => e.query.liveBucket)
        .toSet();
    var retained = 0;
    for (final entry in idle) {
      if (retained >= maxIdleViews ||
          !liveBuckets.add(entry.query.liveBucket)) {
        _entries.remove(entry.query.key);
        entry.stop();
      } else {
        retained++;
      }
    }
  }

  static Stream<Map<String, dynamic>> _openLive(
      InventoryViewQuery query, String? version) {
    final base = Uri.parse(MobileApi.baseUrl);
    final uri = base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/v1/mobile/admin/inventory/live',
      queryParameters: {
        'token': MobileApi.instance.requireToken(),
        'subscriptions': jsonEncode([query.subscription(version: version)]),
      },
    );
    return connectWarehouseLive(uri);
  }

  static Future<List<Object>> _loadSnapshot(InventoryViewQuery query) async {
    final p = query.parameters;
    switch (query.kind) {
      case 'locations':
        return MobileApi.instance.inventoryLocations();
      case 'assets':
        return MobileApi.instance.inventoryAssets(
          warehouseId: p['warehouse_id'] ?? '',
          query: p['query'] ?? '',
          assetKind: p['asset_kind'] == null
              ? null
              : InventoryAssetKind.fromJson(p['asset_kind']),
          currentUserStatesOnly: p['current_user_states_only'] == 'true',
          includeOrderAssignment: p['include_order_assignment'] == 'true',
          limit: int.parse(p['limit']!),
          offset: int.tryParse(p['offset'] ?? '') ?? 0,
        );
      case 'transfers':
        return MobileApi.instance.inventoryTransfers(
          direction: p['direction']!,
          status: p['status'] == null
              ? null
              : InventoryTransferStatus.fromJson(p['status']),
          limit: int.parse(p['limit']!),
          offset: int.tryParse(p['offset'] ?? '') ?? 0,
        );
      default:
        throw StateError('Unknown inventory view');
    }
  }
}

/// A page owns only its listener; disposing keeps the trusted shared window.
class InventoryViewLease<T extends Object> implements Listenable {
  InventoryViewLease._(this._entry) : _ready = _entry.ensure() {
    // Pages may attach before awaiting. Keep an unobserved failed preparation
    // from escaping while retaining the same error for callers of ready.
    unawaited(_ready.catchError((Object _) {}));
  }
  final _InventoryViewEntry<T> _entry;
  final Future<void> _ready;
  final Set<VoidCallback> _listeners = {};
  bool _disposed = false;

  List<T>? get rows => _entry.rows;
  bool get loading => _entry.loading;
  String? get error => _entry.error;
  bool get trusted => _entry.trusted;
  Future<void> get ready => _ready;

  /// Explicit user refresh or compatibility repair; normal writes use deltas.
  Future<void> refresh() => _entry.refresh();

  @override
  void addListener(VoidCallback listener) {
    if (_disposed || !_listeners.add(listener)) return;
    _entry.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_listeners.remove(listener)) _entry.removeListener(listener);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final listener in _listeners) {
      _entry.removeListener(listener);
    }
    _listeners.clear();
    _entry.store._release(_entry);
  }
}

class _InventoryViewEntry<T extends Object> extends ChangeNotifier {
  _InventoryViewEntry(this.store, this.query, this.generation);
  final InventoryViewStore store;
  final InventoryViewQuery query;
  final int generation;
  int users = 0;
  int visit = 0;
  List<T>? rows;
  bool loading = false;
  bool trusted = false;
  String? error;
  String? _version;
  String? _epoch;
  int? _revision;
  int _connection = 0;
  int _attempt = 0;
  bool _fallbackRead = false;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _timeout;
  Timer? _heartbeat;
  Timer? _retry;
  Completer<void>? _preparing;

  bool get _current => store._current(this);
  bool get _canConnect => _current && store._foreground;

  Future<void> ensure() {
    if (!_current) return Future.value();
    if (trusted && _subscription != null) return Future.value();
    if (_preparing != null) return _preparing!.future;
    if (!_canConnect) return Future.value();
    _stopSocket();
    _fallbackRead = false;
    _preparing = Completer<void>();
    loading = rows == null;
    error = null;
    notifyListeners();
    if (store._liveEnabled()) {
      _connect();
    } else {
      unawaited(_fallback());
    }
    return _preparing?.future ?? Future.value();
  }

  Future<void> refresh() {
    if (!_current) return Future.value();
    stop();
    _fallbackRead = false;
    return ensure();
  }

  void _connect() {
    if (!_canConnect) return;
    _retry?.cancel();
    _retry = null;
    final connection = ++_connection;
    _timeout = Timer(store.firstMessageTimeout, () {
      if (connection == _connection) _lost();
    });
    try {
      _subscription = store._liveLoader(query, _version).listen(
        (message) {
          if (connection != _connection || !_current) return;
          try {
            _receive(message);
          } catch (_) {
            // Any malformed/gapped patch leaves the previous canonical window
            // intact and asks the server to validate/replace that baseline.
            _lost();
          }
        },
        onError: (Object _, StackTrace __) {
          if (connection == _connection) _lost();
        },
        onDone: () {
          if (connection == _connection) _lost();
        },
      );
    } catch (_) {
      _lost();
    }
  }

  void _receive(Map<String, dynamic> message) {
    final event = message['event'];
    if (event == 'inventory.reset') {
      store._resetAuthorization();
      return;
    }
    if (event == 'inventory.error') {
      throw const FormatException('Inventory live rejected');
    }
    if (event == 'inventory.heartbeat') {
      if (message['epoch'] == _epoch && trusted) _armHeartbeat();
      return;
    }
    if (message['id'] != 'window') return;
    final epoch = message['epoch'];
    final revision = message['revision'];
    final version = message['version'];
    if (epoch is! String ||
        epoch.isEmpty ||
        revision is! int ||
        revision < 0 ||
        version is! String ||
        version.isEmpty) {
      throw const FormatException('Invalid inventory revision');
    }
    switch (event) {
      case 'inventory.snapshot':
        final next = _decodeRows(message['rows']);
        _validateUnique(next);
        rows = List.unmodifiable(next);
      case 'inventory.ready':
        if (rows == null || version != _version) {
          throw const FormatException('Unknown inventory baseline');
        }
      case 'inventory.delta':
        if (trusted && epoch == _epoch && revision <= _revision!) return;
        if (rows == null ||
            !trusted ||
            epoch != _epoch ||
            message['base_revision'] != _revision ||
            revision != (_revision! + 1)) {
          throw const FormatException('Inventory delta revision gap');
        }
        final next = {for (final row in rows!) query.rowKey(row): row};
        for (final key in _keys(message['removed'])) {
          if (!next.containsKey(key)) {
            throw const FormatException('Unknown removed inventory row');
          }
          next.remove(key);
        }
        final upserts = _decodeRows(message['upserts']);
        _validateUnique(upserts);
        for (final row in upserts) {
          next[query.rowKey(row)] = row;
        }
        final order = _keys(message['order']);
        if (order.length != next.length ||
            order.toSet().length != order.length ||
            order.any((key) => !next.containsKey(key))) {
          throw const FormatException('Invalid inventory window order');
        }
        rows = List.unmodifiable(order.map((key) => next[key]!));
      default:
        return;
    }
    _epoch = epoch;
    _revision = revision;
    _version = version;
    trusted = true;
    loading = false;
    error = null;
    _attempt = 0;
    _fallbackRead = false;
    _timeout?.cancel();
    _timeout = null;
    _armHeartbeat();
    _complete();
    notifyListeners();
  }

  void _armHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer(const Duration(seconds: 55), _lost);
  }

  List<T> _decodeRows(Object? raw) {
    if (raw is! List) throw const FormatException('Expected inventory rows');
    return raw.map((row) {
      if (row is! Map) throw const FormatException('Invalid inventory row');
      return query.decode(row.cast<String, dynamic>()) as T;
    }).toList(growable: false);
  }

  void _validateUnique(List<T> values) {
    final keys = values.map(query.rowKey).toSet();
    if (keys.length != values.length || keys.any((key) => key.isEmpty)) {
      throw const FormatException('Duplicate inventory rows');
    }
  }

  List<String> _keys(Object? raw) {
    if (raw is! List || raw.any((key) => key is! String || key.isEmpty)) {
      throw const FormatException('Invalid inventory keys');
    }
    return raw.cast<String>();
  }

  void _lost() {
    _stopSocket();
    if (!_current) return;
    trusted = false;
    loading = rows == null;
    notifyListeners();
    // Compatibility with an older backend: one HTTP read per visit/explicit
    // refresh. Reconnection retries never turn into repeated list downloads.
    if (!_fallbackRead) {
      unawaited(_fallback());
    } else {
      _scheduleReconnect();
    }
  }

  Future<void> _fallback() async {
    if (!_current || _fallbackRead) return;
    _fallbackRead = true;
    final connection = _connection;
    try {
      final loaded = (await store._snapshotLoader(query)).cast<T>();
      if (!_current || connection != _connection) return;
      _validateUnique(loaded);
      rows = List.unmodifiable(loaded);
      _version = null;
      error = null;
      loading = false;
      _complete();
    } catch (failure, stack) {
      if (!_current || connection != _connection) return;
      if (failure is MobileApiException &&
          (failure.statusCode == 401 || failure.statusCode == 403)) {
        store._resetAuthorization();
        return;
      }
      error = failure.toString();
      loading = false;
      _complete(rows == null ? failure : null, stack);
    }
    if (!_current) return;
    notifyListeners();
    if (store._liveEnabled()) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_canConnect || _retry != null) return;
    final attempt = _attempt++;
    final delay = store.reconnectDelay?.call(attempt) ??
        Duration(milliseconds: min(30000, 1000 * (1 << min(attempt, 5))));
    _retry = Timer(delay, () {
      _retry = null;
      if (_canConnect) _connect();
    });
  }

  void _complete([Object? failure, StackTrace? stack]) {
    final preparing = _preparing;
    _preparing = null;
    if (preparing == null || preparing.isCompleted) return;
    if (failure != null) {
      preparing.completeError(failure, stack);
    } else {
      preparing.complete();
    }
  }

  void _stopSocket() {
    _connection++;
    _timeout?.cancel();
    _timeout = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    final previous = _subscription;
    _subscription = null;
    unawaited(previous?.cancel());
  }

  void stop() {
    _retry?.cancel();
    _retry = null;
    _stopSocket();
    trusted = false;
    _complete();
    loading = false;
  }

  void clear({String? error}) {
    stop();
    rows = null;
    _version = null;
    _epoch = null;
    _revision = null;
    this.error = error;
    notifyListeners();
  }
}
