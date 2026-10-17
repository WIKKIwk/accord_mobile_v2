part of 'admin_production_map_orders_screen.dart';

extension _WorkerMaterialDelivery on _ReadOnlyOrderDetailSheetState {
  Future<bool> _handleRawMaterialContextScan(
    String barcode, {
    required bool mergeMode,
  }) async {
    if (_isTrainingOrder) return false;
    final scope = currentSessionReadScope();
    final orderId = widget.order.map.id.trim();
    final station = widget.apparatus?.id.trim() ?? '';
    bool current() =>
        mounted &&
        scope == currentSessionReadScope() &&
        _detailReadScope == scope &&
        _materialContextIsCurrent(orderId, station);
    late final AdminRawMaterialLookup material;
    try {
      material =
          await MobileApi.instance.adminRawMaterialLookup(barcode: barcode);
    } on MobileApiException catch (error) {
      if (error.statusCode == 404 ||
          error.code == 'raw_material_stock_not_found') {
        return false;
      }
      rethrow;
    }
    if (!current()) return true;
    // Test-mode lookup may return an empty result for a non-material QR.
    if (material.itemCode.trim().isEmpty && material.assignment == null)
      return false;
    if (_materialBarcodeKey(material.barcode) != _materialBarcodeKey(barcode)) {
      throw const MobileApiException(
          code: 'raw_material_lookup_invalid_response', message: '');
    }
    _wipScanHandled = true;
    final assignment = material.assignment;
    final name =
        material.itemName.isEmpty ? material.itemCode : material.itemName;
    final lines = [
      context.l10n
          .productionText('worker.qr.material.scanned', values: {'name': name})
    ];
    if (assignment == null) {
      lines.add(context.l10n.productionText('worker.qr.material.unassigned'));
      await _showWipScanGuidance(lines.join('\n\n'));
      return true;
    }
    lines.add(context.l10n
        .productionText('worker.qr.material.assigned_context', values: {
      'order': material.order?.orderNumber ?? assignment.orderId,
      'apparatus': canonicalApparatusDisplayLabel(
          assignment.apparatus, widget.apparatusCatalog),
    }));
    if (assignment.orderId.trim() != orderId ||
        assignment.apparatus.trim() != station) {
      lines
          .add(context.l10n.productionText('worker.qr.material.wrong_context'));
      await _showWipScanGuidance(lines.join('\n\n'));
      return true;
    }
    final status = material.status.trim().toLowerCase();
    if (status == 'consumed' || status == 'in_use' || status == 'reserved') {
      lines.add(
          context.l10n.productionText('worker.qr.material.status_$status'));
      await _showWipScanGuidance(lines.join('\n\n'));
      return true;
    }
    if (status != 'available' || material.reservedOrderId.trim().isNotEmpty) {
      lines.add(context.l10n.productionText('worker.qr.material.unavailable'));
      await _showWipScanGuidance(lines.join('\n\n'));
      return true;
    }
    final control = await _loadCurrentQueueActionControl();
    if (!current()) return true;
    if (control == null || !_queueActionContractSynchronized) {
      throw const MobileApiException(
          code: 'order_scan_bootstrap_stale', message: '');
    }
    if (_orderControlState != AdminOrderControlState.active) {
      lines.add(context.l10n
          .productionText('worker.qr.material.receipt_unavailable'));
      await _showWipScanGuidance(lines.join('\n\n'));
      return true;
    }
    final loaded = await _loadMaterialAssignments(
        showLoading: false, readIsCurrent: current);
    if (!current()) return true;
    if (!loaded) {
      await _showWipScanGuidance(_materialsError.isEmpty
          ? context.l10n.productionText('worker.error.sync')
          : _materialsError);
      return true;
    }
    final freshAssignment = _materialAssignmentForScannedBarcode(
      assignments: _materialAssignments,
      barcode: barcode,
    );
    if (freshAssignment == null ||
        freshAssignment.orderId.trim() != orderId ||
        freshAssignment.apparatus.trim() != station) {
      lines
          .add(context.l10n.productionText('worker.qr.material.wrong_context'));
    } else if (const {'consumed', 'in_use', 'reserved'}
        .contains(freshAssignment.stockStatus.trim().toLowerCase())) {
      lines.add(context.l10n.productionText(
          'worker.qr.material.status_${freshAssignment.stockStatus.trim().toLowerCase()}'));
    } else if (_detailUiState.materialIntakeAllowed &&
        _materialAssignmentForScannedBarcode(
              assignments: _intakeCandidateAssignments,
              barcode: barcode,
            ) !=
            null) {
      if (mergeMode) {
        setState(() {
          _mergeScanMode = false;
          _materialIntakeMode = true;
          _intakeCandidatesExpanded = true;
        });
      }
      final received = await _receiveAdditionalMaterialFromQuickScan(barcode);
      if (current())
        _showQuickScanFeedback(
          received
              ? ProductionQuickScanFeedback.accepted
              : ProductionQuickScanFeedback.rejected,
          highlight: received
              ? ProductionQuickScanHighlight.materials
              : ProductionQuickScanHighlight.none,
        );
      return true;
    } else if (freshAssignment.executionStatus == 'awaiting_delivery') {
      lines.add(
          context.l10n.productionText('worker.qr.material.awaiting_delivery'));
    } else if (freshAssignment.executionStatus == 'width_mismatch' ||
        freshAssignment.executionStatus == 'needs_cutting') {
      lines.add(
          context.l10n.productionText('worker.error.material_width_mismatch'));
    } else if (freshAssignment.executionStatus == 'unavailable') {
      lines.add(context.l10n.productionText('worker.qr.material.unavailable'));
    } else if (!_detailUiState.showStart &&
        !_detailUiState.showResume &&
        !_detailUiState.materialIntakeAllowed) {
      lines.add(context.l10n
          .productionText('worker.qr.material.receipt_unavailable'));
    } else {
      lines.add(context.l10n.productionText('worker.qr.material.scan_ready'));
    }
    await _showWipScanGuidance(lines.join('\n\n'));
    return true;
  }

  bool get _materialDeliveryScanPending =>
      _detailUiState.showStart &&
      _detailUiState.showStartMaterials &&
      !_materialsLoading &&
      _materialsError.isEmpty &&
      _materialAssignments.any((material) =>
          material.apparatus.trim() == widget.apparatus?.id.trim() &&
          (const ['compatible', 'ready', 'awaiting_delivery']
                  .contains(material.executionStatus) ||
              (material.executionStatus.isEmpty &&
                  material.stockStatus == 'available' &&
                  material.stockQty > 0)) &&
          !_scannedMaterialBarcodes
              .contains(_materialBarcodeKey(material.barcode)));

  Future<bool> _receiveScannedMaterialAtApparatus(
    AdminRawMaterialAssignment material,
  ) async {
    final station = widget.apparatus?.id.trim() ?? '';
    final orderId = widget.order.map.id.trim();
    final candidates =
        await MobileApi.instance.adminMaterialStartDeliveryCandidates(
      orderId: orderId,
      apparatus: station,
      barcode: material.barcode,
    );
    if (!mounted || !_materialContextIsCurrent(orderId, station)) return false;
    if (!candidates.alreadyAtApparatus) {
      if (candidates.deliverers.isEmpty) {
        throw MobileApiException(
          code: 'material_deliverer_missing',
          message: context.l10n.productionText('worker.delivery.no_deliverers'),
        );
      }
      final deliverer =
          await _pickMaterialDeliverer(material, candidates.deliverers);
      if (!mounted ||
          deliverer == null ||
          !_materialContextIsCurrent(orderId, station)) return false;
      await MobileApi.instance.adminReceiveMaterialForStart(
        orderId: orderId,
        apparatus: station,
        barcode: material.barcode,
        deliveredBy: deliverer,
        idempotencyKey:
            'material-delivery:$orderId:$station:${material.barcode}:${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!mounted || !_materialContextIsCurrent(orderId, station))
        return false;
    }
    return true;
  }

  Future<bool> _receiveScannedMaterialForStart(
    AdminRawMaterialAssignment material,
  ) async {
    final station = widget.apparatus?.id.trim() ?? '';
    final orderId = widget.order.map.id.trim();
    if (!await _receiveScannedMaterialAtApparatus(material)) return false;
    await _loadMaterialAssignments(showLoading: false);
    if (!mounted || !_materialContextIsCurrent(orderId, station)) return false;
    final key = _materialBarcodeKey(material.barcode);
    if (_materialStartRequirements?.normalizedStagedBarcodes.contains(key) !=
            true ||
        !_startAssignments.any(
            (assignment) => _materialBarcodeKey(assignment.barcode) == key)) {
      throw MobileApiException(
        code: 'material_delivery_receipt_unconfirmed',
        message: context.l10n.productionText('worker.delivery.unconfirmed'),
      );
    }
    return true;
  }

  Future<AdminMaterialDeliverer?> _pickMaterialDeliverer(
    AdminRawMaterialAssignment material,
    List<AdminMaterialDeliverer> deliverers,
  ) async {
    AdminMaterialDeliverer? selected;
    final l10n = context.l10n;
    return showDialog<AdminMaterialDeliverer>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => Dialog(
          key: const ValueKey('material-delivery-dialog'),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.productionText('worker.delivery.title'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        Text(material.itemName.isEmpty
                            ? material.itemCode
                            : material.itemName),
                        Text(material.barcode),
                        const SizedBox(height: 12),
                        Text(l10n.productionText('worker.delivery.message')),
                        const SizedBox(height: 12),
                        for (final deliverer in deliverers)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            key: ValueKey(
                                'material-deliverer-${deliverer.role}-${deliverer.ref}'),
                            title: Text(deliverer.name),
                            leading: Icon(selected == deliverer
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked),
                            onTap: () => update(() => selected = deliverer),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('material-delivery-confirm'),
                      onPressed: selected == null
                          ? null
                          : () => Navigator.pop(dialogContext, selected),
                      child:
                          Text(l10n.productionText('worker.delivery.confirm')),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(l10n.productionText('worker.delivery.cancel')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
