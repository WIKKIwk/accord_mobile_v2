import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/session/session.dart';
import '../../../core/session/session_read_scope.dart';
import '../models/material_link_request.dart';
import 'material_link_request_card.dart';
import '../../../core/localization/urdu_aware_text.dart';

class MaterialLinkRequestPanel extends StatefulWidget {
  const MaterialLinkRequestPanel({
    super.key,
    required this.orderId,
    required this.apparatusId,
    required this.onMaterialsLinked,
  });
  final String orderId, apparatusId;
  final VoidCallback onMaterialsLinked;
  @override
  State<MaterialLinkRequestPanel> createState() =>
      _MaterialLinkRequestPanelState();
}

class _MaterialLinkRequestPanelState extends State<MaterialLinkRequestPanel>
    with WidgetsBindingObserver {
  Timer? _timer;
  MaterialLinkOverview? _overview;
  final Set<String> _seenMaterialChanges = {};
  Future<void>? _refreshing;
  bool _busy = false;
  bool _routeVisible = false;
  ModalRoute<dynamic>? _route;
  int _generation = 0;
  String _error = '';

  late Object _observedScope;

  Object get _scope => (
        currentSessionReadScope(),
        widget.orderId,
        widget.apparatusId,
      );

  bool get _canPoll {
    final state = WidgetsBinding.instance.lifecycleState;
    return (_route?.isCurrent ?? _routeVisible) &&
        !_busy &&
        (state == null || state == AppLifecycleState.resumed);
  }

  bool _isCurrent(Object scope, int generation) =>
      mounted && scope == _scope && generation == _generation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _observedScope = _scope;
    AppSession.instance.revision.addListener(_sessionChanged);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_canPoll) unawaited(_refresh());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    final visible = _route?.isCurrent ?? true;
    final becameVisible = visible && !_routeVisible;
    _routeVisible = visible;
    if (becameVisible && _canPoll) unawaited(_refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _canPoll) {
      // Route dependency rebuilds may have been deferred while paused. Mark
      // the current visibility now so the resume frame does not read twice.
      _routeVisible = _route?.isCurrent ?? true;
      unawaited(_refresh());
    }
  }

  @override
  void didUpdateWidget(covariant MaterialLinkRequestPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId ||
        oldWidget.apparatusId != widget.apparatusId) {
      _resetScope();
    }
  }

  void _sessionChanged() {
    if (_observedScope != _scope) _resetScope();
  }

  void _resetScope() {
    _observedScope = _scope;
    _generation++;
    _refreshing = null;
    setState(() {
      _overview = null;
      _seenMaterialChanges.clear();
      _error = '';
      _busy = false;
    });
    if (_canPoll) unawaited(_refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AppSession.instance.revision.removeListener(_sessionChanged);
    super.dispose();
  }

  Future<void> _refresh() {
    if (_refreshing case final pending?) return pending;
    late final Future<void> future;
    future = _readOverview().whenComplete(() {
      if (identical(_refreshing, future)) _refreshing = null;
    });
    _refreshing = future;
    return future;
  }

  Future<void> _readOverview() async {
    final scope = _scope;
    final generation = _generation;
    try {
      final overview = await MobileApi.instance.materialLinkRequests(
        orderId: widget.orderId,
        apparatus: widget.apparatusId,
      );
      if (!_isCurrent(scope, generation)) return;
      final changed = overview.requests
          .where((r) => r.status == 'approved' || r.status == 'stale')
          .map((r) => r.id)
          .toSet()
          .difference(_seenMaterialChanges);
      _seenMaterialChanges.addAll(changed);
      setState(() {
        _overview = overview;
        _error = '';
      });
      if (changed.isNotEmpty) widget.onMaterialsLinked();
    } catch (error) {
      if (_isCurrent(scope, generation)) {
        setState(
          () => _error = error is MobileApiException
              ? error.message
              : 'So‘rov holatini yangilab bo‘lmadi',
        );
      }
    }
  }

  // Invalidate any earlier poll before a mutation flow begins. Its late result
  // must not overwrite the authoritative post-write verification read.
  int _beginMutation() {
    _generation++;
    _refreshing = null;
    setState(() {
      _busy = true;
      _error = '';
    });
    return _generation;
  }

  Future<void> _send() async {
    if (_busy) return;
    final scope = _scope;
    final generation = _beginMutation();
    final orderId = widget.orderId;
    final apparatusId = widget.apparatusId;
    try {
      final overview = await MobileApi.instance.materialLinkRequests(
        orderId: orderId,
        apparatus: apparatusId,
      );
      if (!mounted || !_isCurrent(scope, generation)) return;
      setState(() => _overview = overview);
      if (overview.requests.any((r) => r.pending)) return;
      if (overview.candidates.isEmpty) {
        setState(
          () =>
              _error = 'Ulash mumkin bo‘lgan rulon qolmagan. Holatni yangilang',
        );
        return;
      }
      final selected = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => MaterialLinkRollPicker(
          rolls: overview.candidates,
          title: 'So‘rov yuboriladigan rulonlarni tanlang',
          submitLabel: 'So‘rov yuborish',
        ),
      );
      if (!_isCurrent(scope, generation) ||
          selected == null ||
          selected.isEmpty) {
        return;
      }
      await MobileApi.instance.createMaterialLinkRequests(
        orderId: orderId,
        apparatus: apparatusId,
        barcodes: selected,
      );
      if (!_isCurrent(scope, generation)) return;
      await _refresh();
    } catch (error) {
      if (!_isCurrent(scope, generation)) return;
      // Re-read after ambiguous transport errors; a committed request must not be duplicated.
      await _refresh();
      if (_isCurrent(scope, generation)) {
        setState(
          () => _error = error is MobileApiException
              ? error.message
              : 'So‘rov yuborilmadi. Holatni yangilang',
        );
      }
    } finally {
      if (_isCurrent(scope, generation)) {
        _routeVisible = _route?.isCurrent ?? true;
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _cancel(MaterialLinkRequest request) async {
    if (_busy) return;
    final scope = _scope;
    final generation = _beginMutation();
    try {
      await MobileApi.instance.decideMaterialLinkRequest(
        requestId: request.id,
        action: 'cancel',
      );
      if (!_isCurrent(scope, generation)) return;
      await _refresh();
    } catch (error) {
      if (_isCurrent(scope, generation)) {
        setState(
          () => _error =
              error is MobileApiException ? error.message : 'Aloqa uzildi',
        );
      }
    } finally {
      if (_isCurrent(scope, generation)) {
        _routeVisible = _route?.isCurrent ?? true;
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = _overview?.requests ?? const <MaterialLinkRequest>[];
    final latest = <String, MaterialLinkRequest>{};
    for (final request in requests) {
      latest.putIfAbsent(request.moverRef, () => request);
    }
    final pending = latest.values.any((r) => r.pending);
    final available = _overview?.candidates.isNotEmpty ?? false;
    if (!available && latest.isEmpty && _error.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (available) ...[
              UrduAwareText('Orderga ulanmagan rulonlar',
                  style: Theme.of(context).textTheme.titleSmall),
              UrduAwareText(
                  'Apparat oldidagi ${_overview!.candidates.length} ta mos rulondan keraklisini tanlab so‘rov yuboring'),
            ],
            for (final request in latest.values) ...[
              UrduAwareText('${request.moverName}: ${request.statusLabel}'),
              UrduAwareText('So‘ralgan rulonlar: '
                  '${request.rolls.map((roll) => roll.barcode).join(', ')}'),
              if (request.reason.isNotEmpty) Text(request.reason),
              if (request.pending)
                TextButton(
                  onPressed: _busy ? null : () => _cancel(request),
                  child: const UrduAwareText('So‘rovni bekor qilish'),
                ),
            ],
            if (_error.isNotEmpty) ...[
              Text(_error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              TextButton(
                  onPressed: _busy ? null : _refresh,
                  child: const UrduAwareText('Holatni yangilash')),
            ],
            if (available || pending)
              OutlinedButton.icon(
                onPressed: _busy || pending || !available ? null : _send,
                icon: const Icon(Icons.send_outlined),
                label: UrduAwareText(
                    pending ? 'Tasdiq kutilmoqda' : 'Ulash uchun so‘rov'),
              ),
            if (!available && !pending && latest.isNotEmpty)
              const UrduAwareText(
                  'Hozir bu orderga ulash mumkin bo‘lgan bo‘sh rulon yo‘q'),
          ],
        ));
  }
}
