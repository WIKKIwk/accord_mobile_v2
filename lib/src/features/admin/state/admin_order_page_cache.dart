import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/cache/production_snapshot_models.dart';
import '../../../core/cache/production_snapshot_store.dart';
import '../../shared/models/app_models.dart';

String _encodeAdminPagePersistence(Map<String, dynamic> value) =>
    jsonEncode(value);

class AdminOrderPageCacheWindow {
  AdminOrderPageCacheWindow(
      this.request, Iterable<AdminProductionOrderPage> pages)
      : pages = List.unmodifiable(pages);

  final AdminProductionOrderPageRequest request;
  final List<AdminProductionOrderPage> pages;
}

class AdminOrderPageCacheSnapshot {
  AdminOrderPageCacheSnapshot({
    required Iterable<AdminApparatus> apparatus,
    required this.selectedApparatusId,
    required Iterable<AdminOrderPageCacheWindow> windows,
  })  : apparatus = List.unmodifiable(apparatus),
        windows = List.unmodifiable(windows);

  final List<AdminApparatus> apparatus;
  final String? selectedApparatusId;
  final List<AdminOrderPageCacheWindow> windows;
}

class AdminOrderPageCacheVisit {
  AdminOrderPageCacheVisit._(this._owner, this._serial, this.snapshot);
  final AdminOrderPageCache _owner;
  final int _serial;
  final AdminOrderPageCacheSnapshot? snapshot;
}

/// Only immutable server pages survive navigation; sockets, pending writes,
/// widget state and in-flight futures always belong to the current screen.
class AdminOrderPageCache {
  AdminOrderPageCache({
    this.maxAge = const Duration(minutes: 5),
    this.maxWindows = 12,
    this.maxPages = 20,
    this.maxPagesPerWindow = 5,
    DateTime Function()? now,
    this.persistence,
    this.maxPersistedAge = const Duration(days: 7),
  })  : assert(maxWindows > 0 && maxPages > 0 && maxPagesPerWindow > 0),
        _now = now ?? DateTime.now;

  static AdminOrderPageCache? debugOverride;
  static final _instance =
      AdminOrderPageCache(persistence: ProductionSnapshotStore.instance);
  static AdminOrderPageCache get instance => debugOverride ?? _instance;
  static const _persistentKey = 'admin-pages-v2';
  final ProductionSnapshotStore? persistence;
  final Duration maxPersistedAge;
  final Duration maxAge;
  final int maxWindows;
  final int maxPages;
  final int maxPagesPerWindow;
  final DateTime Function() _now;
  String? _scope;
  DateTime? _savedAt;
  AdminOrderPageCacheSnapshot? _snapshot;
  int _serial = 0;
  int _persistenceSerial = 0;
  String? _persistentScope;
  Future<void> _pendingPersistence = Future.value();
  Timer? _persistenceTimer;
  Future<void> Function()? _scheduledPersistence;
  AdminOrderPageCacheSnapshot? _lastScheduledSnapshot;
  DateTime? _lastScheduledAt;
  int? _lastScheduledVisit;

  AdminOrderPageCacheVisit open(String scope) {
    final age = _savedAt == null ? null : _now().difference(_savedAt!);
    if (_scope != scope || (age != null && (age.isNegative || age >= maxAge))) {
      clear();
    }
    _scope = scope;
    // A disposed older route cannot overwrite a newer visit or a logout.
    return AdminOrderPageCacheVisit._(this, ++_serial, _snapshot);
  }

  void save({
    required AdminOrderPageCacheVisit visit,
    required Iterable<AdminApparatus> apparatus,
    required String? selectedApparatusId,
    required Iterable<AdminOrderPageCacheWindow> windows,
    bool refreshAge = true,
    String? persistentScope,
    Iterable<AdminOrderPageCacheWindow>? persistentWindows,
  }) {
    if (!identical(visit._owner, this) || visit._serial != _serial) return;
    var remaining = maxPages;
    final bounded = <AdminOrderPageCacheWindow>[];
    for (final window in windows) {
      if (bounded.length == maxWindows || remaining == 0) break;
      if (window.pages.isEmpty) continue;
      final pages =
          window.pages.take(maxPagesPerWindow).take(remaining).toList();
      final first = pages.first;
      var offset = 0;
      if (first.version.isEmpty ||
          first.epoch.isEmpty ||
          first.revision == null ||
          pages.any((page) {
            final valid = page.offset == offset &&
                page.version == first.version &&
                page.epoch == first.epoch &&
                page.revision == first.revision;
            offset += page.length;
            return !valid;
          })) {
        continue;
      }
      bounded.add(AdminOrderPageCacheWindow(window.request, pages));
      remaining -= pages.length;
    }
    _snapshot = bounded.isEmpty
        ? null
        : AdminOrderPageCacheSnapshot(
            apparatus: apparatus.take(200),
            selectedApparatusId: selectedApparatusId,
            windows: bounded,
          );
    // Reopening an unconfirmed baseline must not renew its lifetime.
    if (refreshAge || _savedAt == null) _savedAt = _now();
    if (persistentScope != null && persistence != null && refreshAge) {
      _persistentScope = persistentScope;
      final durable = _boundedPersistentSnapshot(
        apparatus: apparatus,
        selectedApparatusId: selectedApparatusId,
        windows: persistentWindows ?? bounded,
      );
      if (durable != null) {
        _schedulePersistence(visit, persistentScope, durable);
      }
    }
  }

  void clear() {
    _persistenceTimer?.cancel();
    _persistenceTimer = null;
    _scheduledPersistence = null;
    _lastScheduledSnapshot = null;
    _lastScheduledAt = null;
    _lastScheduledVisit = null;
    _persistenceSerial++;
    _persistentScope = null;
    _scope = null;
    _savedAt = null;
    _snapshot = null;
    _serial++;
  }

  void invalidate(AdminOrderPageCacheVisit? visit) {
    if (visit != null &&
        identical(visit._owner, this) &&
        visit._serial == _serial) {
      final scope = _persistentScope;
      clear();
      if (scope != null && persistence != null) {
        unawaited(persistence!.remove(scope: scope, key: _persistentKey));
      }
    }
  }

  /// Reads only a display baseline. The caller must keep mutation controls
  /// disabled until the existing live/conditional-read barrier confirms it.
  Future<AdminOrderPageCacheSnapshot?> restore({
    required AdminOrderPageCacheVisit visit,
    required String persistentScope,
  }) async {
    if (!_owns(visit)) {
      return null;
    }
    _persistentScope = persistentScope;
    if (_snapshot != null) return _snapshot;
    final store = persistence;
    if (store == null) return null;
    final raw = await store
        .read(scope: persistentScope, key: _persistentKey)
        .timeout(const Duration(milliseconds: 500), onTimeout: () => null);
    if (!_owns(visit) || _persistentScope != persistentScope || raw == null) {
      return null;
    }
    try {
      if (raw['schema'] != 1 ||
          raw['confirmed_at'] is! int ||
          raw['apparatus'] is! List ||
          raw['windows'] is! List ||
          (raw['apparatus'] as List).length > 200 ||
          (raw['windows'] as List).length > maxWindows ||
          (raw['selected_apparatus_id'] != null &&
              raw['selected_apparatus_id'] is! String)) {
        throw const FormatException('Invalid cached admin pages');
      }
      final savedAt = DateTime.fromMillisecondsSinceEpoch(
          raw['confirmed_at'] as int,
          isUtc: true);
      final age = _now().difference(savedAt);
      if (age.isNegative || age >= maxPersistedAge) {
        throw const FormatException('Expired cached admin pages');
      }
      final apparatus = [
        for (final item in raw['apparatus'] as List)
          decodeCachedApparatus((item as Map).cast<String, dynamic>()),
      ];
      if (apparatus.length > 200 ||
          apparatus.isEmpty ||
          apparatus.map((item) => item.id).toSet().length != apparatus.length) {
        throw const FormatException('Invalid cached apparatus catalog');
      }
      final windows = <AdminOrderPageCacheWindow>[];
      final windowKeys = <String>{};
      var pageCount = 0;
      for (final item in raw['windows'] as List) {
        final window = (item as Map).cast<String, dynamic>();
        final request = (window['request'] as Map).cast<String, dynamic>();
        final view = request['view'];
        if (!const {'sequence', 'orders', 'closed', 'move', 'audit'}
                .contains(view) ||
            request['apparatus'] is! String ||
            request['target'] is! String ||
            request['search'] != '' ||
            window['pages'] is! List) {
          throw const FormatException('Invalid cached page request');
        }
        final rawPages = window['pages'] as List;
        pageCount += rawPages.length;
        if (rawPages.isEmpty ||
            rawPages.length > maxPagesPerWindow ||
            pageCount > maxPages ||
            !windowKeys.add(
                '$view\u0000${request['apparatus']}\u0000${request['target']}')) {
          throw const FormatException('Invalid cached page bounds');
        }
        final pages = <AdminProductionOrderPage>[];
        for (final value in window['pages'] as List) {
          pages.add(await AdminProductionOrderPage.fromJson(
              (value as Map).cast<String, dynamic>()));
        }
        windows.add(AdminOrderPageCacheWindow(
            AdminProductionOrderPageRequest(
                view: view as String,
                apparatus: request['apparatus'] as String,
                target: request['target'] as String),
            pages));
      }
      if (!_owns(visit) || _persistentScope != persistentScope) return null;
      final restored = _boundedPersistentSnapshot(
          apparatus: apparatus,
          selectedApparatusId: raw['selected_apparatus_id'] as String?,
          windows: windows);
      if (restored == null ||
          restored.windows.length != windows.length ||
          restored.windows
                  .fold<int>(0, (n, window) => n + window.pages.length) !=
              windows.fold<int>(0, (n, window) => n + window.pages.length)) {
        throw const FormatException('Invalid cached page prefix');
      }
      _snapshot = restored;
      // The process restart did not reconfirm server state.
      _savedAt = savedAt;
      return restored;
    } on Object {
      if (_owns(visit) && _persistentScope == persistentScope) {
        await store.remove(scope: persistentScope, key: _persistentKey);
      }
      return null;
    }
  }

  bool _owns(AdminOrderPageCacheVisit visit) =>
      identical(visit._owner, this) && visit._serial == _serial;

  AdminOrderPageCacheSnapshot? _boundedPersistentSnapshot({
    required Iterable<AdminApparatus> apparatus,
    required String? selectedApparatusId,
    required Iterable<AdminOrderPageCacheWindow> windows,
  }) {
    var remaining = maxPages;
    final result = <AdminOrderPageCacheWindow>[];
    for (final window in windows) {
      if (result.length >= maxWindows || remaining == 0) break;
      final pages =
          window.pages.take(maxPagesPerWindow).take(remaining).toList();
      if (pages.isEmpty ||
          window.request.search.isNotEmpty ||
          !const {'sequence', 'orders', 'closed', 'move', 'audit'}
              .contains(window.request.view)) {
        continue;
      }
      final first = pages.first;
      var offset = 0;
      final seen = <String>{};
      if (first.version.isEmpty ||
          first.epoch.isEmpty ||
          first.revision == null ||
          first.revision! < 0 ||
          pages.any((page) {
            final valid = page.wireValue != null &&
                page.offset == offset &&
                page.version == first.version &&
                page.epoch == first.epoch &&
                page.revision == first.revision &&
                [
                  ...page.orderIds,
                  ...page.pendingOrders.map((row) => row.id),
                  ...page.closedOrders.map((row) => row.orderId)
                ].every(seen.add);
            offset += page.length;
            return !valid;
          })) {
        continue;
      }
      result.add(AdminOrderPageCacheWindow(window.request, pages));
      remaining -= pages.length;
    }
    if (result.isEmpty) return null;
    return AdminOrderPageCacheSnapshot(
        apparatus: apparatus.take(200),
        selectedApparatusId: selectedApparatusId,
        windows: result);
  }

  bool _samePersistentSnapshot(
      AdminOrderPageCacheSnapshot before, AdminOrderPageCacheSnapshot after) {
    if (before.selectedApparatusId != after.selectedApparatusId ||
        before.apparatus.length != after.apparatus.length ||
        before.windows.length != after.windows.length) {
      return false;
    }
    for (var index = 0; index < before.apparatus.length; index++) {
      if (!identical(before.apparatus[index], after.apparatus[index])) {
        return false;
      }
    }
    for (var index = 0; index < before.windows.length; index++) {
      final a = before.windows[index];
      final b = after.windows[index];
      if (a.request.view != b.request.view ||
          a.request.apparatus != b.request.apparatus ||
          a.request.target != b.request.target ||
          a.pages.length != b.pages.length) {
        return false;
      }
      for (var page = 0; page < a.pages.length; page++) {
        if (!identical(a.pages[page].wireValue, b.pages[page].wireValue)) {
          return false;
        }
      }
    }
    return true;
  }

  void _schedulePersistence(AdminOrderPageCacheVisit visit, String scope,
      AdminOrderPageCacheSnapshot snapshot) {
    final previous = _lastScheduledSnapshot;
    final elapsed =
        _lastScheduledAt == null ? null : _now().difference(_lastScheduledAt!);
    if (previous != null &&
        _lastScheduledVisit == visit._serial &&
        elapsed != null &&
        !elapsed.isNegative &&
        elapsed < const Duration(minutes: 1) &&
        _samePersistentSnapshot(previous, snapshot)) {
      return;
    }
    _lastScheduledSnapshot = snapshot;
    _lastScheduledAt = _now();
    _lastScheduledVisit = visit._serial;
    final serial = ++_persistenceSerial;
    final confirmedAt = _savedAt!.millisecondsSinceEpoch;
    final store = persistence!;
    final generation = store.generation;
    bool current() =>
        _owns(visit) &&
        serial == _persistenceSerial &&
        _persistentScope == scope &&
        store.generation == generation;
    _scheduledPersistence = () async {
      if (!current()) return;
      try {
        final value = <String, dynamic>{
          'schema': 1,
          'confirmed_at': confirmedAt,
          'selected_apparatus_id': snapshot.selectedApparatusId,
          'apparatus': [
            for (final item in snapshot.apparatus) encodeCachedApparatus(item)
          ],
          'windows': [
            for (final window in snapshot.windows)
              {
                'request': {
                  'view': window.request.view,
                  'apparatus': window.request.apparatus,
                  'target': window.request.target,
                  'search': window.request.search
                },
                'pages': [for (final page in window.pages) page.wireValue!],
              }
          ],
        };
        final rows = snapshot.windows.fold<int>(
            0,
            (n, window) =>
                n +
                window.pages
                    .fold<int>(0, (count, page) => count + page.length));
        final encoded =
            !kIsWeb && (rows >= 20 || snapshot.apparatus.length >= 50)
                ? await compute(_encodeAdminPagePersistence, value,
                    debugLabel: 'admin-page-cache-encode')
                : _encodeAdminPagePersistence(value);
        if (!current()) return;
        await store.writeEncoded(
            scope: scope,
            key: _persistentKey,
            valueJson: encoded,
            expectedGeneration: generation);
      } on Object {
        // A disk/quota failure never fails a canonical server update.
      }
    };
    _persistenceTimer?.cancel();
    _persistenceTimer =
        Timer(const Duration(milliseconds: 250), _enqueuePersistence);
  }

  void _enqueuePersistence() {
    _persistenceTimer?.cancel();
    _persistenceTimer = null;
    final save = _scheduledPersistence;
    _scheduledPersistence = null;
    if (save != null) {
      _pendingPersistence = _pendingPersistence.then((_) => save());
    }
  }

  Future<void> flush() {
    _enqueuePersistence();
    return _pendingPersistence;
  }
}
