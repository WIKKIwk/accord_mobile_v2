part of 'admin_production_map_orders_screen.dart';

/// The modal exists before any detail read. A summary is display data only;
/// the full detail widget and its effects mount after the scoped read validates.
class _AdminInitialDetailHost extends StatefulWidget {
  const _AdminInitialDetailHost({
    required this.row,
    required this.isCurrent,
    required this.load,
    required this.onReady,
    required this.builder,
  });
  final AdminSequenceListRow row;
  final bool Function() isCurrent;
  final Future<AdminApparatusQueueSnapshot?> Function() load;
  final void Function(AdminApparatusQueueSnapshot) onReady;
  final Widget Function(AdminApparatusQueueSnapshot) builder;

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
    if (current && _snapshot != null) return widget.builder(_snapshot!);
    return _AdminSequenceDetailPreview(
      row: current ? widget.row : null,
      error:
          current ? _error : context.l10n.productionText('worker.error.sync'),
      onRetry: current && !_busy ? () => unawaited(_load()) : null,
    );
  }
}

class _AdminSequenceDetailPreview extends StatelessWidget {
  const _AdminSequenceDetailPreview(
      {required this.row, this.error, this.onRetry});
  final AdminSequenceListRow? row;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = row;
    final failure = error == null
        ? null
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(children: [
              Text(error!, style: theme.textTheme.bodyMedium),
              if (onRetry != null)
                TextButton.icon(
                  key: const ValueKey('admin-sequence-detail-retry'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.retry),
                ),
            ]),
          );
    Widget pending(String key, String label) => Padding(
          key: ValueKey('admin-sequence-detail-pending-$key'),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
            const SizedBox(width: 12),
            Semantics(
                label: context.l10n.loading,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(4)),
                  child: const SizedBox(width: 38, height: 12),
                )),
          ]),
        );
    return DraggableScrollableSheet(
      key: const ValueKey('admin-sequence-detail-preview'),
      expand: false,
      initialChildSize: .86,
      minChildSize: .86,
      maxChildSize: .86,
      builder: (context, controller) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Stack(children: [
          ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(4, 56, 4, 24),
            children: [
              if (item == null && failure != null) failure,
              if (item != null)
                _orderDetailSurfaceCard(
                    context: context,
                    child: Column(children: [
                      Row(children: [
                        AdminOrderImageThumb(
                          imageUrl: MobileApi.instance
                              .adminProductionMapOrderImageUrl(item.id,
                                  imageId: item.imageId),
                          displayName: item.title,
                          heroTag: 'production-order-cover-${item.id}',
                          dimension: 48,
                          previewOnLongPress: false,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  context.l10n
                                      .productionText('worker.order.code'),
                                  style: theme.textTheme.labelSmall),
                              Text(item.code,
                                  style: theme.textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              Text(
                                  [item.customerName, item.title]
                                      .where((s) => s.trim().isNotEmpty)
                                      .join(' • '),
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                            ])),
                      ]),
                      if (failure != null) failure,
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      pending(
                          'materials',
                          context.l10n
                              .productionText('worker.materials.pending')),
                      const Divider(height: 1),
                      pending(
                          'assigned-materials',
                          context.l10n
                              .productionText('worker.materials.attached')),
                      const Divider(height: 1),
                      pending('qolips',
                          context.l10n.productionText('worker.molds.attached')),
                    ])),
              if (item != null) ...[
                const SizedBox(height: 10),
                _orderDetailSurfaceCard(
                    context: context,
                    child: pending(
                        'summary',
                        context.l10n
                            .productionText('worker.summary.expected.title'))),
                const SizedBox(height: 10),
                _orderDetailSurfaceCard(
                    context: context,
                    child: pending('map',
                        context.l10n.productionText('worker.action.view_map'))),
              ],
            ],
          ),
          Positioned(
              top: 4,
              right: 4,
              child: IconButton.filledTonal(
                key: const ValueKey('admin-sequence-detail-close'),
                tooltip: context.l10n.productionText('worker.action.close'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              )),
        ]),
      ),
    );
  }
}
