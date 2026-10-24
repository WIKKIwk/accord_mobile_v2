import 'dart:async';
import 'dart:convert';

import '../../features/admin/state/admin_sequence_apparatus_store.dart';
import '../../features/shared/models/app_models.dart';
import '../api/mobile_api.dart';
import '../cache/production_snapshot_store.dart';
import '../session/session_read_scope.dart';
import '../session/state/app_session.dart';

/// Only these roles use the compact tasks contract. No queue write authority.
String? supplyTasksRoleKind() {
  final session = AppSession.instance;
  if (!session.isLoggedIn || session.isTestModeSession) return null;
  if (session.profile?.role == UserRole.materialTaminotchi &&
      session.can('raw_material.assign')) {
    return 'material';
  }
  if (session.profile?.role == UserRole.qolipchi &&
      session.can('qolip.manage')) {
    return 'qolip';
  }
  return null;
}

/// Compact display baselines only. The visible page owns all live validation.
/// Preparation performs at most one read per role/session; it opens no socket,
/// image, detail, timer or periodic refresh.
class SupplyTasksWarmStore {
  SupplyTasksWarmStore(
      {SupplyTaskWindowLoader? loader,
      ProductionSnapshotStore? snapshots,
      Future<String?> Function()? selectionLoader})
      : _loader = loader ?? MobileApi.instance.supplyTaskWindow,
        _snapshots = snapshots ?? ProductionSnapshotStore.instance,
        _selectionLoader = selectionLoader ??
            AdminSequenceApparatusStore.instance.loadSavedApparatusId;

  static final instance = SupplyTasksWarmStore();
  final SupplyTaskWindowLoader _loader;
  final ProductionSnapshotStore _snapshots;
  final Future<String?> Function() _selectionLoader;
  final _windows = <String, SupplyTaskWindow>{};
  final _pending = <String, Future<SupplyTaskWindow>>{};
  final _readSerials = <String, int>{};
  final _prepared = <String>{};
  final _deniedKinds = <String>{};
  String? _owner;
  int _generation = 0;

  String get _currentOwner => jsonEncode([
        currentSessionReadScope(),
        AppSession.instance.revision.value,
        AppSession.instance.token,
        _snapshots.generation
      ]);

  void _synchronize() {
    final owner = _currentOwner;
    if (_owner == owner) return;
    reset();
    _owner = owner;
  }

  bool _isCurrent(String owner, int generation) =>
      owner == _owner && owner == _currentOwner && generation == _generation;

  String _key(String kind, String apparatus, int limit, String search) =>
      jsonEncode([
        'supply-tasks-v1',
        kind,
        apparatus,
        limit,
        search.trim().toLowerCase()
      ]);

  Future<void> prepare({required String kind}) async {
    _synchronize();
    if (supplyTasksRoleKind() != kind || !_prepared.add(kind)) return;
    final owner = _owner!;
    final generation = _generation;
    try {
      final saved = await _selectionLoader();
      if (!_isCurrent(owner, generation)) return;
      await read(kind: kind, apparatus: saved ?? '', limit: 10, search: '');
    } catch (_) {
      // A failed optional preload is retried by the page, not a background loop.
    }
  }

  SupplyTaskWindow? peek({required String scope, required String kind}) {
    _synchronize();
    if (scope != currentSessionReadScope()) return null;
    for (final window in _windows.values.toList().reversed) {
      if (window.kind == kind && window.limit == 10 && window.search.isEmpty) {
        return window;
      }
    }
    return null;
  }

  Future<SupplyTaskWindow> read(
      {required String kind,
      required String apparatus,
      required int limit,
      required String search,
      bool fresh = false}) {
    _synchronize();
    final normalizedSearch = search.trim().toLowerCase();
    final key = _key(kind, apparatus, limit, normalizedSearch);
    final skipCache = fresh || _deniedKinds.contains(kind);
    if (!skipCache && _windows[key] != null) return Future.value(_windows[key]);
    final pendingKey = '$key:$fresh';
    final existing = _pending[pendingKey];
    if (existing != null) return existing;
    final owner = _owner!;
    final scope = currentSessionReadScope();
    final generation = _generation;
    final serial = (_readSerials[key] ?? 0) + 1;
    _readSerials[key] = serial;
    bool current() =>
        _isCurrent(owner, generation) && _readSerials[key] == serial;
    void requireCurrent() {
      if (!current()) {
        throw const MobileApiException(
            code: 'session_changed',
            message: 'Vazifalar hisob doirasi o‘zgardi.');
      }
    }

    late final Future<SupplyTaskWindow> future;
    future = () async {
      try {
        if (!skipCache) {
          final saved = await _snapshots.read(scope: scope, key: key);
          requireCurrent();
          if (saved != null) {
            try {
              final raw = saved['window'];
              if (saved['schema'] != 1 || raw is! Map) {
                throw const FormatException();
              }
              final window =
                  SupplyTaskWindow.fromJson(raw.cast<String, dynamic>());
              if (window.kind != kind ||
                  window.limit != limit ||
                  window.search != normalizedSearch) {
                throw const FormatException();
              }
              _remember(window, aliases: [key]);
              return window;
            } catch (_) {
              unawaited(_snapshots.remove(scope: scope, key: key));
            }
          }
        }
        requireCurrent();
        final window = await _loader(
            kind: kind,
            apparatus: apparatus,
            limit: limit,
            search: normalizedSearch);
        requireCurrent();
        if (window.kind != kind ||
            window.limit != limit ||
            window.search != normalizedSearch) {
          throw const MobileApiException(
              code: 'supply_tasks_invalid',
              message: 'Vazifalar so‘rovi mos kelmadi.');
        }
        _remember(window, aliases: [key]);
        return window;
      } catch (error) {
        if (current() &&
            error is MobileApiException &&
            (error.statusCode == 401 ||
                error.statusCode == 403 ||
                const {'unauthorized', 'forbidden'}.contains(error.code))) {
          _forgetKind(kind, scope, key);
        }
        rethrow;
      }
    }()
        .whenComplete(() {
      if (identical(_pending[pendingKey], future)) _pending.remove(pendingKey);
    });
    _pending[pendingKey] = future;
    return future;
  }

  void remember(SupplyTaskWindow window) {
    _synchronize();
    _remember(window);
  }

  /// A live authorization error withdraws saved baselines as well as the UI.
  void invalidate({required String kind}) {
    _synchronize();
    _forgetKind(kind, currentSessionReadScope(), _key(kind, '', 10, ''));
  }

  void _remember(SupplyTaskWindow window, {List<String> aliases = const []}) {
    final key =
        _key(window.kind, window.apparatusId, window.limit, window.search);
    final previous = _windows[key];
    if (previous?.epoch == window.epoch &&
        previous!.revision > window.revision) {
      return;
    }
    final keys = {
      key,
      ...aliases,
      for (final entry in _windows.entries)
        if (entry.value.kind == window.kind &&
            entry.value.apparatusId == window.apparatusId &&
            entry.value.limit == window.limit &&
            entry.value.search == window.search)
          entry.key
    };
    final scope = currentSessionReadScope();
    _deniedKinds.remove(window.kind);
    Map<String, dynamic>? value;
    for (final alias in keys) {
      final old = _windows[alias];
      _windows.remove(alias);
      _windows[alias] = window;
      if (old?.version != window.version ||
          old?.epoch != window.epoch ||
          old?.scope != window.scope) {
        value ??= {'schema': 1, 'window': window.toJson()};
        unawaited(_snapshots.write(scope: scope, key: alias, value: value));
      }
    }
    while (_windows.length > 8) {
      _windows.remove(_windows.keys.first);
    }
  }

  void _forgetKind(String kind, String scope, String requestKey) {
    // Reject a response begun before terminal authorization withdrawal.
    _generation++;
    _pending.clear();
    _readSerials.clear();
    _deniedKinds.add(kind);
    final keys = {
      requestKey,
      for (final entry in _windows.entries)
        if (entry.value.kind == kind) entry.key
    };
    for (final key in keys) {
      _windows.remove(key);
      unawaited(_snapshots.remove(scope: scope, key: key));
    }
  }

  void reset() {
    _generation++;
    _owner = null;
    _windows.clear();
    _pending.clear();
    _readSerials.clear();
    _prepared.clear();
    _deniedKinds.clear();
  }
}
