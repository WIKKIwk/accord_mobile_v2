part of 'admin_production_map_orders_screen.dart';

/// Keeps a hydrated detail current without turning list summaries into action
/// authority. The child keeps its State and any unfinished form input.
class _AdminHydratedDetailHost extends StatefulWidget {
  const _AdminHydratedDetailHost({
    required this.initialSnapshot,
    required this.isCurrent,
    required this.currentCursor,
    required this.load,
    required this.builder,
    this.isAuthorityUsable,
  });

  final AdminApparatusQueueSnapshot? initialSnapshot;
  final bool Function() isCurrent;
  final ({String epoch, int revision})? Function() currentCursor;
  final Future<AdminApparatusQueueSnapshot?> Function() load;
  final bool Function(AdminApparatusQueueSnapshot)? isAuthorityUsable;
  final Widget Function(
      AdminApparatusQueueSnapshot?,
      ValueNotifier<AdminApparatusQueueSnapshot?>,
      bool presentationAllowed) builder;

  @override
  State<_AdminHydratedDetailHost> createState() =>
      _AdminHydratedDetailHostState();
}

class _AdminHydratedDetailHostState extends State<_AdminHydratedDetailHost>
    with WidgetsBindingObserver {
  AdminApparatusQueueSnapshot? _snapshot;
  late final ValueNotifier<AdminApparatusQueueSnapshot?> _authority;
  bool _reading = false;
  bool _pending = false;
  bool _terminalReadDenied = false;
  bool _foreground = true;
  int _generation = 0;
  int _recoveryAttempt = 0;
  Timer? _recoveryTimer;

  bool get _canRecover =>
      mounted &&
      _foreground &&
      !_terminalReadDenied &&
      widget.isCurrent() &&
      (ModalRoute.of(context)?.isActive ?? true);

  bool _usable(AdminApparatusQueueSnapshot snapshot) =>
      widget.isAuthorityUsable?.call(snapshot) ?? true;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _snapshot = widget.initialSnapshot;
    _authority = ValueNotifier(
        _snapshot != null && _usable(_snapshot!) ? _snapshot : null);
    WidgetsBinding.instance.addObserver(this);
    ProductionDataRevision.revision.addListener(_productionChanged);
    AppSession.instance.revision.addListener(_sessionChanged);
    // A push may land between the opening read and this route's first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _productionChanged();
    });
  }

  void _cancelRecovery() {
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
  }

  void _sessionChanged() {
    if (widget.isCurrent()) return;
    _generation++;
    _pending = false;
    _cancelRecovery();
    _authority.value = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _pending = false;
      _cancelRecovery();
      _authority.value = null;
    } else if (_canRecover) {
      _productionChanged();
    }
  }

  @override
  void didUpdateWidget(covariant _AdminHydratedDetailHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final initial = widget.initialSnapshot;
    if (_snapshot == null && initial != null) {
      _snapshot = initial;
      _authority.value = _usable(initial) ? initial : null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _productionChanged();
      });
    }
  }

  void _productionChanged() {
    if (_snapshot == null ||
        !_canRecover ||
        !ProductionDataRevision.isCurrentScope) {
      return;
    }
    final cursor = widget.currentCursor();
    if (_authority.value != null &&
        cursor != null &&
        _snapshot!.epoch == cursor.epoch &&
        (_snapshot!.revision ?? -1) >= cursor.revision) {
      return;
    }
    // Keep the map/form, but never reuse preceding action authority.
    _authority.value = null;
    _cancelRecovery();
    _recoveryAttempt = 0;
    _pending = true;
    unawaited(_drain());
  }

  void _recoverLater() {
    _pending = false;
    if (!_canRecover || _recoveryTimer != null) return;
    final index = _recoveryAttempt < _detailRecoveryRetryDelays.length
        ? _recoveryAttempt++
        : _detailRecoveryRetryDelays.length - 1;
    final generation = _generation;
    _recoveryTimer = Timer(_detailRecoveryRetryDelays[index], () {
      _recoveryTimer = null;
      if (!_canRecover || generation != _generation) return;
      _pending = true;
      unawaited(_drain());
    });
  }

  bool _denied(Object error) =>
      error is MobileApiException &&
      (error.statusCode == 401 ||
          error.statusCode == 403 ||
          const {'order_not_available', 'worker_order_not_available'}
              .contains(error.code));

  Future<void> _drain() async {
    if (_reading || !_canRecover) return;
    _reading = true;
    final generation = _generation;
    var reads = 0;
    try {
      while (_pending && _canRecover && generation == _generation) {
        if (reads++ == 2 ||
            (widget.currentCursor() == null &&
                widget.isAuthorityUsable == null)) {
          _recoverLater();
          break;
        }
        _pending = false;
        try {
          final next =
              await widget.load().timeout(_queueActionControlRefreshTimeout);
          if (!_canRecover || generation != _generation) return;
          final cursor = widget.currentCursor();
          if (next == null ||
              next.epoch.isEmpty ||
              next.revision == null ||
              (cursor != null &&
                  (next.epoch != cursor.epoch ||
                      next.revision! < cursor.revision)) ||
              !_usable(next) ||
              (_snapshot?.epoch == next.epoch &&
                  (_snapshot?.revision ?? -1) > (next.revision ?? -1))) {
            // A completed read can lose a race with a list update that has no
            // further push. Catch up now, then back off while this sheet is
            // still open; do not leave a settled read holding an empty lease.
            _authority.value = null;
            _pending = true;
            continue;
          }
          _snapshot = next;
          _recoveryAttempt = 0;
          _cancelRecovery();
          _authority.value = next;
          setState(() {});
          final latest = widget.currentCursor();
          _pending = latest == null
              ? widget.isAuthorityUsable == null
              : next.epoch != latest.epoch || next.revision! < latest.revision;
        } catch (error) {
          if (!mounted || !widget.isCurrent() || generation != _generation) {
            return;
          }
          _authority.value = null;
          if (_denied(error)) {
            _terminalReadDenied = true;
            _pending = false;
            _cancelRecovery();
            setState(() {});
            break;
          }
          final stale =
              error is MobileApiException && error.code == 'order_page_changed';
          if (reads < 2 && (_pending || stale)) {
            _pending = true;
            continue;
          }
          _recoverLater();
          break;
        }
      }
    } finally {
      _reading = false;
      if (mounted && generation == _generation) setState(() {});
    }
  }

  @override
  void dispose() {
    _generation++;
    _cancelRecovery();
    WidgetsBinding.instance.removeObserver(this);
    ProductionDataRevision.revision.removeListener(_productionChanged);
    AppSession.instance.revision.removeListener(_sessionChanged);
    _authority.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(_snapshot, _authority, !_terminalReadDenied);
}
