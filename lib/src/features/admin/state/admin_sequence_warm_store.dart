import 'dart:async';
import 'dart:convert';

import '../../../core/api/mobile_api.dart';
import '../../../core/production/production_data_revision.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/session/state/app_session.dart';
import '../../shared/models/app_models.dart';
import 'admin_sequence_apparatus_store.dart';

/// Includes the authentication generation as well as the readable data scope.
/// This key is local only and must never be logged or sent as a window ID.
String currentAdminSequenceWarmScope() => jsonEncode([
      MobileApi.baseUrl,
      AppSession.instance.token,
      currentSessionReadScope(),
      AppSession.instance.revision.value,
    ]);

typedef AdminSequenceWarmLiveLoader = Stream<AdminProductionMapLiveMessage>
    Function(List<Map<String, Object?>> windows);

class AdminSequenceWarmSnapshot {
  AdminSequenceWarmSnapshot({
    required this.scope,
    required Iterable<AdminApparatus> apparatus,
    required this.selectedApparatusId,
    required this.page,
    required this.fresh,
  }) : apparatus = List.unmodifiable(apparatus);

  final String scope;
  final List<AdminApparatus> apparatus;
  final String selectedApparatusId;
  final AdminProductionOrderPage page;

  /// Display readiness is independent of the live subscription's validation.
  /// A saved/HTTP baseline is useful immediately, but cannot authorize writes.
  final bool fresh;

  AdminSequenceWarmSnapshot _copy({
    AdminProductionOrderPage? page,
    bool? fresh,
  }) =>
      AdminSequenceWarmSnapshot(
        scope: scope,
        apparatus: apparatus,
        selectedApparatusId: selectedApparatusId,
        page: page ?? this.page,
        fresh: fresh ?? this.fresh,
      );
}

/// A screen owns its live subscription while this lease is held. The already
/// running preload is shared with it, rather than canceled and fetched again.
class AdminSequenceWarmLease {
  AdminSequenceWarmLease._(this._owner, this._generation, this._id, this.ready);

  final AdminSequenceWarmStore _owner;
  final int _generation;
  final int _id;
  final Future<AdminSequenceWarmSnapshot?> ready;
  bool _released = false;

  void release({
    Iterable<AdminApparatus>? apparatus,
    String? selectedApparatusId,
    AdminProductionOrderPage? page,
    AdminProductionOrderPage? ordersPage,
    bool confirmed = false,
  }) {
    if (_released) return;
    _released = true;
    _owner._release(this,
        apparatus: apparatus,
        selectedApparatusId: selectedApparatusId,
        page: page,
        ordersPage: ordersPage,
        confirmed: confirmed);
  }
}

/// One account's selected sequence prefix, prepared before route navigation.
///
/// After the selected sequence is ready, one compact Orders prefix is prepared
/// without delaying sequence readiness. Neither preload resolves image URLs or
/// reads details/following pages. Only the sequence has a background live window;
/// timers reconnect sockets only, with no recurring HTTP refresh or polling.
class AdminSequenceWarmStore {
  AdminSequenceWarmStore({
    Future<List<AdminApparatus>> Function()? apparatusLoader,
    Future<String?> Function(String? profileRef)? selectedApparatusLoader,
    AdminProductionOrderPageLoader? pageLoader,
    AdminSequenceWarmLiveLoader? liveLoader,
    Duration Function(int attempt)? reconnectDelay,
    String Function()? scopeReader,
    this.firstMessageTimeout = const Duration(seconds: 10),
  })  : _apparatusLoader = apparatusLoader ??
            (() => MobileApi.instance.adminApparatus(limit: 200)),
        _selectedApparatusLoader = selectedApparatusLoader ??
            ((profileRef) => AdminSequenceApparatusStore.instance
                .loadSavedApparatusId(profileRef: profileRef)),
        _pageLoader = pageLoader ?? MobileApi.instance.adminProductionOrderPage,
        _liveLoader = liveLoader ??
            ((windows) => MobileApi.instance.adminProductionMapLiveStream(
                paged: true, workerScope: false, pageWindows: windows)),
        _reconnectDelay = reconnectDelay ?? _defaultReconnectDelay,
        _scopeReader = scopeReader;

  static AdminSequenceWarmStore? debugOverride;
  static final _instance =
      AdminSequenceWarmStore(scopeReader: currentAdminSequenceWarmScope);
  static AdminSequenceWarmStore get instance => debugOverride ?? _instance;

  static const windowId = 'warm-sequence';
  final Future<List<AdminApparatus>> Function() _apparatusLoader;
  final Future<String?> Function(String? profileRef) _selectedApparatusLoader;
  final AdminProductionOrderPageLoader _pageLoader;
  final AdminSequenceWarmLiveLoader _liveLoader;
  final Duration Function(int attempt) _reconnectDelay;
  final String Function()? _scopeReader;
  final Duration firstMessageTimeout;

  String? _scope;
  String? _profileRef;
  String? _preferredApparatusId;
  List<AdminApparatus>? _knownApparatus;
  bool _foreground = false;
  bool _disposed = false;
  bool _authorizationBlocked = false;
  int _generation = 0;
  int _snapshotSerial = 0;
  int _leaseSerial = 0;
  final Set<int> _leases = {};
  AdminSequenceWarmSnapshot? _snapshot;
  Future<AdminSequenceWarmSnapshot?>? _preparing;
  AdminProductionOrderPage? _ordersPage;
  Future<AdminProductionOrderPage?>? _preparingOrders;
  int _ordersSerial = 0;
  bool _ordersAutoAttempted = false;
  final Set<String> _retiredOrdersEpochs = {};
  StreamSubscription<AdminProductionMapLiveMessage>? _subscription;
  Timer? _reconnectTimer;
  Timer? _firstMessageTimer;
  int _streamGeneration = 0;
  int _reconnectAttempt = 0;
  bool _repairBudget = true;
  Future<void> _events = Future.value();
  Object? _lastError;

  Object? get lastError => _lastError;

  bool _owns(int generation) =>
      !_disposed &&
      !_authorizationBlocked &&
      generation == _generation &&
      _scope != null &&
      (_scopeReader == null || _scopeReader() == _scope);

  bool get _mayStream => _owns(_generation) && _foreground && _leases.isEmpty;

  /// Called by the foreground session coordinator, never by a periodic timer.
  void configure({
    required String? scope,
    String? profileRef,
    required bool foreground,
  }) {
    if (_disposed) return;
    final nextScope = scope == null || scope.isEmpty ? null : scope;
    final changed = nextScope != _scope;
    final resumed = foreground && !_foreground;
    if (changed) {
      _generation++;
      _snapshotSerial++;
      _stopLive();
      _scope = nextScope;
      _snapshot = null;
      _preparing = null;
      _clearOrders();
      _preferredApparatusId = null;
      _knownApparatus = null;
      _authorizationBlocked = false;
      _leases.clear();
      _lastError = null;
      _reconnectAttempt = 0;
    }
    _profileRef = profileRef;
    _foreground = foreground;
    if (!_foreground || nextScope == null) {
      _markStale();
      _stopLive();
      return;
    }
    if (!changed && !resumed) return;
    _repairBudget = true;
    if (_snapshot != null) {
      _startLive();
      _warmOrdersAfterSequence();
    } else {
      unawaited(prepare(nextScope));
    }
  }

  AdminSequenceWarmSnapshot? peek(String scope) =>
      scope == _scope && _owns(_generation) ? _snapshot : null;

  AdminProductionOrderPage? peekOrders(String scope) =>
      scope == _scope && _owns(_generation) ? _ordersPage : null;

  /// Foreground navigation can promote this read before sequence finishes.
  /// Automatic warming and navigation share the exact same in-flight future.
  /// Unlike the best-effort background observer, explicit callers receive read
  /// errors and can use their existing foreground error/retry presentation.
  Future<AdminProductionOrderPage?> prepareOrders(String scope) {
    if (scope != _scope || !_owns(_generation)) return Future.value();
    if (_ordersPage != null) return Future.value(_ordersPage);
    final pending = _preparingOrders;
    if (pending != null) return pending;
    if (!_foreground) return Future.value();
    _ordersAutoAttempted = true;
    late final Future<AdminProductionOrderPage?> future;
    future = _readOrders(_generation, _ordersSerial).whenComplete(() {
      if (identical(_preparingOrders, future)) _preparingOrders = null;
    });
    _preparingOrders = future;
    return future;
  }

  /// A screen returns only its canonical, unsearched first compact page. This
  /// supersedes any earlier background read without letting it overwrite data.
  void rememberOrders(String scope, AdminProductionOrderPage page) {
    if (scope != _scope ||
        !_owns(_generation) ||
        !_validOrdersPage(page) ||
        _retiredOrdersEpochs.contains(page.epoch)) {
      return;
    }
    final current = _ordersPage;
    if (current != null &&
        current.epoch == page.epoch &&
        current.revision! > page.revision!) {
      return;
    }
    if (current != null && current.epoch != page.epoch) {
      _retiredOrdersEpochs.add(current.epoch);
    }
    _ordersSerial++;
    _ordersAutoAttempted = true;
    _ordersPage = page;
  }

  static bool _validOrdersPage(AdminProductionOrderPage page) =>
      page.isOrdersList &&
      page.scope.isNotEmpty &&
      page.wireValue?['projection'] == adminOrdersListProjection &&
      _validFirstPage(page);

  Future<AdminProductionOrderPage?> _readOrders(
      int generation, int serial) async {
    try {
      final page = await _pageLoader(
          const AdminProductionOrderPageRequest(view: 'orders'));
      if (!_owns(generation)) return null;
      if (serial != _ordersSerial) return _ordersPage;
      if (page == null || !_validOrdersPage(page)) {
        throw const MobileApiException(
            code: 'order_page_invalid',
            message: 'Buyurtmalar sahifasi noto‘g‘ri. Qayta yuklang.');
      }
      if (_retiredOrdersEpochs.contains(page.epoch)) return _ordersPage;
      _ordersPage = page;
      return page;
    } catch (error) {
      if (!_owns(generation)) return null;
      if (serial != _ordersSerial) return _ordersPage;
      _recordReadError(generation, error);
      rethrow;
    }
  }

  void _warmOrdersAfterSequence() {
    if (!_owns(_generation) ||
        !_foreground ||
        _snapshot == null ||
        _ordersAutoAttempted) {
      return;
    }
    // Attaching the observer immediately keeps a failed speculative request
    // out of the unhandled-error zone. The shared future still rejects for an
    // explicit caller that joins it while the background request is pending.
    unawaited(prepareOrders(_scope!)
        .then<void>((_) {}, onError: (Object _, StackTrace __) {}));
  }

  void _clearOrders() {
    _ordersSerial++;
    _ordersPage = null;
    _preparingOrders = null;
    _ordersAutoAttempted = false;
    _retiredOrdersEpochs.clear();
  }

  /// Returns the very same future to every caller during a cold preparation.
  /// Failed background reads are not retried on a timer; explicit navigation or
  /// a later foreground transition may request another bounded preparation.
  Future<AdminSequenceWarmSnapshot?> prepare(String scope) {
    if (scope != _scope || !_owns(_generation)) return Future.value();
    if (_snapshot != null) return Future.value(_snapshot);
    final pending = _preparing;
    if (pending != null) return pending;
    late final Future<AdminSequenceWarmSnapshot?> future;
    future = _prepare(_generation, _snapshotSerial).whenComplete(() {
      if (identical(_preparing, future)) _preparing = null;
    });
    _preparing = future;
    return future;
  }

  AdminSequenceWarmLease acquire(String scope) {
    final id = ++_leaseSerial;
    if (scope != _scope || !_owns(_generation)) {
      return AdminSequenceWarmLease._(
          this, -1, id, Future<AdminSequenceWarmSnapshot?>.value());
    }
    _leases.add(id);
    _markStale();
    _stopLive();
    return AdminSequenceWarmLease._(this, _generation, id, prepare(scope));
  }

  Future<AdminSequenceWarmSnapshot?> _prepare(
      int generation, int serial) async {
    // Start catalog and preference reads together. A saved apparatus permits
    // its page read to overlap the catalog's network request as well.
    final selected = _readSelection(generation);
    final catalog = _knownApparatus == null
        ? _readCatalog(generation)
        : Future<List<AdminApparatus>?>.value(_knownApparatus);
    final speculative = selected.then(
        (id) => id == null || id.isEmpty ? null : _readFirst(id, generation));
    final apparatus = await catalog;
    final selectedId = await selected;
    if (!_owns(generation)) return null;
    if (apparatus == null || apparatus.isEmpty) return null;
    final remembered =
        apparatus.where((item) => item.id == selectedId).firstOrNull;
    final target = remembered ?? apparatus.first;
    final page = target.id == selectedId
        ? await speculative
        : await _readFirst(target.id, generation);
    if (!_owns(generation)) return null;
    // A screen may have returned a newer canonical page while this read ran.
    if (serial != _snapshotSerial) return _snapshot;
    _knownApparatus = apparatus;
    if (page == null) return null;
    _snapshot = AdminSequenceWarmSnapshot(
      scope: _scope!,
      apparatus: apparatus,
      selectedApparatusId: target.id,
      page: page,
      fresh: false,
    );
    _lastError = null;
    _startLive();
    _warmOrdersAfterSequence();
    return _snapshot;
  }

  Future<String?> _readSelection(int generation) async {
    if (_preferredApparatusId != null) return _preferredApparatusId;
    try {
      final selected = await _selectedApparatusLoader(_profileRef);
      return _owns(generation) ? selected?.trim() : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<AdminApparatus>?> _readCatalog(int generation) async {
    try {
      final apparatus = await _apparatusLoader();
      if (!_owns(generation)) return null;
      if (apparatus.length > 200 ||
          apparatus.any((item) => item.id.trim().isEmpty) ||
          apparatus.map((item) => item.id).toSet().length != apparatus.length) {
        throw StateError('Invalid warm apparatus catalog');
      }
      return List.unmodifiable(apparatus);
    } catch (error) {
      _recordReadError(generation, error);
      return null;
    }
  }

  Future<AdminProductionOrderPage?> _readFirst(
      String apparatus, int generation) async {
    if (!_owns(generation)) return null;
    try {
      final page = await _pageLoader(AdminProductionOrderPageRequest(
          view: 'sequence', apparatus: apparatus));
      if (!_owns(generation)) return null;
      if (page == null || !_validFirstPage(page)) {
        throw StateError('Invalid warm sequence page');
      }
      return page;
    } catch (error) {
      _recordReadError(generation, error);
      return null;
    }
  }

  static bool _validFirstPage(AdminProductionOrderPage page) =>
      page.offset == 0 &&
      page.length <= 20 &&
      page.version.isNotEmpty &&
      page.epoch.isNotEmpty &&
      page.revision != null &&
      page.revision! >= 0 &&
      page.wireValue != null;

  void _release(
    AdminSequenceWarmLease lease, {
    Iterable<AdminApparatus>? apparatus,
    String? selectedApparatusId,
    AdminProductionOrderPage? page,
    AdminProductionOrderPage? ordersPage,
    required bool confirmed,
  }) {
    if (!_owns(lease._generation) || !_leases.remove(lease._id)) return;
    // Older stacked routes cannot overwrite the more recently visited route.
    if (lease._id == _leaseSerial && ordersPage != null) {
      rememberOrders(_scope!, ordersPage);
    }
    if (lease._id == _leaseSerial &&
        (apparatus != null || selectedApparatusId != null || page != null)) {
      final catalog = apparatus?.take(200).toList(growable: false);
      _preferredApparatusId = selectedApparatusId;
      if (catalog != null &&
          catalog.every((item) => item.id.trim().isNotEmpty) &&
          catalog.map((item) => item.id).toSet().length == catalog.length) {
        _knownApparatus = List.unmodifiable(catalog);
      }
      _snapshotSerial++;
      _preparing = null;
      if (catalog != null &&
          selectedApparatusId != null &&
          catalog.any((item) => item.id == selectedApparatusId) &&
          page != null &&
          _validFirstPage(page)) {
        _snapshot = AdminSequenceWarmSnapshot(
          scope: _scope!,
          apparatus: catalog,
          selectedApparatusId: selectedApparatusId,
          page: page,
          fresh: confirmed,
        );
        _lastError = null;
      } else {
        // Never reopen the previous apparatus when the departing route has a
        // newer selection but cannot hand back a canonical page yet.
        _snapshot = null;
      }
    }
    if (_leases.isEmpty && _mayStream) {
      _repairBudget = true;
      if (_snapshot != null) {
        _startLive();
        _warmOrdersAfterSequence();
      } else if (_preferredApparatusId != null) {
        unawaited(prepare(_scope!));
      }
    }
  }

  void _markStale() {
    if (_snapshot?.fresh == true) _snapshot = _snapshot!._copy(fresh: false);
  }

  void _startLive() {
    if (!_mayStream ||
        _snapshot == null ||
        _subscription != null ||
        _reconnectTimer != null) {
      return;
    }
    _markStale();
    final generation = ++_streamGeneration;
    final value = _snapshot!;
    _events = Future.value();
    _firstMessageTimer = Timer(firstMessageTimeout, () {
      if (generation == _streamGeneration) {
        _disconnected(generation, TimeoutException('Warm page first event'));
      }
    });
    try {
      _subscription = _liveLoader([
        {
          'id': windowId,
          'view': 'sequence',
          if (value.page.isSequenceList)
            'projection': adminSequenceListProjection,
          'apparatus': value.selectedApparatusId,
          'target': '',
          'search': '',
          'length': 20,
          'version': value.page.version,
        }
      ]).listen(
        (event) => _enqueue(generation, () => _apply(event, generation)),
        onError: (Object error, StackTrace _) =>
            _enqueue(generation, () => _disconnected(generation, error)),
        onDone: () =>
            _enqueue(generation, () => _disconnected(generation, null)),
      );
    } catch (error) {
      _disconnected(generation, error);
    }
  }

  void _enqueue(int generation, FutureOr<void> Function() action) {
    _events = _events.then((_) async {
      if (generation != _streamGeneration || !_mayStream) return;
      await action();
    }).catchError((Object error) {
      _disconnected(generation, error);
    });
  }

  Future<void> _apply(
      AdminProductionMapLiveMessage event, int generation) async {
    final before = _snapshot;
    if (before == null) return;
    if (event is! AdminProductionMapPageWindowMessage) {
      await _repair(generation);
      return;
    }
    if (event.window != windowId) return;
    final page = before.page;
    if (event.epoch == page.epoch && event.revision < page.revision!) return;
    try {
      if (event.type == 'page_window_resync') {
        await _repair(generation);
        return;
      }
      if (event.type == 'page_window_ready') {
        if (event.value['resync'] != false ||
            event.epoch != page.epoch ||
            event.revision != page.revision ||
            event.version != page.version) {
          await _repair(generation);
          return;
        }
        _snapshot = before._copy(fresh: true);
      } else if (event.epoch == page.epoch &&
          event.revision == page.revision &&
          event.version == page.version) {
        // A duplicate is already represented by this immutable wire baseline.
        return;
      } else {
        final next = await applyAdminOrderPageWindow([page], event);
        if (generation != _streamGeneration ||
            !_mayStream ||
            !identical(before, _snapshot)) {
          return;
        }
        if (next.length != 1 || !_validFirstPage(next.single)) {
          throw StateError('Warm prefix changed bounds');
        }
        _snapshot = before._copy(page: next.single, fresh: true);
      }
      _firstMessageTimer?.cancel();
      _firstMessageTimer = null;
      _reconnectAttempt = 0;
      _repairBudget = true;
      _lastError = null;
      if (generation == _streamGeneration && _mayStream) {
        ProductionDataRevision.notify(
            epoch: event.epoch, revision: event.revision);
      }
    } catch (_) {
      await _repair(generation);
    }
  }

  /// One HTTP repair is allowed between validated stream baselines. A broken
  /// server cannot turn repeated resync frames into an HTTP polling loop.
  Future<void> _repair(int streamGeneration) async {
    if (streamGeneration != _streamGeneration || !_mayStream) return;
    if (!_repairBudget) {
      _disconnected(streamGeneration, StateError('Warm resync not validated'));
      return;
    }
    _repairBudget = false;
    _markStale();
    _stopLive();
    final generation = _generation;
    final serial = _snapshotSerial;
    final before = _snapshot!;
    final page = await _readFirst(before.selectedApparatusId, generation);
    if (!_owns(generation) || serial != _snapshotSerial) return;
    if (page != null) {
      _snapshot = before._copy(page: page, fresh: false);
      _startLive();
    } else {
      _disconnected(_streamGeneration, _lastError);
    }
  }

  void _disconnected(int generation, Object? error) {
    if (generation != _streamGeneration || !_mayStream) return;
    if (error != null && _isAuthorizationError(error)) {
      _recordReadError(_generation, error);
      return;
    }
    _markStale();
    if (error != null) _lastError = error;
    _stopLive();
    if (!_mayStream) return;
    _reconnectTimer = Timer(_reconnectDelay(_reconnectAttempt++), () {
      _reconnectTimer = null;
      _startLive();
    });
  }

  void _stopLive() {
    _streamGeneration++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _firstMessageTimer?.cancel();
    _firstMessageTimer = null;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
  }

  static bool _isAuthorizationError(Object error) =>
      error is MobileApiException &&
      (error.statusCode == 401 ||
          error.statusCode == 403 ||
          error.code == 'unauthorized' ||
          error.code == 'forbidden');

  void _recordReadError(int generation, Object error) {
    if (!_owns(generation)) return;
    _lastError = error;
    if (_isAuthorizationError(error)) {
      _authorizationBlocked = true;
      _snapshotSerial++;
      _snapshot = null;
      _knownApparatus = null;
      _clearOrders();
      _stopLive();
    }
  }

  static Duration _defaultReconnectDelay(int attempt) {
    final bounded = attempt.clamp(0, 5);
    return Duration(seconds: bounded == 5 ? 30 : 1 << bounded);
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _snapshotSerial++;
    _stopLive();
    _scope = null;
    _snapshot = null;
    _knownApparatus = null;
    _preparing = null;
    _clearOrders();
    _leases.clear();
  }
}
