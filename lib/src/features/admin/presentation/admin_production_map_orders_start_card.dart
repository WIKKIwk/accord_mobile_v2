part of 'admin_production_map_orders_screen.dart';

class _OrderStartUnifiedCard extends StatelessWidget {
  const _OrderStartUnifiedCard({
    required this.apparatusCatalog,
    required this.orderCode,
    required this.orderImageBytes,
    required this.orderImageLoading,
    required this.onViewOrderImage,
    required this.productTitle,
    required this.customerName,
    required this.workerMode,
    required this.contractSynchronized,
    required this.showContractWarning,
    required this.blockingReasonCode,
    required this.showBackendBlockingState,
    required this.startAssignments,
    required this.intakeCandidateAssignments,
    required this.assignedAssignments,
    required this.showStartMaterials,
    required this.showIntakeCandidates,
    required this.materialIntakeAllowed,
    required this.materialsLoading,
    required this.materialsError,
    required this.materialStartReady,
    required this.materialStartBlockingText,
    required this.scannedBarcodes,
    required this.scannedCount,
    required this.requiredCount,
    required this.showStart,
    required this.allMaterialsScanned,
    required this.actionInFlight,
    required this.materialIntakeInFlight,
    required this.materialIntakeMode,
    required this.intakeCandidatesExpanded,
    required this.onToggleIntakeCandidatesExpanded,
    required this.showPause,
    required this.pauseLabel,
    required this.showMerge,
    required this.showRollComplete,
    required this.showComplete,
    required this.showResume,
    required this.showWaitingForPrevious,
    required this.showWaitingForSequence,
    required this.previousStage,
    required this.openingWipRequired,
    required this.previousProgressRequired,
    required this.previousProgressReady,
    required this.previousProgressBatch,
    required this.openingWipBatch,
    required this.openingWipBatches,
    required this.inputProgressBatches,
    required this.inputProgressLoading,
    required this.inputProgressError,
    required this.requiresQolipScan,
    required this.qolipScanned,
    required this.qolipCodes,
    required this.requiredQolips,
    required this.qolipRequirementsStatusText,
    required this.startMaterialsExpanded,
    required this.onToggleStartMaterialsExpanded,
    required this.materialsExpanded,
    required this.onToggleMaterialsExpanded,
    required this.qolipsExpanded,
    required this.onToggleQolipsExpanded,
    required this.rezkaInstructionLines,
    required this.rezkaMergeStateLines,
    required this.onMaterialIntake,
    required this.onStart,
    required this.onPause,
    required this.onMerge,
    required this.onRollComplete,
    required this.onComplete,
    required this.onResume,
    required this.orderControlState,
    required this.allowMaterialUnlink,
    required this.onUnlinkMaterial,
    required this.unlinkingMaterialBarcode,
  });
  final List<AdminApparatus> apparatusCatalog;
  final String orderCode;
  final List<int>? orderImageBytes;
  final bool orderImageLoading;
  final VoidCallback onViewOrderImage;
  final String productTitle;
  final String? customerName;
  final bool workerMode;
  final bool contractSynchronized;
  final bool showContractWarning;
  final String blockingReasonCode;
  final bool showBackendBlockingState;
  final List<AdminRawMaterialAssignment> startAssignments;
  final List<AdminRawMaterialAssignment> intakeCandidateAssignments;
  final List<AdminRawMaterialAssignment> assignedAssignments;
  final bool showStartMaterials;
  final bool showIntakeCandidates;
  final bool materialIntakeAllowed;
  final bool materialsLoading;
  final String materialsError;
  final bool materialStartReady;
  final String materialStartBlockingText;
  final Set<String> scannedBarcodes;
  final int scannedCount;
  final int requiredCount;
  final bool showStart;
  final bool allMaterialsScanned;
  final bool actionInFlight;
  final bool materialIntakeInFlight;
  final bool materialIntakeMode;
  final bool intakeCandidatesExpanded;
  final VoidCallback onToggleIntakeCandidatesExpanded;
  final bool showPause;
  final String pauseLabel;
  final bool showMerge;
  final bool showRollComplete;
  final bool showComplete;
  final bool showResume;
  final bool showWaitingForPrevious;
  final bool showWaitingForSequence;
  final String? previousStage;
  final bool openingWipRequired;
  final bool previousProgressRequired;
  final bool previousProgressReady;
  final AdminProgressBatch? previousProgressBatch;
  final AdminOpeningWipBatch? openingWipBatch;
  final List<AdminOpeningWipBatch> openingWipBatches;
  final List<AdminProgressBatch> inputProgressBatches;
  final bool inputProgressLoading;
  final String inputProgressError;
  final bool requiresQolipScan;
  final bool qolipScanned;
  final List<String> qolipCodes;
  final List<AdminProductionMapRequiredQolip> requiredQolips;
  final String qolipRequirementsStatusText;
  final bool startMaterialsExpanded;
  final VoidCallback onToggleStartMaterialsExpanded;
  final bool materialsExpanded;
  final VoidCallback onToggleMaterialsExpanded;
  final bool qolipsExpanded;
  final VoidCallback onToggleQolipsExpanded;
  final List<String> rezkaInstructionLines;
  final List<String> rezkaMergeStateLines;
  final VoidCallback onMaterialIntake;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onMerge;
  final VoidCallback onRollComplete;
  final VoidCallback onComplete;
  final VoidCallback onResume;
  final AdminOrderControlState orderControlState;
  final bool allowMaterialUnlink;
  final void Function(AdminRawMaterialAssignment assignment)? onUnlinkMaterial;
  final String unlinkingMaterialBarcode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final scannedQolipKeys = qolipCodes
        .map((code) => code.trim().toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet();
    final qolipProgressText = requiredQolips.isEmpty
        ? context.l10n.productionCount(qolipCodes.length, kind: 'molds')
        : context.l10n.productionText(
            'worker.mold.progress',
            values: {
              'scanned': qolipCodes.length,
              'required': requiredQolips.length,
            },
          );
    final orderControlBlocked =
        orderControlState != AdminOrderControlState.active;
    final hasActions = showStart ||
        showPause ||
        showMerge ||
        showComplete ||
        showResume ||
        showWaitingForPrevious ||
        showWaitingForSequence;
    final showContractSyncNotice = showContractWarning && !contractSynchronized;
    final showBackendBlockingNotice = showBackendBlockingState &&
        !orderControlBlocked &&
        !showWaitingForPrevious &&
        !showWaitingForSequence;
    final backendBlockingText = switch (blockingReasonCode.trim()) {
      'raw_material_assignment_required' => context.l10n.productionText(
          'worker.error.incomplete_material_groups',
        ),
      'order_frozen' => context.l10n.productionText('worker.freeze.active'),
      _ => context.l10n.productionText('worker.error.sync'),
    };
    final showRezkaInputProgressScan = previousProgressRequired && showStart;
    final hasIntakeCandidates = intakeCandidateAssignments.isNotEmpty;
    final showMaterialIntake = materialIntakeAllowed && hasIntakeCandidates;
    final intakeCandidatesExpandable = materialsLoading ||
        materialsError.trim().isNotEmpty ||
        hasIntakeCandidates;
    final attachedMaterialsExpandable = materialsLoading ||
        materialsError.trim().isNotEmpty ||
        assignedAssignments.isNotEmpty;
    final startMaterialsExpandable = startAssignments.isNotEmpty;
    final qolipsExpandable = requiredQolips.isNotEmpty;
    final customer = customerName?.trim() ?? '';
    final product = productTitle.trim();
    final orderProductLabel = customer.isEmpty
        ? product
        : product.isEmpty
            ? customer
            : '$customer • $product';
    return _orderDetailSurfaceCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!workerMode) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _productionMapOrderImageThumbnail(
                  context: context,
                  imageBytes: orderImageBytes,
                  loading: orderImageLoading,
                  onTap: onViewOrderImage,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 94,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.productionText('worker.order.code'),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              orderCode.trim().isEmpty ? '-' : orderCode.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            orderProductLabel.isEmpty ? '-' : orderProductLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(
                height: 28,
                color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ],
          if (orderControlBlocked) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                orderControlState == AdminOrderControlState.frozen
                    ? context.l10n.productionText('worker.freeze.active')
                    : context.l10n.productionText('worker.freeze.requested'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (showContractSyncNotice) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                context.l10n.productionText('worker.error.sync'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (showBackendBlockingNotice) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                backendBlockingText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (showStartMaterials) ...[
            _ScannedItemsExpansionHeader(
              key: const ValueKey('production-start-materials-expansion'),
              title: context.l10n.productionText(
                startMaterialsExpandable || materialsLoading
                    ? 'worker.materials.start'
                    : 'worker.materials.start.empty',
              ),
              countText:
                  materialsLoading ? '...' : '$scannedCount/$requiredCount',
              expanded: startMaterialsExpandable && startMaterialsExpanded,
              complete: requiredCount > 0 && allMaterialsScanned,
              onTap: startMaterialsExpandable
                  ? onToggleStartMaterialsExpanded
                  : null,
            ),
            if (startMaterialsExpandable && startMaterialsExpanded) ...[
              const SizedBox(height: 12),
              _RawMaterialAssignmentsExpansionBody(
                assignments: startAssignments,
                apparatusCatalog: apparatusCatalog,
                loading: materialsLoading,
                error: materialsError,
                emptyText: context.l10n.productionText(
                  'worker.materials.start.empty',
                ),
                scannedBarcodes: scannedBarcodes,
                allowUnlink: allowMaterialUnlink,
                onUnlink: onUnlinkMaterial,
                unlinkingBarcode: unlinkingMaterialBarcode,
              ),
            ],
            if (materialStartBlockingText.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  materialStartBlockingText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            Divider(
              height: 28,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ] else if (showIntakeCandidates) ...[
            _ScannedItemsExpansionHeader(
              key: const ValueKey('production-intake-materials-expansion'),
              title: context.l10n.productionText(
                intakeCandidatesExpandable
                    ? 'worker.materials.pending'
                    : 'worker.materials.pending.empty',
              ),
              countText: materialsLoading
                  ? '...'
                  : context.l10n.productionCount(
                      intakeCandidateAssignments.length,
                      kind: 'materials',
                    ),
              expanded: intakeCandidatesExpandable && intakeCandidatesExpanded,
              complete: false,
              onTap: intakeCandidatesExpandable
                  ? onToggleIntakeCandidatesExpanded
                  : null,
            ),
            if (intakeCandidatesExpandable && intakeCandidatesExpanded) ...[
              const SizedBox(height: 12),
              _RawMaterialAssignmentsExpansionBody(
                assignments: intakeCandidateAssignments,
                apparatusCatalog: apparatusCatalog,
                loading: materialsLoading,
                error: materialsError,
                emptyText: context.l10n.productionText(
                  'worker.materials.pending.empty',
                ),
                scannedBarcodes: const {},
                allowUnlink: allowMaterialUnlink,
                onUnlink: onUnlinkMaterial,
                unlinkingBarcode: unlinkingMaterialBarcode,
              ),
            ],
            Divider(
              height: 28,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ],
          _ScannedItemsExpansionHeader(
            key: const ValueKey('production-materials-expansion'),
            title: context.l10n.productionText(
              attachedMaterialsExpandable
                  ? 'worker.materials.attached'
                  : 'worker.materials.attached.empty',
            ),
            countText: materialsLoading
                ? '...'
                : context.l10n.productionCount(
                    assignedAssignments.length,
                    kind: 'materials',
                  ),
            expanded: attachedMaterialsExpandable && materialsExpanded,
            complete: false,
            onTap:
                attachedMaterialsExpandable ? onToggleMaterialsExpanded : null,
          ),
          if (attachedMaterialsExpandable && materialsExpanded) ...[
            const SizedBox(height: 12),
            _RawMaterialAssignmentsExpansionBody(
              assignments: assignedAssignments,
              apparatusCatalog: apparatusCatalog,
              loading: materialsLoading,
              error: materialsError,
              emptyText: context.l10n.productionText(
                'worker.materials.attached.empty',
              ),
              scannedBarcodes: scannedBarcodes,
              allowUnlink: allowMaterialUnlink,
              onUnlink: onUnlinkMaterial,
              unlinkingBarcode: unlinkingMaterialBarcode,
            ),
          ],
          if (showStart && requiresQolipScan) ...[
            Divider(
              height: 28,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            _ScannedItemsExpansionHeader(
              key: const ValueKey('production-qolips-expansion'),
              title: qolipsExpandable
                  ? context.l10n.productionText('worker.molds')
                  : qolipRequirementsStatusText,
              countText: qolipProgressText,
              expanded: qolipsExpandable && qolipsExpanded,
              complete: qolipScanned,
              onTap: qolipsExpandable ? onToggleQolipsExpanded : null,
            ),
            if (qolipsExpandable && qolipsExpanded) ...[
              const SizedBox(height: 12),
              Column(
                children: [
                  for (var index = 0;
                      index < requiredQolips.length;
                      index++) ...[
                    if (index > 0) const SizedBox(height: 8),
                    _ScannedQolipTile(
                      qolip: requiredQolips[index],
                      scanned: scannedQolipKeys.contains(
                        requiredQolips[index].qolipCode.trim().toLowerCase(),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
          if (hasActions) ...[
            Divider(
                height: 28,
                color: scheme.outlineVariant.withValues(alpha: 0.5)),
            if (showRezkaInputProgressScan) ...[
              if (openingWipRequired)
                _OpeningWipQrTile(
                  previousStage: previousStage ?? '',
                  apparatusCatalog: apparatusCatalog,
                  ready: previousProgressReady,
                  batch: openingWipBatch,
                  availableBatches: openingWipBatches,
                  loading: inputProgressLoading,
                  error: inputProgressError,
                )
              else
                _PreviousProgressQrTile(
                  previousStage: previousStage ?? '',
                  apparatusCatalog: apparatusCatalog,
                  ready: previousProgressReady,
                  batch: previousProgressBatch,
                  availableBatches: inputProgressBatches,
                  loading: inputProgressLoading,
                  error: inputProgressError,
                ),
              const SizedBox(height: 10),
            ],
            AnimatedSize(
              key: const ValueKey('production-order-material-intake-motion'),
              duration: AppMotion.medium,
              curve: AppMotion.standardDecelerate,
              alignment: Alignment.topCenter,
              child: showMaterialIntake
                  ? Column(
                      key: const ValueKey(
                        'production-order-material-intake-visible',
                      ),
                      children: [
                        FilledButton.tonalIcon(
                          key: const ValueKey(
                            'receive-additional-raw-material',
                          ),
                          onPressed: actionInFlight || materialIntakeInFlight
                              ? null
                              : onMaterialIntake,
                          icon: materialIntakeInFlight
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  materialIntakeMode
                                      ? Icons.close_rounded
                                      : Icons.add_box_outlined,
                                ),
                          label: Text(
                            materialIntakeMode
                                ? context.l10n.productionText(
                                    'worker.action.close_scanner',
                                  )
                                : context.l10n.productionText(
                                    'worker.action.receive_material',
                                  ),
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    )
                  : const SizedBox(
                      key: ValueKey('production-order-material-intake-hidden'),
                    ),
            ),
            if (rezkaInstructionLines.isNotEmpty) ...[
              _RezkaWipSplitInstruction(lines: rezkaInstructionLines),
              const SizedBox(height: 10),
            ],
            if (rezkaMergeStateLines.isNotEmpty) ...[
              _RezkaMergeStateCard(lines: rezkaMergeStateLines),
              const SizedBox(height: 10),
            ],
            AnimatedSize(
              key: const ValueKey('production-order-start-action-motion'),
              duration: AppMotion.medium,
              curve: AppMotion.standardDecelerate,
              alignment: Alignment.topCenter,
              child: showStart
                  ? FilledButton.icon(
                      key: const ValueKey('production-order-start-action'),
                      onPressed: actionInFlight ||
                              !materialStartReady ||
                              (requiresQolipScan && !qolipScanned) ||
                              !previousProgressReady
                          ? null
                          : onStart,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        context.l10n.productionText('worker.action.start'),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: Size.fromHeight(workerMode ? 58 : 52),
                        padding: workerMode
                            ? const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              )
                            : null,
                        textStyle: workerMode
                            ? theme.textTheme.titleMedium?.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              )
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            workerMode ? 28 : 14,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey('production-order-start-action-hidden'),
                    ),
            ),
            AnimatedSize(
              key: const ValueKey('production-order-pause-complete-motion'),
              duration: AppMotion.medium,
              curve: AppMotion.standardDecelerate,
              alignment: Alignment.topCenter,
              child: showPause || showComplete
                  ? Column(
                      key: const ValueKey(
                        'production-order-pause-complete-visible',
                      ),
                      children: [
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (showPause)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: actionInFlight ? null : onPause,
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: Size.fromHeight(
                                      workerMode ? 58 : 48,
                                    ),
                                    padding: workerMode
                                        ? const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 16,
                                          )
                                        : null,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        workerMode ? 28 : 14,
                                      ),
                                    ),
                                  ),
                                  child: Text(pauseLabel),
                                ),
                              ),
                            if (showPause && showComplete)
                              const SizedBox(width: 10),
                            if (showComplete)
                              Expanded(
                                child: FilledButton(
                                  onPressed: actionInFlight ? null : onComplete,
                                  style: FilledButton.styleFrom(
                                    minimumSize: Size.fromHeight(
                                      workerMode ? 58 : 48,
                                    ),
                                    padding: workerMode
                                        ? const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 16,
                                          )
                                        : null,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        workerMode ? 28 : 14,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    context.l10n.productionText(
                                      'worker.action.complete',
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    )
                  : const SizedBox(
                      key: ValueKey('production-order-pause-complete-hidden'),
                    ),
            ),
            AnimatedSize(
              key: const ValueKey('production-order-merge-motion'),
              duration: AppMotion.medium,
              curve: AppMotion.standardDecelerate,
              alignment: Alignment.topCenter,
              child: showMerge
                  ? Column(
                      key: const ValueKey(
                        'production-order-merge-visible',
                      ),
                      children: [
                        const SizedBox(height: 10),
                        FilledButton.tonalIcon(
                          key: const ValueKey('production-order-merge-action'),
                          onPressed: actionInFlight ? null : onMerge,
                          icon: const Icon(Icons.link_rounded),
                          label: Text(
                            context.l10n.productionText(
                              'worker.action.merge',
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(
                      key: ValueKey('production-order-merge-hidden'),
                    ),
            ),
            AnimatedSize(
              key: const ValueKey('production-order-resume-motion'),
              duration: AppMotion.medium,
              curve: AppMotion.standardDecelerate,
              alignment: Alignment.topCenter,
              child: showResume
                  ? Column(
                      key: const ValueKey('production-order-resume-visible'),
                      children: [
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: actionInFlight ? null : onResume,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(
                            context.l10n.productionText('worker.action.resume'),
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(
                      key: ValueKey('production-order-resume-hidden'),
                    ),
            ),
            if (showWaitingForPrevious && previousStage != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.productionText(
                        'worker.waiting.previous',
                        values: {
                          'stage': canonicalApparatusDisplayLabel(
                            previousStage!,
                            apparatusCatalog,
                          ),
                        },
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (showWaitingForSequence) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.productionText('worker.waiting.sequence'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
