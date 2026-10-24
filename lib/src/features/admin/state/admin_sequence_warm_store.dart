import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
/// After the selected sequence attempt, first pages are prepared in tab order.
/// Foreground tab requests bypass that queue and share any existing read. No
/// preload resolves image URLs or reads details/following pages. Only the
/// sequence has a background live window;
/// Transient reads have a bounded retry budget; there is no recurring HTTP
/// refresh or polling after that preparation finishes.
class AdminSequenceWarmStore {
  AdminSequenceWarmStore({
    Future<List<AdminApparatus>> Function()? apparatusLoader,
    Future<String?> Function(String? profileRef)? selectedApparatusLoader,
    AdminProductionOrderPageLoader? pageLoader,
    AdminSequenceWarmLiveLoader? liveLoader,
    Duration Function(int attempt)? reconnectDelay,
    this.readRetryDelay = const Duration(milliseconds: 250),
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
  final Duration readRetryDelay;

  String? _scope;
  String? _profileRef;
  String? _preferredApparatusId;
  List<AdminApparatus>? _knownApparatus;
  bool _foreground = false;
  bool _disposed = false;
  bool _authorizationBlocked = false;
  int _generation = 0;
  final Set<Completer<void>> _activeReadCancellations = {};
  int _snapshotSerial = 0;
  int _leaseSerial = 0;
  final Set<int> _leases = {};
  AdminSequenceWarmSnapshot? _snapshot;
  Future<AdminSequenceWarmSnapshot?>? _preparing;
  final ValueNotifier<int> _pagesChanges = ValueNotifier(0);
  final Map<String, _AdminWarmPageEntry> _pages = {};
  final Set<Future<AdminProductionOrderPage?>> _priorityReads = {};
  final Set<Completer<void>> _activePageCancellations = {};
  final Set<String> _backgroundAttempts = {};
  final Set<Future<AdminProductionOrderPage?>> _backgroundReads = {};
  Completer<void> _backgroundWake = Completer<void>();
  bool _allowBackgroundOverlap = false;
  List<AdminProductionOrderPageRequest>? _moveRequests;
  Future<void>? _backgroundPreparation;
  bool _sequenceAttempted = false;
  int _pagesGeneration = 0;
  static const _maximumPageKeys = 12;
  final Map<Completer<void>, Timer> _readRetryWaits = {};
  StreamSubscription<AdminProductionMapLiveMessage>? _subscription;
  Timer? _reconnectTimer;
  Timer? _firstMessageTimer;
  int _streamGeneration = 0;
  int _reconnectAttempt = 0;
  bool _repairBudget = true;
  Future<void> _events = Future.value();
  Object? _lastError;

  Object? get lastError => _lastError;

  /// Lets mounted pages stage already downloaded rows before a tab is shown.
  /// Listening never starts a request or grants action authority.
  Listenable get pagesChanges => _pagesChanges;

  /// Compatibility for existing Orders observers.
  Listenable get ordersChanges => pagesChanges;

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
      _endReadGeneration();
      _cancelReadRetries();
      _snapshotSerial++;
      _stopLive();
      _scope = nextScope;
      _snapshot = null;
      _preparing = null;
      _knownApparatus = null;
      _clearPages();
      _preferredApparatusId = null;
      _authorizationBlocked = false;
      _leases.clear();
      _lastError = null;
      _reconnectAttempt = 0;
    }
    _profileRef = profileRef;
    _foreground = foreground;
    if (!_foreground || nextScope == null) {
      // An already started same-account read may populate RAM while paused.
      // Ownership is retired only on logout/account/auth changes; resume joins
      // that HTTP future instead of creating a duplicate transport request.
      _wakeBackground();
      _markStale();
      _stopLive();
      return;
    }
    if (!changed && !resumed) return;
    _repairBudget = true;
    if (resumed) _backgroundAttempts.clear();
    if (_snapshot != null) {
      _startLive();
      _warmPagesAfterSequence();
    } else {
      unawaited(prepare(nextScope));
    }
  }

  AdminSequenceWarmSnapshot? peek(String scope) =>
      scope == _scope && _owns(_generation) ? _snapshot : null;

  static const _ordersRequest = AdminProductionOrderPageRequest(view: 'orders');

  List<AdminApparatus>? peekApparatus(String scope) =>
      scope == _scope && _owns(_generation) ? _knownApparatus : null;

  AdminProductionOrderPage? peekOrders(String scope) =>
      peekPage(scope, _ordersRequest);

  Future<AdminProductionOrderPage?> prepareOrders(String scope) =>
      preparePage(scope, _ordersRequest);

  void rememberOrders(String scope, AdminProductionOrderPage page) =>
      rememberPage(scope, _ordersRequest, page);

  /// Only canonical, unsearched first-page requests participate in RAM warming.
  /// Request identity includes both apparatus IDs, so Move directions cannot
  /// share an unrelated response.
  static String? _pageKey(AdminProductionOrderPageRequest request) {
    if (request.search.isNotEmpty ||
        request.cursor != null ||
        request.ifVersion != null ||
        !const {'orders', 'move', 'closed', 'audit'}.contains(request.view)) {
      return null;
    }
    if (request.view == 'move') {
      if (request.apparatus.isEmpty ||
          request.target.isEmpty ||
          request.apparatus == request.target) {
        return null;
      }
    } else if (request.apparatus.isNotEmpty || request.target.isNotEmpty) {
      return null;
    }
    return jsonEncode([request.view, request.apparatus, request.target]);
  }

  AdminProductionOrderPage? peekPage(
      String scope, AdminProductionOrderPageRequest request) {
    if (scope != _scope || !_owns(_generation)) return null;
    final key = _pageKey(request);
    return key == null ? null : _pages[key]?.page;
  }

  /// Foreground demand starts immediately, even while sequence/catalog or a
  /// different background request is pending. Joining callers receive the very
  /// same future. Errors remain visible to explicit callers.
  Future<AdminProductionOrderPage?> preparePage(
      String scope, AdminProductionOrderPageRequest request,
      {bool prioritize = true}) {
    if (scope != _scope || !_owns(_generation)) return Future.value();
    final key = _pageKey(request);
    if (key == null) return Future.value();
    final entry = _pageEntry(key, request);
    if (entry.page != null) return Future.value(entry.page);
    final pending = entry.pending;
    if (pending != null) {
      if (prioritize) _observePriority(pending);
      return pending;
    }
    if (!_foreground) return Future.value();
    final generation = _generation;
    final pagesGeneration = _pagesGeneration;
    final serial = entry.serial;
    late final Future<AdminProductionOrderPage?> future;
    future = _readPage(generation, pagesGeneration, key, entry, serial)
        .whenComplete(() {
      if (identical(entry.pending, future)) entry.pending = null;
    });
    entry.pending = future;
    if (prioritize) _observePriority(future);
    return future;
  }

  void _observePriority(Future<AdminProductionOrderPage?> future) {
    if (!_priorityReads.add(future)) return;
    _wakeBackground();
    // Observe speculative errors immediately without changing the shared future
    // returned to an explicit caller.
    unawaited(future.then<void>((_) {
      if (_priorityReads.remove(future)) {
        _sequenceAttempted = true;
        if (_backgroundReads.isNotEmpty) _allowBackgroundOverlap = true;
      }
      _wakeBackground();
      _warmPagesAfterSequence();
    }, onError: (Object _, StackTrace __) {
      if (_priorityReads.remove(future)) {
        _sequenceAttempted = true;
        if (_backgroundReads.isNotEmpty) _allowBackgroundOverlap = true;
      }
      _wakeBackground();
      _warmPagesAfterSequence();
    }));
  }

  _AdminWarmPageEntry _pageEntry(
      String key, AdminProductionOrderPageRequest request) {
    final existing = _pages[key];
    if (existing != null) return existing;
    if (_pages.length >= _maximumPageKeys) {
      final retired = _pages.remove(_pages.keys.first)!;
      retired.serial++;
    }
    final entry = _AdminWarmPageEntry(request);
    _pages[key] = entry;
    return entry;
  }

  /// A screen's canonical page supersedes any earlier read without permitting
  /// stale responses, revisions, or retired server epochs to overwrite it.
  void rememberPage(String scope, AdminProductionOrderPageRequest request,
      AdminProductionOrderPage page) {
    if (scope != _scope || !_owns(_generation)) return;
    final key = _pageKey(request);
    if (key == null || !_validPage(request, page)) return;
    final entry = _pageEntry(key, request);
    if (entry.retiredEpochs.contains(page.epoch)) return;
    final current = entry.page;
    if (current != null &&
        current.epoch == page.epoch &&
        current.revision! > page.revision!) {
      return;
    }
    if (current != null && current.epoch != page.epoch) {
      entry.retiredEpochs.add(current.epoch);
    }
    entry.serial++;
    entry.page = page;
    _pagesChanges.value++;
  }

  static bool _validPage(AdminProductionOrderPageRequest request,
          AdminProductionOrderPage page) =>
      _validFirstPage(page) &&
      (request.view != 'orders' ||
          (page.isOrdersList &&
              page.scope.isNotEmpty &&
              page.wireValue?['projection'] == adminOrdersListProjection));

  Future<AdminProductionOrderPage?> _readPage(
      int generation,
      int pagesGeneration,
      String key,
      _AdminWarmPageEntry entry,
      int serial) async {
    bool ownsEntry() =>
        pagesGeneration == _pagesGeneration && identical(_pages[key], entry);
    final canceled = Completer<void>();
    _activePageCancellations.add(canceled);
    try {
      final page = await _readWithRetry(generation, () async {
        final page = await _pageLoader(entry.request);
        if (page == null || !_validPage(entry.request, page)) {
          throw const MobileApiException(
              code: 'order_page_invalid',
              message: 'Buyurtmalar sahifasi noto‘g‘ri. Qayta yuklang.');
        }
        return page;
      },
          isCurrent: () => ownsEntry() && serial == entry.serial,
          cancellation: canceled.future);
      if (!_owns(generation) || !ownsEntry()) return null;
      if (serial != entry.serial) return entry.page;
      if (page == null) return null;
      if (entry.retiredEpochs.contains(page.epoch)) return entry.page;
      entry.page = page;
      // A successful unrelated tab must not erase a failed Sequence diagnostic.
      if (_snapshot != null) _lastError = null;
      _pagesChanges.value++;
      return page;
    } catch (error) {
      if (!_owns(generation) || !ownsEntry()) return null;
      if (serial != entry.serial) return entry.page;
      _recordReadError(generation, error);
      rethrow;
    } finally {
      _activePageCancellations.remove(canceled);
    }
  }

  /// The route may supply a different currently selected Move pair. The two
  /// direction pages are independent entries and share foreground requests.
  void configureMoveRequests(
      String scope, List<AdminProductionOrderPageRequest> requests) {
    if (scope != _scope || !_owns(_generation)) return;
    final unique = <String, AdminProductionOrderPageRequest>{};
    for (final request in requests.take(2)) {
      final key = _pageKey(request);
      if (request.view == 'move' && key != null) unique[key] = request;
    }
    _moveRequests = List.unmodifiable(unique.values);
    _warmPagesAfterSequence();
  }

  List<AdminProductionOrderPageRequest> _backgroundRequests() {
    final configured = _moveRequests;
    final catalog = _knownApparatus ?? const <AdminApparatus>[];
    final printers = catalog.where((item) => item.isPechat).toList();
    final candidates = printers.isEmpty ? catalog : printers;
    final top = candidates.firstOrNull;
    final bottom = candidates.length > 1
        ? candidates[1]
        : catalog.where((item) => item.id != top?.id).firstOrNull;
    return [
      _ordersRequest,
      ...?configured,
      if (configured == null && top != null && bottom != null) ...[
        AdminProductionOrderPageRequest(
            view: 'move', apparatus: top.id, target: bottom.id),
        AdminProductionOrderPageRequest(
            view: 'move', apparatus: bottom.id, target: top.id),
      ],
      const AdminProductionOrderPageRequest(view: 'closed'),
      const AdminProductionOrderPageRequest(view: 'audit'),
    ];
  }

  void _warmPagesAfterSequence() {
    if (!_owns(_generation) ||
        !_foreground ||
        !_sequenceAttempted ||
        _backgroundPreparation != null) {
      return;
    }
    final generation = _generation;
    final pagesGeneration = _pagesGeneration;
    late final Future<void> future;
    future =
        _prepareBackgroundPages(generation, pagesGeneration).whenComplete(() {
      if (identical(_backgroundPreparation, future)) {
        _backgroundPreparation = null;
        // Catalog or Move selection may add keys between the runner's final
        // empty-queue check and this completion callback. Recheck once; an
        // empty queue must never create a recurring preparation loop.
        if (_owns(generation) &&
            _foreground &&
            pagesGeneration == _pagesGeneration &&
            _hasPendingBackgroundPages) {
          _warmPagesAfterSequence();
        }
      }
    });
    _backgroundPreparation = future;
    unawaited(future);
  }

  bool get _hasPendingBackgroundPages => _backgroundRequests().any((request) {
        final key = _pageKey(request)!;
        return !_backgroundAttempts.contains(key) && _pages[key]?.page == null;
      });

  void _wakeBackground() {
    final previous = _backgroundWake;
    _backgroundWake = Completer<void>();
    if (!previous.isCompleted) previous.complete();
  }

  Future<void> _waitBackgroundProgress() => Future.any<void>([
        _backgroundWake.future,
        ..._backgroundReads.map((future) =>
            future.then<void>((_) {}, onError: (Object _, StackTrace __) {})),
      ]);

  Future<void> _prepareBackgroundPages(
      int generation, int pagesGeneration) async {
    bool active() =>
        _owns(generation) && _foreground && pagesGeneration == _pagesGeneration;
    while (active()) {
      while (_priorityReads.isNotEmpty && active()) {
        await Future.wait(_priorityReads.toList().map((future) =>
            future.then<void>((_) {}, onError: (Object _, StackTrace __) {})));
      }
      if (!active()) return;
      // Normal warming is serial. A completed foreground demand can release a
      // replacement lane beside an already started slow background request;
      // at most two background reads are active, so remaining tabs still run.
      final capacity = _allowBackgroundOverlap ? 2 : 1;
      if (_backgroundReads.length >= capacity) {
        await _waitBackgroundProgress();
        continue;
      }
      AdminProductionOrderPageRequest? next;
      for (final request in _backgroundRequests()) {
        final key = _pageKey(request)!;
        if (!_backgroundAttempts.contains(key) && _pages[key]?.page == null) {
          next = request;
          break;
        }
      }
      if (next == null) return;
      _backgroundAttempts.add(_pageKey(next)!);
      final future = preparePage(_scope!, next, prioritize: false);
      _backgroundReads.add(future);
      unawaited(future.then<void>((_) {
        _backgroundReads.remove(future);
        if (_backgroundReads.isEmpty) _allowBackgroundOverlap = false;
        _wakeBackground();
      }, onError: (Object _, StackTrace __) {
        _backgroundReads.remove(future);
        if (_backgroundReads.isEmpty) _allowBackgroundOverlap = false;
        _wakeBackground();
      }));
      await _waitBackgroundProgress();
    }
  }

  void _suspendPageReads() {
    _pagesGeneration++;
    final reads = _activePageCancellations.toList();
    _activePageCancellations.clear();
    for (final read in reads) {
      if (!read.isCompleted) read.complete();
    }
    for (final entry in _pages.values) {
      entry.pending = null;
    }
    _backgroundPreparation = null;
    _priorityReads.clear();
    _backgroundReads.clear();
    _allowBackgroundOverlap = false;
    _wakeBackground();
  }

  void _clearPages() {
    _suspendPageReads();
    for (final entry in _pages.values) {
      entry.serial++;
    }
    _pages.clear();
    _backgroundAttempts.clear();
    _moveRequests = null;
    _sequenceAttempted = false;
    _pagesChanges.value++;
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
    final generation = _generation;
    future = _prepare(generation, _snapshotSerial).whenComplete(() {
      if (identical(_preparing, future)) _preparing = null;
      if (_owns(generation)) {
        _sequenceAttempted = true;
        _warmPagesAfterSequence();
      }
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
    final speculative = selected.then((id) =>
        id == null || id.isEmpty ? null : _readFirst(id, generation, serial));
    final apparatus = await catalog;
    final selectedId = await selected;
    if (!_owns(generation)) return null;
    if (apparatus == null || apparatus.isEmpty) return null;
    final remembered =
        apparatus.where((item) => item.id == selectedId).firstOrNull;
    final target = remembered ?? apparatus.first;
    final page = target.id == selectedId
        ? await speculative
        : await _readFirst(target.id, generation, serial);
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
    _sequenceAttempted = true;
    _startLive();
    _warmPagesAfterSequence();
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
      final apparatus = await _readWithRetry(generation, () async {
        final apparatus = await _apparatusLoader();
        if (apparatus.length > 200 ||
            apparatus.any((item) => item.id.trim().isEmpty) ||
            apparatus.map((item) => item.id).toSet().length !=
                apparatus.length) {
          throw StateError('Invalid warm apparatus catalog');
        }
        return List<AdminApparatus>.unmodifiable(apparatus);
      });
      if (_owns(generation) && apparatus != null) {
        _knownApparatus = apparatus;
        _pagesChanges.value++;
        _warmPagesAfterSequence();
      }
      return apparatus;
    } catch (error) {
      _recordReadError(generation, error);
      return null;
    }
  }

  Future<AdminProductionOrderPage?> _readFirst(
      String apparatus, int generation, int serial) async {
    if (!_owns(generation)) return null;
    try {
      return await _readWithRetry(generation, () async {
        final page = await _pageLoader(AdminProductionOrderPageRequest(
            view: 'sequence', apparatus: apparatus));
        if (page == null || !_validFirstPage(page)) {
          throw StateError('Invalid warm sequence page');
        }
        return page;
      }, isCurrent: () => serial == _snapshotSerial);
    } catch (error) {
      _recordReadError(generation, error);
      return null;
    }
  }

  /// One preparation gets at most three attempts, shared by all its callers.
  /// Only transient failures qualify. A new foreground transition or explicit
  /// navigation can start another preparation after the budget is exhausted.
  Future<T?> _readWithRetry<T>(int generation, Future<T> Function() read,
      {bool Function()? isCurrent, Future<void>? cancellation}) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (!_owns(generation) ||
          !_foreground ||
          (isCurrent != null && !isCurrent())) {
        return null;
      }
      try {
        // Retiring a session must release callers immediately, even if its
        // old HTTP transport takes longer to finish. Future.any observes late
        // errors too; ownership below still fences every eventual response.
        final canceled = Completer<void>();
        _activeReadCancellations.add(canceled);
        final T? value;
        try {
          value = await Future.any<T?>([
            read(),
            canceled.future.then<T?>((_) => null),
            if (cancellation != null) cancellation.then<T?>((_) => null),
          ]);
        } finally {
          _activeReadCancellations.remove(canceled);
          if (!canceled.isCompleted) canceled.complete();
        }
        return _owns(generation) && (isCurrent == null || isCurrent())
            ? value
            : null;
      } catch (error) {
        if (!_owns(generation) || (isCurrent != null && !isCurrent())) {
          return null;
        }
        if (!_foreground || attempt == 2 || !_isTransientReadError(error)) {
          rethrow;
        }
        final ready = Completer<void>();
        final timer = Timer(readRetryDelay * (attempt + 1), ready.complete);
        _readRetryWaits[ready] = timer;
        try {
          if (cancellation == null) {
            await ready.future;
          } else {
            await Future.any<void>([ready.future, cancellation]);
          }
        } finally {
          _readRetryWaits.remove(ready)?.cancel();
        }
      }
    }
    return null;
  }

  static bool _isTransientReadError(Object error) =>
      !_isAuthorizationError(error) &&
      (error is TimeoutException ||
          error is http.ClientException ||
          (error is MobileApiException &&
              (error.code == 'order_page_changed' ||
                  error.statusCode == 408 ||
                  error.statusCode == 429 ||
                  (error.statusCode ?? 0) >= 500)));

  void _endReadGeneration() {
    final reads = _activeReadCancellations.toList();
    _activeReadCancellations.clear();
    for (final read in reads) {
      if (!read.isCompleted) read.complete();
    }
  }

  void _cancelReadRetries() {
    final waits = Map.of(_readRetryWaits);
    _readRetryWaits.clear();
    for (final entry in waits.entries) {
      entry.value.cancel();
      if (!entry.key.isCompleted) entry.key.complete();
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
        _warmPagesAfterSequence();
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

  /// One bounded repair is allowed between validated stream baselines. A broken
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
    final page =
        await _readFirst(before.selectedApparatusId, generation, serial);
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
      _endReadGeneration();
      _cancelReadRetries();
      _snapshotSerial++;
      _snapshot = null;
      _knownApparatus = null;
      _clearPages();
      _stopLive();
    }
  }

  static Duration _defaultReconnectDelay(int attempt) {
    final bounded = attempt.clamp(0, 5);
    return Duration(seconds: bounded == 5 ? 30 : 1 << bounded);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _endReadGeneration();
    _cancelReadRetries();
    _snapshotSerial++;
    _stopLive();
    _scope = null;
    _snapshot = null;
    _knownApparatus = null;
    _preparing = null;
    _clearPages();
    _leases.clear();
    _pagesChanges.dispose();
  }
}

class _AdminWarmPageEntry {
  _AdminWarmPageEntry(this.request);

  final AdminProductionOrderPageRequest request;
  AdminProductionOrderPage? page;
  Future<AdminProductionOrderPage?>? pending;
  final Set<String> retiredEpochs = {};
  int serial = 0;
}
