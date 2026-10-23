import 'dart:async';
import 'dart:math';

import '../../features/shared/models/app_models.dart';
import '../api/mobile_api.dart';
import '../session/session_read_scope.dart';
import 'production_data_revision.dart';
import 'worker_queue_limit_store.dart';

/// A decoded, canonical read baseline. Never contains optimistic page writes.
class WorkerQueueWarmSnapshot {
  WorkerQueueWarmSnapshot({
    required this.snapshot,
    required List<AdminApparatus> apparatus,
  }) : apparatus = List.unmodifiable(apparatus);

  final AdminApparatusQueueSnapshot snapshot;
  final List<AdminApparatus> apparatus;
}

typedef WorkerQueueWarmLiveLoader = Stream<AdminProductionMapLiveMessage>
    Function(WorkerQueueWarmSnapshot baseline, int limit, String search);

/// One foreground worker window shared by home and the production page.
///
/// Home prepares typed rows and maintains them with the existing state-delta
/// protocol. Claiming transfers socket ownership to the page synchronously;
/// an unfinished initial read is joined rather than downloaded again. On exit
/// the page returns only a canonical baseline and this service resumes it.
/// Reconnect timers open sockets only. HTTP reconciliation is event driven.
class WorkerQueueWarmStore {
  WorkerQueueWarmStore({
    Future<AdminApparatusQueueSnapshot> Function(int, String)? snapshotLoader,
    Future<List<AdminApparatus>> Function()? apparatusLoader,
    WorkerQueueWarmLiveLoader? liveLoader,
    Future<int> Function(String)? limitLoader,
    String Function()? scopeReader,
    this.firstMessageTimeout = const Duration(seconds: 10),
    this.reconnectDelay,
  })  : _snapshotLoader = snapshotLoader ??
            ((limit, search) => MobileApi.instance
                .adminProductionMapQueueSnapshot(
                    workerScope: true, queueLimit: limit, queueSearch: search)),
        _apparatusLoader = apparatusLoader ??
            (() => MobileApi.instance.adminApparatus(limit: 200)),
        _liveLoader = liveLoader ??
            ((baseline, limit, search) => MobileApi.instance
                .adminProductionMapLiveStream(
                    stateDelta: true,
                    workerScope: true,
                    queueLimit: limit,
                    queueSearch: search,
                    epoch: baseline.snapshot.epoch,
                    revision: baseline.snapshot.revision,
                    scope: baseline.snapshot.scope)),
        _limitLoader = limitLoader ?? WorkerQueueLimitStore.load,
        _scopeReader = scopeReader ?? currentSessionReadScope;

  static final _instance = WorkerQueueWarmStore();
  static WorkerQueueWarmStore? debugOverride;
  static WorkerQueueWarmStore get instance => debugOverride ?? _instance;

  final Future<AdminApparatusQueueSnapshot> Function(int, String)
      _snapshotLoader;
  final Future<List<AdminApparatus>> Function() _apparatusLoader;
  final WorkerQueueWarmLiveLoader _liveLoader;
  final Future<int> Function(String) _limitLoader;
  final String Function() _scopeReader;
  final Duration firstMessageTimeout;
  final Duration Function(int)? reconnectDelay;
  String? _scope;
  int? _limit;
  String _search = '';
  WorkerQueueWarmSnapshot? _value;
  Future<void>? _starting;
  Future<WorkerQueueWarmSnapshot?>? _preparing;
  bool _foreground = false;
  bool _claimed = false;
  Object? _pageLease;
  bool _blocked = false;
  int _generation = 0;
  int _socketGeneration = 0;
  int _attempt = 0;
  int _repairBudget = 1;
  StreamSubscription<AdminProductionMapLiveMessage>? _subscription;
  Timer? _retry;
  Timer? _firstMessage;

  bool get _current => _scope != null && _scope == _scopeReader();
  bool get _canStream => _current && _foreground && !_claimed && !_blocked;
  Object? get pageLease => _pageLease;
  int? get preparedLimit =>
      _current && _value != null && _search.isEmpty ? _limit : null;

  WorkerQueueWarmSnapshot? peek({
    required String scope,
    required int queueLimit,
    String search = '',
  }) =>
      _matches(scope, queueLimit, search) ? _value : null;

  bool _matches(String scope, int limit, String search) =>
      _current && _scope == scope && _limit == limit && _search == search;

  Future<void> start({
    required String scope,
    required String preferenceAccount,
  }) {
    if (scope != _scopeReader()) return Future.value();
    if (_scope == scope) {
      resume();
      return _starting ?? Future.value();
    }
    reset();
    _scope = scope;
    _foreground = true;
    final generation = _generation;
    return _starting = _start(generation, preferenceAccount).whenComplete(() {
      if (_generation == generation) _starting = null;
    });
  }

  Future<void> _start(int generation, String account) async {
    var limit = WorkerQueueLimitStore.defaultLimit;
    try {
      final saved = await _limitLoader(account);
      if (WorkerQueueLimitStore.choices.contains(saved)) limit = saved;
    } catch (_) {
      // Optional preferences cannot block warming the normal worker window.
    }
    if (!_current || generation != _generation) return;
    _limit = limit;
    await _prepare(generation);
  }

  /// Detach background live immediately, then join any existing preparation.
  Future<WorkerQueueWarmSnapshot?> claim({
    required String scope,
    required int queueLimit,
    String search = '',
  }) async {
    if (scope != _scopeReader()) return null;
    if (_scope != scope) {
      // A worker queue can be the first route, before the app's post-frame
      // warm runtime starts. Reserve ownership before that runtime can launch
      // a duplicate background read or socket.
      reset();
      _scope = scope;
      _limit = queueLimit;
      _search = search;
    }
    _claimed = true;
    final lease = _pageLease = Object();
    _stopSocket();
    final generation = _generation;
    await _starting;
    if (generation != _generation ||
        !identical(lease, _pageLease) ||
        !_matches(scope, queueLimit, search)) {
      return null;
    }
    final value = _preparing == null ? _value : await _preparing;
    return generation == _generation && identical(lease, _pageLease)
        ? value
        : null;
  }

  /// Null means the page has unconfirmed writes or an invalid read contract.
  /// Never resume from the pre-navigation baseline in that case.
  void release({
    required String scope,
    required int queueLimit,
    String search = '',
    WorkerQueueWarmSnapshot? latest,
    Object? expectedLease,
  }) {
    if (!_current || _scope != scope) return;
    if (expectedLease != null && !identical(expectedLease, _pageLease)) return;
    _stopSocket();
    _generation++;
    _preparing = null;
    _starting = null;
    _limit = queueLimit;
    _search = search;
    _claimed = false;
    _pageLease = null;
    _repairBudget = 1;
    _value = latest != null && _usable(latest.snapshot) ? latest : null;
    if (!_canStream) return;
    if (_value == null) {
      unawaited(_prepare(_generation));
    } else {
      _connect();
    }
  }

  void pause() {
    _foreground = false;
    _stopSocket();
  }

  void resume() {
    if (!_foreground) _repairBudget = 1;
    _foreground = true;
    if (!_canStream || _starting != null || _preparing != null) return;
    if (_value != null) {
      if (_subscription == null && _retry == null) _connect();
    } else if (_limit != null) {
      unawaited(_prepare(_generation));
    }
  }

  void reset() {
    _generation++;
    _stopSocket();
    _scope = null;
    _limit = null;
    _search = '';
    _value = null;
    _starting = null;
    _preparing = null;
    _foreground = false;
    _claimed = false;
    _pageLease = null;
    _blocked = false;
    _attempt = 0;
    _repairBudget = 1;
  }

  bool _usable(AdminApparatusQueueSnapshot snapshot) =>
      snapshot.revision != null &&
      snapshot.epoch.isNotEmpty &&
      snapshot.scope.isNotEmpty;

  Future<WorkerQueueWarmSnapshot?> _prepare(int generation) {
    if (!_current || generation != _generation || _limit == null) {
      return Future.value(null);
    }
    return _preparing ??= _load(generation).whenComplete(() {
      if (generation == _generation) _preparing = null;
    });
  }

  Future<WorkerQueueWarmSnapshot?> _load(int generation) async {
    try {
      // Both start in the same turn; catalog latency must not add another RTT.
      final results = await Future.wait<Object>([
        _snapshotLoader(_limit!, _search),
        _apparatusLoader(),
      ], eagerError: true)
          .timeout(const Duration(seconds: 10));
      if (!_current || generation != _generation) return null;
      final snapshot = results[0] as AdminApparatusQueueSnapshot;
      snapshot.validateContract();
      if (!_usable(snapshot)) return null;
      final value = WorkerQueueWarmSnapshot(
          snapshot: snapshot, apparatus: results[1] as List<AdminApparatus>);
      _value = value;
      if (_canStream) _connect();
      return value;
    } catch (error) {
      if (generation == _generation && _authorizationError(error)) {
        _value = null;
        _blocked = true;
        _stopSocket();
      }
      // Page entry retains its normal explicit error/retry presentation.
      return null;
    }
  }

  void _connect() {
    if (!_canStream || _value == null || _limit == null) return;
    _stopSocket();
    final generation = _socketGeneration;
    final baseline = _value!;
    _firstMessage = Timer(firstMessageTimeout, () => _retrySocket(generation));
    try {
      _subscription = _liveLoader(baseline, _limit!, _search).listen(
        (message) {
          if (!_canStream || generation != _socketGeneration) return;
          _firstMessage?.cancel();
          _firstMessage = null;
          _apply(message);
        },
        onError: (Object error) {
          if (generation != _socketGeneration) return;
          if (_authorizationError(error)) {
            _value = null;
            _blocked = true;
            _stopSocket();
          } else {
            _retrySocket(generation);
          }
        },
        onDone: () => _retrySocket(generation),
      );
    } catch (error) {
      if (_authorizationError(error)) {
        _value = null;
        _blocked = true;
        _stopSocket();
      } else {
        _retrySocket(generation);
      }
    }
  }

  void _apply(AdminProductionMapLiveMessage message) {
    final before = _value;
    if (before == null) return;
    final snapshot = before.snapshot;
    try {
      if (message is AdminProductionMapLiveStateReady) {
        if (message.resync ||
            message.epoch != snapshot.epoch ||
            message.scope != snapshot.scope ||
            message.revision != snapshot.revision) {
          _reconcile();
        } else {
          _healthy();
        }
      } else if (message is AdminProductionMapLiveStateDelta) {
        if (message.epoch == snapshot.epoch &&
            message.scope == snapshot.scope &&
            message.revision <= snapshot.revision!) {
          return;
        }
        final next = message.applyTo(snapshot);
        _value = WorkerQueueWarmSnapshot(
            snapshot: _retainLiveExtras(next, snapshot, message.patch),
            apparatus: before.apparatus);
        _healthy();
      } else if (message is AdminProductionMapLiveSnapshot) {
        if (message.epoch == snapshot.epoch &&
            message.revision != null &&
            message.revision! < snapshot.revision!) {
          return;
        }
        message.validateContract();
        if (!_usable(message)) throw const FormatException('Missing cursor');
        _value = WorkerQueueWarmSnapshot(
            snapshot: message, apparatus: before.apparatus);
        _healthy();
      } else {
        // A legacy sequence-only delta cannot certify worker action controls.
        _reconcile();
      }
    } catch (_) {
      _reconcile();
    }
  }

  void _reconcile() {
    if (_repairBudget <= 0) {
      // A server that repeatedly rejects the same freshly read baseline must
      // not turn reconnects into an HTTP polling loop. Only a confirmed live
      // cursor, new foreground visit or page handoff grants another repair.
      _retrySocket(_socketGeneration);
      return;
    }
    _repairBudget--;
    _stopSocket();
    // One HTTP recovery per actual gap/resync. No periodic queue requests.
    unawaited(_prepare(_generation));
  }

  void _healthy() {
    _attempt = 0;
    _repairBudget = 1;
    final snapshot = _value?.snapshot;
    if (_current && snapshot != null && _usable(snapshot)) {
      ProductionDataRevision.notify(
          epoch: snapshot.epoch, revision: snapshot.revision!);
    }
  }

  void _retrySocket(int generation) {
    if (!_canStream || generation != _socketGeneration) return;
    _stopSocket();
    final attempt = _attempt++;
    final seconds = min(30, 1 << min(attempt, 5));
    final delay = reconnectDelay?.call(attempt) ??
        Duration(
            milliseconds:
                (seconds * 1000 * (0.5 + Random().nextDouble() / 2)).round());
    _retry = Timer(delay, () {
      _retry = null;
      _connect();
    });
  }

  void _stopSocket() {
    _socketGeneration++;
    _firstMessage?.cancel();
    _firstMessage = null;
    _retry?.cancel();
    _retry = null;
    final subscription = _subscription;
    _subscription = null;
    unawaited(subscription?.cancel());
  }

  bool _authorizationError(Object error) =>
      error is MobileApiException &&
      (error.statusCode == 401 ||
          error.statusCode == 403 ||
          const {'unauthorized', 'forbidden', 'permission_denied'}
              .contains(error.code));
}

/// State reducers deliberately return the base queue type. Retain actor-only
/// lists explicitly so a warm handoff never needs three additional reads.
AdminApparatusQueueSnapshot _retainLiveExtras(AdminApparatusQueueSnapshot next,
    AdminApparatusQueueSnapshot before, Map<String, dynamic> patch) {
  if (before is! AdminProductionMapLiveSnapshot) return next;
  return workerWarmLiveSnapshot(next,
      completed: patch['completed_orders'] == null
          ? before.completedOrders
          : [
              for (final raw in patch['completed_orders'] as List)
                AdminCompletedQueueOrder.fromJson(
                    (raw as Map).cast<String, dynamic>())
            ],
      requests: patch['completion_requests'] == null
          ? before.completionRequests
          : [
              for (final raw in patch['completion_requests'] as List)
                AdminCompletionRequestNotification.fromJson(
                    (raw as Map).cast<String, dynamic>())
            ],
      decisions: patch['completion_request_decisions'] == null
          ? before.completionRequestDecisions
          : [
              for (final raw in patch['completion_request_decisions'] as List)
                AdminCompletionRequestDecisionNotification.fromJson(
                    (raw as Map).cast<String, dynamic>())
            ]);
}

AdminProductionMapLiveSnapshot workerWarmLiveSnapshot(
  AdminApparatusQueueSnapshot snapshot, {
  required List<AdminCompletedQueueOrder> completed,
  required List<AdminCompletionRequestNotification> requests,
  required List<AdminCompletionRequestDecisionNotification> decisions,
}) =>
    AdminProductionMapLiveSnapshot(
      maps: snapshot.maps,
      sequences: snapshot.sequences,
      sequenceVersions: snapshot.sequenceVersions,
      sequenceRevisions: snapshot.sequenceRevisions,
      sequencePositionsByApparatus: snapshot.sequencePositionsByApparatus,
      visibleOrderIds: snapshot.visibleOrderIds,
      queueStates: snapshot.queueStates,
      queuePolicies: snapshot.queuePolicies,
      queueActionControls: snapshot.queueActionControls,
      stageStates: snapshot.stageStates,
      completedOrders: completed,
      completionRequests: requests,
      completionRequestDecisions: decisions,
      orderControls: snapshot.orderControls,
      stageOrderControls: snapshot.stageOrderControls,
      stageFreezeSupported: snapshot.stageFreezeSupported,
      earlyClosingOrderIds: snapshot.earlyClosingOrderIds,
      orderCustomers: snapshot.orderCustomers,
      orderStatuses: snapshot.orderStatuses,
      frozenOrdersByApparatus: snapshot.frozenOrdersByApparatus,
      revision: snapshot.revision,
      epoch: snapshot.epoch,
      scope: snapshot.scope,
      workerShowAllApparatusTabs: snapshot.workerShowAllApparatusTabs,
    );
