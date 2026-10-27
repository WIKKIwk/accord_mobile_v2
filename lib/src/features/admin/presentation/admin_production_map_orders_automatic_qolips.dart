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
      required this.blockingText,
      required this.enabled,
      required this.onSelect});

  final AdminProductionMapQolipValidation? validation;
  final String? selectedSetId;
  final bool confirmed;
  final bool loading;
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(confirmed ? Icons.check_circle_rounded : Icons.layers_outlined,
            color: confirmed ? scheme.primary : scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
            child: Text(l10n.productionText('worker.molds'),
                style: Theme.of(context).textTheme.titleSmall)),
      ]),
      if (loading) ...[
        const SizedBox(height: 8),
        const LinearProgressIndicator(),
      ],
      if (sets.length > 1) ...[
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
      if (confirmed)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(l10n.productionText('qolip.start.auto.confirmed'),
              key: const ValueKey('production-qolip-auto-status'),
              style: TextStyle(color: scheme.primary)),
        ),
      if (blockingText.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(blockingText,
              key: const ValueKey('production-qolip-auto-blocking'),
              style: TextStyle(
                  color: loading ? scheme.onSurfaceVariant : scheme.error)),
        ),
      for (final mold in molds)
        Padding(
          key: ValueKey('production-qolip-auto-' + mold.qolipCode),
          padding: const EdgeInsets.only(top: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(
                mold.ready && !loading
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: mold.ready && !loading ? scheme.primary : scheme.error),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text([mold.qolipCode, mold.color]
                    .where((value) => value.isNotEmpty)
                    .join(' · ')),
                if (mold.blockingReasonCode.isNotEmpty)
                  Text(
                      l10n.productionErrorMessage(mold.blockingReasonCode,
                          fallback:
                              l10n.productionText('qolip.start.auto.blocked')),
                      style: TextStyle(color: scheme.error)),
              ],
            )),
          ]),
        ),
    ]);
  }
}
