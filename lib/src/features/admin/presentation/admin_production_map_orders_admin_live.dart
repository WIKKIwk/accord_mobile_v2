part of 'admin_production_map_orders_screen.dart';

extension _AdminOrdersPagedLive on _AdminProductionMapOrdersScreenState {
  Future<void> _restartAdminPagedLive() async {
    _stopWorkerLiveStream();
    final generation = _liveStreamGeneration;
    if (await TestModeController.instance.isEnabled()) return;
    if (!mounted || !_adminForeground || generation != _liveStreamGeneration) {
      return;
    }
    unawaited(_runWorkerLiveStream(generation));
  }

  void _applyAdminPageLive(Object message) {
    final String epoch;
    final int revision;
    if (message is AdminProductionMapPageChange) {
      epoch = message.epoch;
      revision = message.revision;
    } else if (message is AdminProductionMapLiveDelta) {
      epoch = message.epoch;
      revision = message.snapshotRevision!;
    } else {
      return;
    }
    if (_retiredSnapshotEpochs.contains(epoch) ||
        (epoch == _adminLiveEpoch && revision < _adminLiveRevision)) {
      return;
    }
    _adminLiveEpoch = epoch;
    _adminLiveRevision = revision;
    final invalidation = ++_adminPageInvalidation;
    _updateScreenState(() {
      for (final window in _adminWindows.values) {
        if (window.account != _adminPageAccount) continue;
        final page = window.pages.firstOrNull;
        if (page?.epoch != epoch || (page?.revision ?? -1) < revision) {
          window.invalidation = invalidation;
        }
      }
      if (message is AdminProductionMapLiveDelta &&
          epoch == _lastAppliedSnapshotEpoch) {
        _applyAdminWindowMove(message);
      }
      // A move does not certify updated start/action permissions.
      _queueSnapshotNeedsReconcile = _sequenceNeedsSnapshot.isNotEmpty ||
          _adminModuleWindows(_module)
              .any((window) => !window.loaded || window.dirty);
    });
    // Only the active, already requested prefix is reconciled. Hidden tabs
    // retain their dirty marker until selected. There is no periodic read.
    unawaited(_ensureAdminModule(_module));
    if (message is AdminProductionMapPageChange) {
      unawaited(_refreshCompletionRequests());
    }
  }

  void _applyAdminWindowMove(AdminProductionMapLiveDelta delta) {
    final apparatus = delta.apparatus;
    final currentRevision = _sequenceRevisions[apparatus];
    if (currentRevision != null && delta.revision <= currentRevision) return;
    final window = _adminWindows.values
        .where((window) =>
            window.account == _adminPageAccount &&
            window.request.view == 'sequence' &&
            window.request.apparatus == apparatus &&
            window.request.search == _adminPageSearch &&
            window.loaded)
        .firstOrNull;
    if (window == null ||
        window.request.search.isNotEmpty ||
        _queuePoliciesByApparatus[apparatus]?.policy ==
            ApparatusQueuePolicy.freePick) {
      return;
    }
    // Reuse the original delta reducer with its version and anchor checks.
    // Missing rows/anchors and gaps require a canonical window read.
    final next = _sequenceAfterDelta(_sequenceByApparatus[apparatus],
        currentRevision, _sequenceVersions[apparatus], delta);
    if (next == null) return;
    _sequenceByApparatus[apparatus] = next;
    _sequenceVersions[apparatus] = delta.version;
    _sequenceRevisions[apparatus] = delta.revision;
    _adminSequenceAcks[apparatus] = AdminSequenceMoveResult(
        next, delta.version, false,
        revision: delta.revision, epoch: delta.epoch);
  }
}
