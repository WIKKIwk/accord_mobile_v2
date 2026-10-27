part of 'admin_production_map_orders_screen.dart';

extension _AutomaticOrderQolips on _ReadOnlyOrderDetailSheetState {
  bool get _automaticQolipMode =>
      !_isTrainingOrder &&
      _queueActionControl?.interaction?.qolipMode ==
          AdminQueueQolipMode.scanRequired &&
      _queueActionControl?.interaction?.qolipAutomaticConfirmation == true;

  AdminQolipAutomaticSet? get _selectedAutomaticQolipSet =>
      _automaticQolipValidation?.sets
          .where((entry) => entry.setId == _automaticQolipSetId)
          .firstOrNull;

  bool get _automaticQolipsReady {
    final validation = _automaticQolipValidation;
    final selected = _selectedAutomaticQolipSet;
    if (!_automaticQolipMode ||
        !_queueActionContractSynchronized ||
        !_qolipRequirementsLoaded ||
        _qolipRequirementsLoading ||
        _qolipRequirementsError.isNotEmpty ||
        validation == null ||
        !validation.automaticConfirmationEnabled ||
        validation.policyRevision !=
            _queueActionControl?.interaction?.qolipPolicyRevision ||
        validation.blockingReasonCode.isNotEmpty ||
        selected == null ||
        !selected.ready ||
        selected.blockingReasonCode.isNotEmpty) return false;
    final members = validation.requiredQolips
        .where((mold) => mold.isExtension || mold.setId == selected.setId)
        .toList();
    return members.isNotEmpty &&
        members.every((mold) => mold.ready && mold.blockingReasonCode.isEmpty);
  }

  bool get _qolipsConfirmedForStart =>
      _automaticQolipMode ? _automaticQolipsReady : _allRequiredQolipsScanned;

  AdminQolipAutomaticConfirmation? get _automaticQolipConfirmation {
    if (!_automaticQolipsReady) return null;
    final selected = _selectedAutomaticQolipSet!;
    return AdminQolipAutomaticConfirmation(
      setId: selected.setId,
      fingerprint: selected.fingerprint,
      policyRevision: _automaticQolipValidation!.policyRevision,
    );
  }

  void _clearAutomaticQolips() {
    _automaticQolipValidation = null;
    _automaticQolipSetId = null;
    _automaticQolipReadRevision = null;
    _automaticQolipRequestedRevision = null;
  }

  void _acceptQolipRequirements(AdminProductionMapQolipValidation validation,
      {int? readRevision}) {
    if (_automaticQolipMode &&
        (!validation.automaticConfirmationEnabled ||
            validation.policyRevision !=
                _queueActionControl?.interaction?.qolipPolicyRevision)) {
      throw const MobileApiException(
          code: 'qolip_policy_changed',
          message: 'Qolip confirmation policy changed');
    }
    final previous = _selectedAutomaticQolipSet;
    _replaceRequiredQolips(validation.requiredQolips);
    if (!_automaticQolipMode) {
      _clearAutomaticQolips();
      return;
    }
    _automaticQolipValidation = validation;
    _automaticQolipReadRevision =
        readRevision ?? _acceptedDetailControl?.revision;
    _automaticQolipRequestedRevision = _automaticQolipReadRevision;
    if (validation.sets.length == 1) {
      _automaticQolipSetId = validation.sets.single.setId;
    } else if (previous == null ||
        !validation.sets.any((entry) =>
            entry.setId == previous.setId &&
            entry.fingerprint == previous.fingerprint)) {
      _automaticQolipSetId = null;
    }
  }

  String get _automaticQolipBlockingText {
    final l10n = context.l10n;
    if (_qolipRequirementsLoading) {
      return l10n.productionText('qolip.start.auto.checking');
    }
    if (_qolipRequirementsError.isNotEmpty) return _qolipRequirementsError;
    final validation = _automaticQolipValidation;
    if (validation == null) {
      return l10n.productionText('qolip.start.auto.unavailable');
    }
    if (validation.requiredQolips.isEmpty &&
        (validation.blockingReasonCode.isEmpty ||
            validation.blockingReasonCode == 'qolip_scan_required')) {
      return l10n.productionText('worker.mold.requirements.empty');
    }
    if (validation.blockingReasonCode.isNotEmpty) {
      return l10n.productionErrorMessage(validation.blockingReasonCode,
          fallback: l10n.productionText('qolip.start.auto.blocked'));
    }
    final selected = _selectedAutomaticQolipSet;
    if (selected == null) {
      return l10n.productionText('qolip.start.auto.choose_set');
    }
    return l10n.productionErrorMessage(selected.blockingReasonCode,
        fallback: l10n.productionText('qolip.start.auto.blocked'));
  }

  Widget _automaticQolipContent() => _AutomaticQolipReadiness(
        validation: _automaticQolipValidation,
        selectedSetId: _automaticQolipSetId,
        confirmed: _automaticQolipsReady,
        loading: _qolipRequirementsLoading,
        expanded: _qolipsExpanded,
        onToggleExpanded: () =>
            setState(() => _qolipsExpanded = !_qolipsExpanded),
        blockingText: _automaticQolipsReady ? '' : _automaticQolipBlockingText,
        enabled: _queueActionContractSynchronized &&
            !_queueActionBusy &&
            !_qolipRequirementsLoading,
        onSelect: (setId) {
          if (!_automaticQolipMode ||
              !_queueActionContractSynchronized ||
              _queueActionBusy ||
              _qolipRequirementsLoading) return;
          setState(() => _automaticQolipSetId = setId);
        },
      );
}

class _AutomaticQolipReadiness extends StatelessWidget {
  const _AutomaticQolipReadiness(
      {required this.validation,
      required this.selectedSetId,
      required this.confirmed,
      required this.loading,
      required this.expanded,
      required this.onToggleExpanded,
      required this.blockingText,
      required this.enabled,
      required this.onSelect});

  final AdminProductionMapQolipValidation? validation;
  final String? selectedSetId;
  final bool confirmed;
  final bool loading;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final String blockingText;
  final bool enabled;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final sets = validation?.sets ?? const <AdminQolipAutomaticSet>[];
    final molds = (validation?.requiredQolips ??
            const <AdminProductionMapRequiredQolip>[])
        .where((mold) =>
            selectedSetId == null ||
            mold.isExtension ||
            mold.setId == selectedSetId)
        .toList();
    final confirmedCount = molds
        .where(
            (mold) => mold.ready && !loading && mold.blockingReasonCode.isEmpty)
        .length;
    final choosingSet = sets.length > 1 && selectedSetId == null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _ScannedItemsExpansionHeader(
        key: const ValueKey('production-qolips-expansion'),
        title: l10n.productionText(
            choosingSet ? 'worker.mold.alternatives' : 'worker.molds'),
        countText: l10n.productionText('worker.mold.progress', values: {
          'scanned': confirmedCount,
          'required': molds.length,
        }),
        countNumber:
            choosingSet ? '${sets.length}' : '$confirmedCount/${molds.length}',
        countUnit: choosingSet
            ? l10n.productionText('worker.mold.set_unit')
            : (l10n.isUzbek ? 'ta' : ''),
        isLoading: loading,
        expanded: molds.isNotEmpty && expanded,
        onTap: molds.isNotEmpty ? onToggleExpanded : null,
        trailing: confirmed
            ? Icon(Icons.check_rounded,
                key: const ValueKey('production-qolip-auto-status'),
                color: scheme.primary,
                semanticLabel:
                    l10n.productionText('qolip.start.auto.confirmed'))
            : null,
      ),
      if (loading) ...[
        const SizedBox(height: 8),
        const LinearProgressIndicator(),
      ],
      if (expanded && sets.length > 1) ...[
        const SizedBox(height: 8),
        Text(l10n.productionText('qolip.start.auto.choose_set')),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final entry in sets)
            ChoiceChip(
              key: ValueKey('production-qolip-set-select-' + entry.setId),
              label: Text(entry.setId),
              selected: selectedSetId == entry.setId,
              onSelected: enabled ? (_) => onSelect(entry.setId) : null,
            ),
        ]),
      ],
      if (blockingText.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(blockingText,
              key: const ValueKey('production-qolip-auto-blocking'),
              style: TextStyle(
                  color: loading ? scheme.onSurfaceVariant : scheme.error)),
        ),
      if (expanded)
        for (final (index, mold) in molds.indexed)
          Padding(
            key: ValueKey('production-qolip-auto-' + mold.qolipCode),
            padding: EdgeInsets.only(top: index == 0 ? 12 : 8),
            child: _ScannedQolipTile(
              qolip: mold,
              scanned:
                  mold.ready && !loading && mold.blockingReasonCode.isEmpty,
              blockingReasonCode: mold.blockingReasonCode,
            ),
          ),
    ]);
  }
}
