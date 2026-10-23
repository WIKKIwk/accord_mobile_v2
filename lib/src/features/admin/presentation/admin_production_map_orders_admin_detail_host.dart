part of 'admin_production_map_orders_screen.dart';

/// Keeps a hydrated admin detail current without turning list summaries into
/// action authority. The child keeps its State and any unfinished form input.
class _AdminHydratedDetailHost extends StatefulWidget {
  const _AdminHydratedDetailHost({
    required this.initialSnapshot,
    required this.isCurrent,
    required this.currentCursor,
    required this.load,
    required this.builder,
  });

  final AdminApparatusQueueSnapshot? initialSnapshot;
  final bool Function() isCurrent;
  final ({String epoch, int revision})? Function() currentCursor;
  final Future<AdminApparatusQueueSnapshot?> Function() load;
  final Widget Function(AdminApparatusQueueSnapshot?,
      ValueNotifier<AdminApparatusQueueSnapshot?>, bool presentationAllowed) builder;

  @override
  State<_AdminHydratedDetailHost> createState() =>
      _AdminHydratedDetailHostState();
}

class _AdminHydratedDetailHostState extends State<_AdminHydratedDetailHost> {
  AdminApparatusQueueSnapshot? _snapshot;
  late final ValueNotifier<AdminApparatusQueueSnapshot?> _authority;
  bool _reading = false;
  bool _pending = false;
  bool _terminalReadDenied = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot;
    _authority = ValueNotifier(_snapshot);
    ProductionDataRevision.revision.addListener(_productionChanged);
    AppSession.instance.revision.addListener(_sessionChanged);
    // A push may land between the opening read and this route's first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _productionChanged();
    });
  }

  void _sessionChanged() {
    if (widget.isCurrent()) return;
    _generation++;
    _pending = false;
    _authority.value = null;
  }

  @override
  void didUpdateWidget(covariant _AdminHydratedDetailHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final initial = widget.initialSnapshot;
    if (_snapshot == null && initial != null) {
      _snapshot = initial;
      _authority.value = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _productionChanged();
      });
    }
  }

  void _productionChanged() {
    if (_snapshot == null ||
        !mounted ||
        !widget.isCurrent() ||
        !ProductionDataRevision.isCurrentScope) {
      return;
    }
    final cursor = widget.currentCursor();
    if (cursor == null) {
      _authority.value = null;
      return;
    }
    // A scoped detail can be newer than the list event that caused it. Do not
    // fetch it again merely because that event finally reaches the list.
    if (_authority.value != null &&
        _snapshot!.epoch == cursor.epoch &&
        (_snapshot!.revision ?? -1) >= cursor.revision) {
      return;
    }
    // Keep the rendered map/form, but never let an older action contract
    // authorize controls while the new scoped authority is still in flight.
    _authority.value = null;
    _pending = true;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_reading) return;
    _reading = true;
    final generation = _generation;
    try {
      while (_pending &&
          mounted &&
          widget.isCurrent() &&
          generation == _generation) {
        _pending = false;
        try {
          final next = await widget.load();
          if (!mounted || !widget.isCurrent() || generation != _generation) {
            return;
          }
          if (next == null) {
            _authority.value = null;
            return;
          }
          final cursor = widget.currentCursor();
          if (cursor == null ||
              next.epoch != cursor.epoch ||
              (next.revision ?? -1) < cursor.revision) {
            // A racing event will schedule its own read; failed/stale HTTP
            // responses never start a recurring refresh loop.
            _authority.value = null;
            continue;
          }
          if (_snapshot?.epoch == next.epoch &&
              (_snapshot?.revision ?? -1) > (next.revision ?? -1)) {
            continue;
          }
          _snapshot = next;
          _terminalReadDenied = false;
          _authority.value = next;
          setState(() {});
          final latest = widget.currentCursor();
          if (latest != null &&
              next.epoch == latest.epoch &&
              (next.revision ?? -1) >= latest.revision) {
            _pending = false;
          }
        } catch (error) {
          if (!mounted || generation != _generation) return;
          // Preserve rendered data, but withdraw stale action authority. A
          // later pushed revision or explicit reopen can retry the scoped read.
          _authority.value = null;
          if (error is MobileApiException &&
              (error.statusCode == 401 || error.statusCode == 403 ||
                  error.code == 'order_not_available')) {
            setState(() => _terminalReadDenied = true);
          }
        }
      }
    } finally {
      _reading = false;
    }
  }

  @override
  void dispose() {
    _generation++;
    ProductionDataRevision.revision.removeListener(_productionChanged);
    AppSession.instance.revision.removeListener(_sessionChanged);
    _authority.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(_snapshot, _authority, !_terminalReadDenied);
}
