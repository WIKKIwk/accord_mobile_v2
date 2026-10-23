part of 'admin_production_map_orders_screen.dart';

/// Keeps the existing sheet mounted while its display-only summary is hydrated.
/// Only a validated scoped response enables detail effects and authority.
class _AdminInitialDetailHost extends StatefulWidget {
  const _AdminInitialDetailHost({
    required this.isCurrent,
    required this.load,
    required this.onReady,
    required this.builder,
  });
  final bool Function() isCurrent;
  final Future<AdminApparatusQueueSnapshot?> Function() load;
  final void Function(AdminApparatusQueueSnapshot) onReady;
  final Widget Function(AdminApparatusQueueSnapshot?, String?, VoidCallback?)
      builder;

  @override
  State<_AdminInitialDetailHost> createState() =>
      _AdminInitialDetailHostState();
}

class _AdminInitialDetailHostState extends State<_AdminInitialDetailHost> {
  AdminApparatusQueueSnapshot? _snapshot;
  String? _error;
  bool _busy = false;
  int _generation = 0;

  bool get _canLoad =>
      mounted &&
      widget.isCurrent() &&
      (ModalRoute.of(context)?.isActive ?? false);

  @override
  void initState() {
    super.initState();
    AppSession.instance.revision.addListener(_sessionChanged);
    // Paint the existing row identity before detail decode or section startup
    // can compete with the opening animation's first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  void _sessionChanged() {
    if (!mounted || widget.isCurrent()) return;
    _generation++;
    setState(() {
      _snapshot = null;
      _busy = false;
    });
  }

  Future<void> _load() async {
    if (_busy || !_canLoad) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final snapshot = await widget.load();
      if (!mounted || !_canLoad || generation != _generation) return;
      if (snapshot == null) {
        throw MobileApiException(
            code: 'order_detail_unavailable',
            message: context.l10n.productionText('worker.error.sync'));
      }
      widget.onReady(snapshot);
      setState(() => _snapshot = snapshot);
    } catch (error) {
      if (!mounted || !_canLoad || generation != _generation) return;
      setState(() => _error = error is MobileApiException
          ? error.message
          : context.l10n.adminText('production.open_failed'));
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    AppSession.instance.revision.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.isCurrent();
    if (!current) {
      return Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.productionText('worker.action.close')),
        ),
      );
    }
    return widget.builder(
        _snapshot, _error, !_busy ? () => unawaited(_load()) : null);
  }
}
