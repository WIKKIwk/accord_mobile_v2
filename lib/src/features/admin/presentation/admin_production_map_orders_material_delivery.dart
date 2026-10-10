part of 'admin_production_map_orders_screen.dart';

extension _WorkerMaterialDelivery on _ReadOnlyOrderDetailSheetState {
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

  Future<bool> _receiveScannedMaterialForStart(
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
        builder: (context, update) => AlertDialog(
          key: const ValueKey('material-delivery-dialog'),
          title: Text(l10n.productionText('worker.delivery.title')),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(material.itemName.isEmpty
                    ? material.itemCode
                    : material.itemName),
                Text(material.barcode),
                const SizedBox(height: 12),
                Text(l10n.productionText('worker.delivery.message')),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(children: [
                      for (final deliverer in deliverers)
                        ListTile(
                          key: ValueKey(
                              'material-deliverer-${deliverer.role}-${deliverer.ref}'),
                          title: Text(deliverer.name),
                          leading: Icon(selected == deliverer
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked),
                          onTap: () => update(() => selected = deliverer),
                        ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.productionText('worker.delivery.cancel'))),
            FilledButton(
              key: const ValueKey('material-delivery-confirm'),
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(dialogContext, selected),
              child: Text(l10n.productionText('worker.delivery.confirm')),
            ),
          ],
        ),
      ),
    );
  }
}
