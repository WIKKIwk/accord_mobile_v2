part of 'admin_production_map_orders_screen.dart';

class _RezkaMasterOrdersPage extends StatefulWidget {
  const _RezkaMasterOrdersPage({
    super.key,
    required this.active,
    required this.searchQuery,
    required this.apparatusCatalog,
    required this.bottomPadding,
    required this.loadPage,
    required this.onOpenSettings,
  });

  final bool active;
  final String searchQuery;
  final List<AdminApparatus> apparatusCatalog;
  final double bottomPadding;
  final AdminProductionOrderPageLoader loadPage;
  final Future<void> Function(ProductionMapDefinition, bool) onOpenSettings;

  @override
  State<_RezkaMasterOrdersPage> createState() => _RezkaMasterOrdersPageState();
}

class _RezkaMasterOrdersPageState extends State<_RezkaMasterOrdersPage>
    with AutomaticKeepAliveClientMixin {
  final _scope = currentSessionReadScope();
  late _AdminOrderWindow _window;
  Timer? _searchDebounce;
  bool _openingSettings = false;
  bool _loadingSettings = false;

  @override
  bool get wantKeepAlive => true;

  String get _search =>
      String.fromCharCodes(widget.searchQuery.trim().runes.take(120));

  _AdminOrderWindow _windowFor(String search) => _AdminOrderWindow(
        AdminProductionOrderPageRequest(view: 'orders', search: search),
        _scope,
        '',
      );

  bool get _current => mounted && _scope == currentSessionReadScope();

  @override
  void initState() {
    super.initState();
    _window = _windowFor(_search);
    if (widget.active) unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _RezkaMasterOrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery == oldWidget.searchQuery &&
        widget.active == oldWidget.active) return;
    _searchDebounce?.cancel();
    if (!widget.active) return;
    final search = _search;
    if (_window.request.search != search) {
      _searchDebounce = Timer(const Duration(milliseconds: 350), () {
        if (!_current || !widget.active) return;
        setState(() => _window = _windowFor(search));
        unawaited(_load());
      });
    } else if (!oldWidget.active) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    final window = _window;
    if (!_current || !widget.active || (append && window.cursor == null))
      return;
    if (window.inFlight case final pending?) return pending;
    final read = _read(window, append: append);
    setState(() {
      window.inFlight = read;
    });
    try {
      await read;
    } finally {
      if (_current && identical(_window, window)) {
        setState(() => window.inFlight = null);
      }
    }
  }

  Future<void> _read(_AdminOrderWindow window, {required bool append}) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final page = await widget.loadPage(AdminProductionOrderPageRequest(
          view: 'orders',
          search: window.request.search,
          cursor: append ? window.cursor : null,
          ifVersion: !append && attempt == 0
              ? window.pages.firstOrNull?.version
              : null,
        ));
        if (!_current || !identical(_window, window)) return;
        if (page != null) {
          if (!page.isOrdersList ||
              page.offset != (append ? window.length : 0) ||
              (append && page.version != window.pages.first.version)) {
            throw const MobileApiException(
              code: 'order_page_changed',
              message: 'Buyurtmalar yangilandi. Qayta yuklang.',
            );
          }
          window.pages = [if (append) ...window.pages, page];
        }
        window.error = null;
        return;
      } catch (error) {
        if (!_current || !identical(_window, window)) return;
        if (attempt == 0 &&
            error is MobileApiException &&
            error.code == 'order_page_changed') {
          append = false;
          continue;
        }
        if (error is MobileApiException &&
            (error.statusCode == 401 || error.statusCode == 403)) {
          window.pages = [];
        }
        window.error = error is MobileApiException
            ? error.message
            : context.l10n.adminText('production.open_failed');
        return;
      }
    }
  }

  Future<void> _openSettings(ProductionMapSaved order) async {
    if (!_current || !widget.active || _openingSettings) return;
    _openingSettings = true;
    setState(() => _loadingSettings = true);
    try {
      final settings =
          await MobileApi.instance.rezkaMasterOrderSettings(order.map.id);
      if (!_current || !widget.active) return;
      setState(() => _loadingSettings = false);
      await widget.onOpenSettings(
        order.map.copyWith(
          standardPrintSide: settings.standardPrintSide,
          duplicateRezkaLabels: settings.duplicateLabels,
          includeBobinaInNet: settings.includeBobina,
        ),
        settings.canEditWorkOptions,
      );
    } catch (error) {
      if (!_current || !widget.active) return;
      final message = error is MobileApiException &&
              error.code != 'map_not_found'
          ? error.message
          : context.l10n.adminText('rezka_master.order_settings_unavailable');
      showAdminTopNotice(context, message, tone: AdminTopNoticeTone.error);
    } finally {
      _openingSettings = false;
      if (_current && _loadingSettings) setState(() => _loadingSettings = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final window = _window;
    final orders = window.orders;
    return Column(
      children: [
        if (window.inFlight != null || _loadingSettings)
          const _OrdersConnectionProgress(),
        Expanded(
          child: _AdminOrderPageViewport(
            key: ValueKey(window),
            window: window,
            onMore: () => unawaited(_load(append: true)),
            onRetry: () => unawaited(_load()),
            child: RefreshIndicator(
              onRefresh: _load,
              child: _OrdersModulePage(
                physics: const AlwaysScrollableScrollPhysics(),
                orders: orders,
                visibleOrders: orders,
                orderRows: {for (final page in window.pages) ...page.orderRows},
                pendingRows: [
                  for (final page in window.pages)
                    for (final id in page.pendingIds) page.pendingRows[id]!,
                ],
                apparatusCatalog: widget.apparatusCatalog,
                bottomPadding: widget.bottomPadding,
                customerNameByMapId: const {},
                orderStatusesByOrderId: const {},
                orderControlsByOrderId: const {},
                queueStatesByApparatus: const {},
                stageStatesByOrderId: const {},
                queueActionControlsByApparatus: const {},
                visibleOrderIdsByApparatus: const {},
                onInfoOrder: null,
                onLongPressOrder: (order) => unawaited(_openSettings(order)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
