part of 'admin_production_map_orders_screen.dart';

extension _ReadOnlyScannedWipHistory on _ReadOnlyOrderDetailSheetState {
  String get _scannedWipStage {
    final confirmed = _queueActionControl?.stageNodeId.trim() ?? '';
    if (confirmed.isNotEmpty) return confirmed;
    final nodes = widget.order.map.nodes
        .where((node) => node.apparatusId == widget.apparatus?.id)
        .toList(growable: false);
    return nodes.length == 1 ? nodes.single.id : '';
  }

  bool get _canReadScannedWips {
    final apparatus = widget.apparatus;
    final profile = AppSession.instance.profile;
    return widget.workerMode &&
        !widget.detailPending &&
        apparatus != null &&
        (apparatus.usesLaminationWorkflow || apparatus.operation == 'cut') &&
        profile?.role == UserRole.aparatchi &&
        AppSession.instance.can('apparatus.queue.read') &&
        profile!.assignedApparatus.contains(apparatus.id) &&
        _scannedWipStage.isNotEmpty;
  }

  Future<void> _showScannedWips() async {
    if (!_canReadScannedWips || _scannedWipSheetOpen || _queueActionBusy) {
      return;
    }
    final scope = currentSessionReadScope();
    final apparatus = widget.apparatus!.id;
    final orderId = widget.order.map.id;
    final stage = _scannedWipStage;
    _scannedWipSheetOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _ScannedWipHistorySheet(
          apparatus: apparatus,
          orderId: orderId,
          stageNodeId: stage,
          onMutationAttempted: () {
            if (!mounted || scope != currentSessionReadScope()) return;
            // Only a write (including a lost response) withdraws old authority.
            // Opening, reading, retrying and dismissing this history do not.
            // ignore: invalid_use_of_protected_member
            setState(() {
              _actionControlGeneration++;
              _queueActionControl = null;
              _mergeScanMode = false;
              _ignoreClosedQuickScanCallbacks = true;
              _seenQuickScanValues.clear();
            });
            unawaited(_refreshQueueActionControlAfterWrite());
          },
        ),
      );
    } finally {
      _scannedWipSheetOpen = false;
    }
  }
}

class _ScannedWipHistorySheet extends StatefulWidget {
  const _ScannedWipHistorySheet(
      {required this.apparatus,
      required this.orderId,
      required this.stageNodeId,
      required this.onMutationAttempted});
  final String apparatus, orderId, stageNodeId;
  final VoidCallback onMutationAttempted;
  @override
  State<_ScannedWipHistorySheet> createState() =>
      _ScannedWipHistorySheetState();
}

class _ScannedWipHistorySheetState extends State<_ScannedWipHistorySheet> {
  late final String _scope;
  List<AdminScannedWip> _items = const [];
  bool _loading = true;
  bool _failed = false;
  bool _writing = false;
  String _notice = '';
  int _generation = 0;
  bool get _scopeCurrent => _scope == currentSessionReadScope();
  bool _canReturn(AdminScannedWip item) =>
      AppSession.instance.can('apparatus.queue.manage') && item.canReturn;

  @override
  void initState() {
    super.initState();
    _scope = currentSessionReadScope();
    AppSession.instance.revision.addListener(_sessionChanged);
    unawaited(_load());
  }

  void _sessionChanged() {
    if (mounted && !_scopeCurrent) {
      setState(() {
        _items = const [];
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    AppSession.instance.revision.removeListener(_sessionChanged);
    super.dispose();
  }

  Future<void> _load() async {
    if (!_scopeCurrent) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
      _items = const [];
    });
    try {
      final items = await MobileApi.instance
          .adminScannedWips(
            apparatus: widget.apparatus,
            orderId: widget.orderId,
            stageNodeId: widget.stageNodeId,
          )
          .timeout(const Duration(seconds: 20));
      if (mounted && generation == _generation && _scopeCurrent) {
        setState(() => _items = items);
      }
    } catch (_) {
      if (mounted && generation == _generation && _scopeCurrent) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && generation == _generation && _scopeCurrent) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _returnWip(AdminScannedWip item) async {
    if (_writing || _loading || !_scopeCurrent || !_canReturn(item)) return;
    final confirmed = await showM3ConfirmDialog(
      context: context,
      title: context.l10n.productionText('worker.scanned_wip.return'),
      message:
          '${item.qrPayload}\n\n${context.l10n.productionText('worker.scanned_wip.confirm')}',
      cancelLabel: context.l10n.productionText('worker.cancel_start.back'),
      confirmLabel: context.l10n.productionText('worker.scanned_wip.return'),
      verticalActions: true,
      confirmButtonKey: const ValueKey('scanned-wip-return-confirm'),
      cancelButtonKey: const ValueKey('scanned-wip-return-cancel'),
    );
    if (confirmed != true || !mounted || !_scopeCurrent || _writing) return;
    setState(() {
      _writing = true;
      _notice = '';
    });
    var success = false;
    try {
      await MobileApi.instance
          .adminReturnScannedWip(
            apparatus: widget.apparatus,
            orderId: widget.orderId,
            stageNodeId: widget.stageNodeId,
            input: item,
          )
          .timeout(const Duration(seconds: 20));
      success = true;
    } catch (_) {
      // Reconcile instead of retrying a write whose response may have been lost.
    } finally {
      if (_scopeCurrent) widget.onMutationAttempted();
      if (mounted && _scopeCurrent) {
        setState(() {
          _writing = false;
          _notice = success
              ? 'worker.scanned_wip.success'
              : 'worker.scanned_wip.failed';
        });
        await _load();
      }
    }
  }

  String _stateLabel(AdminScannedWip item) => context.l10n.productionText(
      item.state != 'returned' && item.consumeState == 'unknown'
          ? 'worker.scanned_wip.unknown'
          : 'worker.scanned_wip.${item.state}');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_writing,
      child: SafeArea(
        child: SizedBox(
          key: const ValueKey('scanned-wip-history-sheet'),
          height: MediaQuery.sizeOf(context).height * .76,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          l10n.productionText('worker.scanned_wip.title'),
                          style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                      tooltip: l10n.retry,
                      key: const ValueKey('scanned-wip-history-refresh'),
                      onPressed:
                          _loading || _writing || !_scopeCurrent ? null : _load,
                      icon: const Icon(Icons.refresh_rounded)),
                  IconButton(
                      tooltip: l10n.productionText('worker.action.close'),
                      key: const ValueKey('scanned-wip-history-close'),
                      onPressed:
                          _writing ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded)),
                ])),
            if (_notice.isNotEmpty)
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(l10n.productionText(_notice),
                      key: const ValueKey('scanned-wip-history-notice'))),
            if (_writing) const LinearProgressIndicator(),
            Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _failed || !_scopeCurrent
                        ? Center(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                Text(l10n.productionText(
                                    'worker.scanned_wip.error')),
                                TextButton(
                                    onPressed: _scopeCurrent ? _load : null,
                                    child: Text(l10n.retry)),
                              ]))
                        : _items.isEmpty
                            ? Center(
                                child: Text(l10n.productionText(
                                    'worker.scanned_wip.empty')))
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                itemCount: _items.length + 1,
                                separatorBuilder: (_, index) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Text(
                                            l10n.productionText(
                                                'worker.scanned_wip.hint'),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall));
                                  }
                                  final item = _items[index - 1];
                                  final status = item.state;
                                  final icon = status == 'returned'
                                      ? Icons.undo_rounded
                                      : item.consumeState == 'consumed'
                                          ? Icons.check_circle_outline_rounded
                                          : status == 'active'
                                              ? Icons
                                                  .play_circle_outline_rounded
                                              : Icons.qr_code_rounded;
                                  final reason = item.blockedReason ==
                                          'work_recorded'
                                      ? 'worker.scanned_wip.work_recorded'
                                      : item.blockedReason == 'other_worker'
                                          ? 'worker.scanned_wip.other_worker'
                                          : 'worker.scanned_wip.unavailable';
                                  return Card.filled(
                                      child: ListTile(
                                    key: ValueKey(
                                        'scanned-wip-${item.sessionId}-${item.batchId}'),
                                    isThreeLine: true,
                                    leading: Icon(icon, color: scheme.primary),
                                    title: Text(
                                        item.qrPayload.isEmpty
                                            ? item.batchId
                                            : item.qrPayload,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    subtitle: Text([
                                      _stateLabel(item),
                                      [
                                        item.workerDisplayName,
                                        formatUnixSecondsLocalDateTime(
                                            item.linkedAtUnix)
                                      ]
                                          .where((text) => text.isNotEmpty)
                                          .join(' · '),
                                      if (!_canReturn(item) &&
                                          item.state != 'returned')
                                        l10n.productionText(reason),
                                    ].join('\n')),
                                    trailing: _canReturn(item)
                                        ? const Icon(Icons.undo_rounded)
                                        : null,
                                    onLongPress: !_writing && _canReturn(item)
                                        ? () => _returnWip(item)
                                        : null,
                                  ));
                                },
                              )),
          ]),
        ),
      ),
    );
  }
}
