part of 'admin_production_map_orders_screen.dart';

enum _WorkerWipScanPurpose { start, merge, materialIntake, context }

class _ScannedWorkerWip {
  const _ScannedWorkerWip({this.progress, this.opening, this.openingRecord});
  final AdminProgressBatch? progress;
  final AdminOpeningWipBatch? opening;
  final AdminOpeningWipRecord? openingRecord;
  String get orderId => (progress?.orderId ?? opening!.orderId).trim();
  String get status =>
      (progress?.wipStatus ?? opening!.wipStatus).trim().toLowerCase();
  String get usedBy {
    final explicit =
        (progress?.usedByApparatus ?? opening!.usedByApparatus).trim();
    return explicit.isNotEmpty
        ? explicit
        : progress?.currentApparatus.trim() ?? '';
  }

  String get qrPayload => progress?.qrPayload ?? opening!.qrPayload;
  String get batchId => progress?.batchId ?? opening!.batchId;
  String get label => (progress?.labelItemName ?? opening!.labelItemName)
      .split(RegExp(r',?\s*apparat:', caseSensitive: false))
      .first
      .trim();
}

Future<_ScannedWorkerWip?> _identifyWorkerWip(String qr) async {
  try {
    return _ScannedWorkerWip(
        progress: await MobileApi.instance
            .adminProgressQrLookup(qr, requireActiveOrder: true));
  } on MobileApiException catch (error) {
    if (!const {'progress_batch_not_found', 'progress_qr_not_found'}
        .contains(error.code)) {
      rethrow;
    }
    try {
      final record = await MobileApi.instance.adminOpeningWipQrReport(qr);
      final batch = record.batches
          .where((batch) =>
              batch.qrPayload.trim().toUpperCase() == qr.trim().toUpperCase() ||
              batch.batchId.trim() == qr.trim())
          .firstOrNull;
      if (batch == null) return null;
      if (batch.orderId.trim().isEmpty ||
          record.intake.orderId.trim() != batch.orderId.trim() ||
          record.intake.status.trim().toLowerCase() != 'confirmed') {
        throw const MobileApiException(
            code: 'progress_qr_invalid_response', message: '');
      }
      if (!const {'waiting', 'in_use', 'processed', 'void'}
          .contains(batch.wipStatus.trim().toLowerCase())) {
        throw const MobileApiException(
            code: 'progress_qr_invalid_response', message: '');
      }
      return _ScannedWorkerWip(opening: batch, openingRecord: record);
    } on MobileApiException catch (openingError) {
      if (openingError.statusCode == 404 ||
          const {
            'opening_wip_qr_not_found',
            'opening_wip_not_found',
            'opening_wip_qr_mismatch',
            'progress_batch_not_found',
            'not_found'
          }.contains(openingError.code)) {
        return null;
      }
      rethrow;
    }
  }
}

List<String> _workerWipConsumerIds(
    _ScannedWorkerWip wip, ProductionMapDefinition? map,
    {String consumerStageNodeId = ''}) {
  final progress = wip.progress;
  if (progress != null) {
    if (progress.hasInputRouteMetadata && consumerStageNodeId.isEmpty) {
      return progress.inputRoute?.consumerApparatusIds ?? const [];
    }
    if (map == null) return const [];
    return productionMapWipConsumerIds(
        map: map,
        nextApparatus:
            progress.hasInputRouteMetadata ? '' : progress.nextApparatus,
        nextStageNodeId: progress.inputRoute?.stageNodeId ??
            progress.payloadJson['next_stage_node_id']?.toString() ??
            '',
        consumerStageNodeId: consumerStageNodeId);
  }
  final intake = wip.openingRecord!.intake;
  if (intake.sourceApparatus.trim().isEmpty) {
    if (map == null) return [intake.resumeApparatus];
    return productionMapWipConsumerIds(
        map: map,
        nextApparatus: intake.resumeApparatus,
        nextStageNodeId: intake.resumeStageNodeId,
        consumerStageNodeId: consumerStageNodeId);
  }
  if (map == null) return const [];
  final stages = productionMapNextWorkStagesForNode(
      map: map, stageNodeId: intake.sourceStageNodeId);
  return stages
      .where((stage) =>
          consumerStageNodeId.isEmpty ||
          productionMapWipConsumerIds(
                  map: map,
                  nextApparatus: stage.apparatusId ?? '',
                  nextStageNodeId: stage.nodeId,
                  consumerStageNodeId: consumerStageNodeId)
              .contains(stage.apparatusId))
      .map((stage) => stage.apparatusId ?? '')
      .where((id) => id.isNotEmpty)
      .toList();
}

extension _ReadOnlyWorkerWipScan on _ReadOnlyOrderDetailSheetState {
  Future<void> _showWipScanGuidance(String message) async {
    if (!mounted || _wipGuidanceOpen) return;
    _updateWipScanState(() {
      _wipScanHandled = true;
      _wipGuidanceOpen = true;
      _quickScanStatus = message;
    });
    _showQuickScanFeedback(ProductionQuickScanFeedback.rejected);
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('production-wip-guidance-dialog'),
          scrollable: true,
          title: Text(context.l10n.productionText('worker.qr.guidance.title')),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.productionText('worker.action.close')),
            )
          ],
        ),
      );
    } finally {
      if (mounted) _updateWipScanState(() => _wipGuidanceOpen = false);
    }
  }

  Future<String> _currentWipScanGuidance() async {
    final control = await _loadCurrentQueueActionControl();
    if (!mounted) return '';
    _updateWipScanState(() => _queueActionControl = control);
    final labels = _unavailableBusyLabels();
    if (_queueActionContractSynchronized && control?.allows('start') == true) {
      return context.l10n.productionText('worker.qr.start_ready', values: {
        'apparatus': canonicalApparatusDisplayLabel(
            widget.apparatus?.id ?? '', widget.apparatusCatalog),
        'order': _busyOrderDisplayLabel(widget.order, context.l10n),
      });
    }
    return _workerQrExistingOrderText(
      l10n: context.l10n,
      control: control,
      orderControlState: _orderControlState,
      queueState: _queueStates[widget.order.map.id.trim()],
      apparatusLabel: canonicalApparatusDisplayLabel(
          widget.apparatus?.id ?? '', widget.apparatusCatalog),
      orderLabel: _busyOrderDisplayLabel(widget.order, context.l10n),
      usesRollJoining: (widget.apparatus?.usesLaminationWorkflow ?? false) ||
          widget.apparatus?.operation == 'cut',
      busyOrderLabel: labels.order,
    );
  }

  Future<_ScannedWorkerWip?> _checkWorkerWipScan(
    String qr,
    _WorkerWipScanPurpose purpose, {
    _ScannedWorkerWip? identified,
  }) async {
    final openedId = widget.order.map.id.trim();
    _wipScanHandled = false;
    final openedStation = widget.apparatus?.id.trim() ?? '';
    final scope = currentSessionReadScope();
    final wip = identified ?? await _identifyWorkerWip(qr);
    if (!mounted ||
        scope != currentSessionReadScope() ||
        !_materialContextIsCurrent(openedId, openedStation)) {
      return null;
    }
    if (wip == null) {
      if (purpose == _WorkerWipScanPurpose.merge ||
          purpose == _WorkerWipScanPurpose.context) {
        await _showWipScanGuidance(
            context.l10n.productionText('worker.qr.not_found'));
      }
      return null;
    }
    _wipScanHandled = true;
    final snapshot = await MobileApi.instance
        .adminProductionMapQueueSnapshot(
            fresh: true, workerScope: widget.workerMode)
        .timeout(_queueActionControlRefreshTimeout);
    if (!mounted ||
        scope != currentSessionReadScope() ||
        !_materialContextIsCurrent(openedId, openedStation)) {
      return null;
    }
    final openedControl =
        snapshot.queueActionControls[openedStation]?[openedId];
    final openedOrderControl = snapshot.orderControlFor(openedId);
    final openedQueueState = snapshot.queueStates[openedStation]?[openedId];
    if (openedControl?.isConsistentWith(openedOrderControl,
            queueState: openedQueueState) ==
        true) {
      final detailed = snapshot.revision != null && snapshot.epoch.isNotEmpty
          ? AdminPrintPreflightControlState(
              apparatus: openedStation,
              orderId: openedId,
              revision: snapshot.revision!,
              epoch: snapshot.epoch,
              control: openedControl!,
              queueState: openedQueueState ?? '',
              stageStates: snapshot.stageStates[openedId] ?? const {},
              orderControl: openedOrderControl)
          : null;
      if ((detailed == null && _pendingDetailRevision != null) ||
          (detailed != null && !_liveAllowsDetailControl(detailed))) {
        throw const MobileApiException(
            code: 'order_scan_bootstrap_stale', message: '');
      }
      _updateWipScanState(() {
        _queueStates = Map<String, String>.from(
            snapshot.queueStates[openedStation] ?? const {});
        _stageStates = Map<String, String>.from(
            snapshot.stageStates[openedId] ?? const {});
        _orderControlState = openedOrderControl;
        _orderControls =
            Map<String, AdminOrderControlState>.from(snapshot.orderControls);
        if (detailed != null) {
          _applyDetailControl(detailed);
        } else {
          _queueActionControl = openedControl;
        }
      });
    } else {
      _updateWipScanState(() => _queueActionControl = null);
    }
    final sameOrder = wip.orderId == openedId;
    final targetMap = sameOrder
        ? widget.order
        : snapshot.maps
            .where((order) => order.map.id.trim() == wip.orderId)
            .firstOrNull;
    final orderLabel = targetMap != null
        ? _busyOrderDisplayLabel(targetMap, context.l10n)
        : widget.busyOrderTitleLookup?.call(wip.orderId)?.trim() ?? wip.label;
    final progress = wip.progress;
    final candidates = _workerWipConsumerIds(wip, targetMap?.map);
    final assigned =
        AppSession.instance.profile?.assignedApparatus ?? const <String>[];
    final preferred = candidates.contains(openedStation)
        ? openedStation
        : candidates.where((id) => assigned.contains(id)).firstOrNull ?? '';
    final stationId = wip.status == 'in_use' && wip.usedBy.isNotEmpty
        ? wip.usedBy
        : preferred;
    final station = widget.apparatusCatalog
        .where((station) => station.id == stationId)
        .firstOrNull;
    final orderControl = snapshot.orderControlFor(wip.orderId);
    final control = snapshot.queueActionControls[stationId]?[wip.orderId];
    final queueState = snapshot.queueStates[stationId]?[wip.orderId];
    String guidance;
    if (orderControl == AdminOrderControlState.frozen) {
      guidance = _workerFrozenOrderMessage(context.l10n, orderLabel);
    } else if (orderControl == AdminOrderControlState.freezeRequested) {
      guidance = context.l10n.productionText('worker.qr.freeze_requested');
    } else if (wip.status == 'processed' || wip.status == 'void') {
      guidance = context.l10n.productionText(wip.status == 'void'
          ? 'worker.qr.roll_void'
          : 'worker.error.wip_used');
    } else if ((progress?.inputRouteError ?? '').isNotEmpty) {
      throw MobileApiException(code: progress!.inputRouteError, message: '');
    } else if (wip.status == 'in_use' &&
        station != null &&
        !_isAssignedWatchApparatus(station, assignedApparatus: assigned)) {
      guidance =
          '${context.l10n.productionText('worker.qr.roll_in_use', values: {
            'apparatus': canonicalApparatusDisplayLabel(
                stationId, widget.apparatusCatalog),
            'order': orderLabel,
          })} ${context.l10n.productionText('worker.error.assigned_machine')}';
    } else if (station == null ||
        !_isAssignedWatchApparatus(station, assignedApparatus: assigned)) {
      guidance = context.l10n.productionText('worker.error.assigned_machine');
    } else if (control?.isConsistentWith(orderControl,
            queueState: queueState) !=
        true) {
      guidance = context.l10n.productionText('worker.error.sync');
    } else {
      final busyId = snapshot.queueActionControls[stationId]?.entries
          .where((entry) =>
              entry.key != wip.orderId &&
              entry.value.isConsistentWith(snapshot.orderControlFor(entry.key),
                  queueState: snapshot.queueStates[stationId]?[entry.key]) &&
              const {
                AdminQueueInteractionMode.inProgress,
                AdminQueueInteractionMode.freezeRequested
              }.contains(entry.value.interaction?.mode))
          .firstOrNull
          ?.key;
      final busyLabel = busyId == null
          ? ''
          : widget.busyOrderTitleLookup?.call(busyId) ??
              snapshot.maps
                  .where((order) => order.map.id == busyId)
                  .firstOrNull
                  ?.map
                  .title ??
              '';
      guidance = control!.allows('start')
          ? context.l10n.productionText('worker.qr.start_ready', values: {
              'apparatus': canonicalApparatusDisplayLabel(
                  stationId, widget.apparatusCatalog),
              'order': orderLabel
            })
          : _workerQrExistingOrderText(
              l10n: context.l10n,
              control: control,
              orderControlState: orderControl,
              queueState: queueState,
              apparatusLabel: canonicalApparatusDisplayLabel(
                  stationId, widget.apparatusCatalog),
              orderLabel: orderLabel,
              usesRollJoining:
                  station.usesLaminationWorkflow || station.operation == 'cut',
              busyOrderLabel: busyLabel);
      if (wip.status == 'in_use') {
        guidance =
            context.l10n.productionText('worker.qr.roll_in_use', values: {
          'apparatus': canonicalApparatusDisplayLabel(
              stationId, widget.apparatusCatalog),
          'order': orderLabel,
        });
        if (control.allows('resume')) {
          guidance +=
              ' ${context.l10n.productionText('worker.qr.resume_loaded_roll', values: {
                'action': context.l10n.productionText('worker.action.resume')
              })}';
        } else if (control.interaction?.mode ==
            AdminQueueInteractionMode.inProgress) {
          guidance +=
              ' ${context.l10n.productionText('worker.qr.loaded_active')}';
        } else {
          guidance +=
              ' ${_workerQrExistingOrderText(l10n: context.l10n, control: control, orderControlState: orderControl, queueState: queueState, apparatusLabel: canonicalApparatusDisplayLabel(stationId, widget.apparatusCatalog), orderLabel: orderLabel, usesRollJoining: false, busyOrderLabel: busyLabel)}';
        }
      }
      if (sameOrder &&
          stationId == openedStation &&
          wip.status == 'waiting' &&
          ((purpose == _WorkerWipScanPurpose.start &&
                  control.allows('start')) ||
              (purpose == _WorkerWipScanPurpose.merge &&
                  control.allows('merge')))) {
        if (progress != null && progress.inputRouteError.isNotEmpty) {
          throw MobileApiException(code: progress.inputRouteError, message: '');
        }
        final validated = progress != null
            ? _ScannedWorkerWip(
                progress: await MobileApi.instance.adminProgressQrLookup(qr,
                    apparatus: openedStation,
                    orderId: openedId,
                    requireActiveOrder: true))
            : _ScannedWorkerWip(
                opening: await MobileApi.instance.adminLookupOpeningWip(
                    apparatus: openedStation, orderId: openedId, qrPayload: qr),
                openingRecord: wip.openingRecord);
        if (!mounted ||
            scope != currentSessionReadScope() ||
            !_materialContextIsCurrent(openedId, openedStation)) {
          return null;
        }
        if (validated.orderId != openedId ||
            validated.batchId != wip.batchId ||
            validated.qrPayload.trim() != wip.qrPayload.trim()) {
          throw const MobileApiException(
              code: 'progress_qr_invalid_response', message: '');
        }
        if (validated.status != 'waiting') {
          throw MobileApiException(
              code: validated.status == 'in_use'
                  ? 'progress_batch_in_use'
                  : 'progress_batch_already_used',
              message: '');
        }
        final latest = await _loadCurrentQueueActionControl();
        if (!mounted ||
            scope != currentSessionReadScope() ||
            !_materialContextIsCurrent(openedId, openedStation)) {
          return null;
        }
        _updateWipScanState(() => _queueActionControl = latest);
        final action =
            purpose == _WorkerWipScanPurpose.merge ? 'merge' : 'start';
        if (_queueActionContractSynchronized &&
            latest?.allows(action) == true) {
          if (!_workerWipConsumerIds(validated, widget.order.map,
                  consumerStageNodeId: latest?.stageNodeId ?? '')
              .contains(openedStation)) {
            await _showWipScanGuidance(
                context.l10n.productionText('worker.error.machine_flow'));
            return null;
          }
          _wipScanHandled = false;
          return validated;
        }
        guidance = await _currentWipScanGuidance();
      }
    }
    if (!mounted || scope != currentSessionReadScope()) return null;
    if (!sameOrder) {
      guidance =
          '${context.l10n.productionText('worker.qr.wrong_order_context', values: {
            'opened': _busyOrderDisplayLabel(widget.order, context.l10n),
            'order': orderLabel
          })} $guidance';
    }
    if (purpose == _WorkerWipScanPurpose.materialIntake) {
      guidance =
          '${context.l10n.productionText('worker.qr.material_mode')} $guidance';
    }
    if (sameOrder &&
        control?.allows('resume') == true &&
        control?.interaction?.qolipMode == AdminQueueQolipMode.scanRequired &&
        !_allRequiredQolipsScanned) {
      guidance += ' ${context.l10n.productionText('worker.qr.resume_molds')}';
    }
    await _showWipScanGuidance(guidance);
    return null;
  }
}

String _workerWipScanErrorText(Object error, AppLocalizations l10n,
    {String orderTitle = ''}) {
  if (error is TimeoutException) {
    return l10n.productionText('worker.error.network_timeout');
  }
  if (error is http.ClientException) {
    return l10n.productionText('worker.qr.connection');
  }
  if (error is FormatException || error is TypeError) {
    return l10n.productionText('worker.qr.invalid_response');
  }
  if (error is MobileApiException) {
    if (error.code == 'order_frozen') {
      return _workerFrozenOrderMessage(l10n,
          error.orderTitle.trim().isEmpty ? orderTitle : error.orderTitle);
    }
    if (error.statusCode == 401 || error.code == 'unauthorized') {
      return l10n.productionText('worker.qr.session_expired');
    }
    if (error.statusCode == 403 ||
        error.code == 'forbidden' ||
        error.code == 'apparatus_not_assigned') {
      return l10n.productionText('worker.qr.forbidden');
    }
    final key = switch (error.code) {
      'progress_batch_in_use' => 'worker.error.wip_in_use',
      'progress_batch_already_used' => 'worker.error.wip_used',
      'progress_qr_invalid_response' ||
      'progress_qr_validation_missing' ||
      'progress_input_invalid' =>
        'worker.qr.invalid_response',
      'opening_wip_qr_not_found' ||
      'opening_wip_not_found' =>
        'worker.qr.not_found',
      'opening_wip_qr_mismatch' ||
      'opening_wip_lookup' =>
        'worker.opening_wip.qr_mismatch',
      'queue_action_not_allowed' ||
      'order_scan_bootstrap_stale' ||
      'production_map_snapshot_contract_invalid' =>
        'worker.qr.scan_state_changed',
      _ => '',
    };
    if (key.isNotEmpty) return l10n.productionText(key);
    return l10n.productionErrorMessage(error.code,
        fallback: l10n.productionText('worker.qr.lookup_failed'));
  }
  return l10n.productionText('worker.qr.lookup_failed');
}
