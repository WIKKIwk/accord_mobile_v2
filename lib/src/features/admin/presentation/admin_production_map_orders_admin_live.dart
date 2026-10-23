part of 'admin_production_map_orders_screen.dart';

extension _AdminOrdersPagedLive on _AdminProductionMapOrdersScreenState {
  void _cancelAdminSequenceSyncTimers() {
    for (final timer in _adminSequenceSyncTimers.values) {
      timer.cancel();
    }
    _adminSequenceSyncTimers.clear();
  }

  void _resetAdminSequenceSyncAccount() {
    final account = _adminPageAccount;
    if (_adminSequenceSyncAccount == account) return;
    _cancelAdminSequenceSyncTimers();
    _adminSequenceAcks.clear();
    _adminSequenceAckWindows.clear();
    _adminSequenceSyncAccount = account;
    _adminDetailReads.clear();
  }

  bool _adminWindowCoversSequenceAck(
      _AdminOrderWindow window, AdminSequenceMoveResult ack) {
    if (window.account != _adminPageAccount || !window.loaded || window.dirty ||
        ack.epoch.isEmpty || ack.epoch != window.pages.first.epoch) {
      return false;
    }
    return window.pages.every((page) {
      final snapshot = page.snapshot;
      if (page.epoch != ack.epoch ||
          (!page.isSequenceList && snapshot == null) ||
          page.version != window.pages.first.version ||
          page.revision != window.pages.first.revision) {
        return false;
      }
      final apparatus = window.request.apparatus;
      final revision = page.sequenceRevisions[apparatus];
      final sameVersion = page.sequenceVersions[apparatus] == ack.version;
      if (ack.revision == null) return sameVersion;
      return revision != null && (revision > ack.revision! ||
          (revision == ack.revision && sameVersion));
    });
  }

  void _rememberAdminSequenceAck(String apparatus, AdminSequenceMoveResult result,
      {_AdminOrderWindow? window}) {
    _resetAdminSequenceSyncAccount();
    _adminSequenceAcks[apparatus] = AdminSequenceMoveResult(
      result.orderIds, result.version, result.adjusted,
      revision: result.revision,
      epoch: result.epoch.isEmpty ? _lastAppliedSnapshotEpoch : result.epoch,
      ops: result.ops,
    );
    _adminSequenceAckWindows[apparatus] =
        window ?? _adminWindow('sequence', apparatus: apparatus);
  }

  void _settleAdminSequenceWrite(String apparatus) {
    _resetAdminSequenceSyncAccount();
    final ack = _adminSequenceAcks[apparatus];
    final window = _adminSequenceAckWindows[apparatus];
    if (ack == null || window == null) return;
    if (_adminWindowCoversSequenceAck(window, ack)) {
      _updateScreenState(_rebuildAdminPageState);
      return;
    }
    if (!mounted || !_adminForeground || _queueSnapshotContractError) return;
    final canStream = _adminLiveStarted && !_adminWindowLiveFallback &&
        _workerLiveHealthy && _liveStreamSubscription != null &&
        _adminModuleWindows(_module).contains(window) &&
        window.loaded && window.pages.every((page) => page.wireValue != null);
    if (!canStream) {
      unawaited(_recoverAdminSequenceWindow(apparatus, window));
      return;
    }
    // Keep the first deadline across a burst of writes. Only an authoritative
    // page can cover an ACK; the locally projected ordering cannot certify it.
    _adminSequenceSyncTimers.putIfAbsent(apparatus, () {
      final account = _adminPageAccount;
      return Timer(const Duration(seconds: 2), () {
        _adminSequenceSyncTimers.remove(apparatus);
        if (!mounted || !_adminForeground || account != _adminPageAccount ||
            _queueSnapshotContractError || !_adminSequenceAcks.containsKey(apparatus)) {
          return;
        }
        unawaited(_recoverAdminSequenceWindow(apparatus, window));
      });
    });
  }

  Future<void> _recoverAdminSequenceWindow(
      String apparatus, _AdminOrderWindow window) {
    final account = _adminPageAccount;
    final key = jsonEncode([account, window.liveId]);
    final pending = _adminSequenceRecoveries[key];
    if (pending != null) return pending;
    if (!mounted || !_adminForeground || window.account != account) {
      return Future.value();
    }
    _adminSequenceSyncTimers.remove(apparatus)?.cancel();
    late final Future<void> recovery;
    recovery = _loadAdminWindow(window, force: true).whenComplete(() {
      if (identical(_adminSequenceRecoveries[key], recovery)) {
        _adminSequenceRecoveries.remove(key);
      }
    });
    _adminSequenceRecoveries[key] = recovery;
    return recovery;
  }

  void _stopAdminNotifications() {
    _adminNotificationGeneration++;
    _adminNotificationRetry?.cancel();
    _adminNotificationRetry = null;
    unawaited(_adminNotificationSubscription?.cancel());
    _adminNotificationSubscription = null;
    final finished = _adminNotificationFinished;
    if (finished != null && !finished.isCompleted) finished.complete();
    _adminNotificationFinished = null;
  }

  void _startAdminNotifications() {
    _stopAdminNotifications();
    if (widget.liveEventsLoader != null && widget.notificationEventsLoader == null) return;
    unawaited(_runAdminNotifications(_adminNotificationGeneration));
  }

  Future<void> _runAdminNotifications(int generation) async {
    if (widget.notificationEventsLoader == null && await TestModeController.instance.isEnabled()) return;
    final scope = currentSessionReadScope();
    bool active() => mounted && _adminForeground && generation == _adminNotificationGeneration &&
        scope == currentSessionReadScope();
    var attempt = 0;
    while (active()) {
      final finished = Completer<void>();
      _adminNotificationFinished = finished;
      final first = Timer(const Duration(seconds: 10), () {
        if (!finished.isCompleted) finished.completeError(TimeoutException('Notifications'));
      });
      StreamSubscription<List<AdminCompletionRequestNotification>>? subscription;
      try {
        subscription = (widget.notificationEventsLoader?.call() ??
          MobileApi.instance.adminProductionMapNotificationEvents()).listen((requests) {
            if (!active()) return;
            first.cancel();
            attempt = 0;
            _updateScreenState(() {
              _completionRequestsGeneration++;
              _completionRequests = requests;
              _completionRequestsErrorMessage = null;
              _reconnectingOrderReads.remove(_OrdersReadSection.completionRequests);
            });
          }, onError: (Object error, StackTrace stack) {
            if (!finished.isCompleted) finished.completeError(error, stack);
          }, onDone: () { if (!finished.isCompleted) finished.complete(); });
        _adminNotificationSubscription = subscription;
        await finished.future;
      } catch (error) {
        if (!active()) return;
        if (error is MobileApiException && (error.statusCode == 401 || error.statusCode == 403 ||
            const {'forbidden', 'unauthorized', 'permission_denied'}.contains(error.code))) return;
      } finally {
        first.cancel();
        unawaited(subscription?.cancel());
        if (identical(_adminNotificationSubscription, subscription)) {
          _adminNotificationSubscription = null;
        }
      }
      if (!active()) return;
      final delay = productionMapLiveReconnectDelay(attempt++);
      final retry = Completer<void>();
      _adminNotificationFinished = retry;
      _adminNotificationRetry = Timer(Duration(milliseconds:
        (delay.inMilliseconds * (0.5 + Random().nextDouble() * 0.5)).round()), retry.complete);
      await retry.future;
    }
  }

  Future<void> _restartAdminPagedLive() async {
    _stopWorkerLiveStream();
    final generation = _liveStreamGeneration;
    _adminSubscriptionFingerprint = _adminWindowFingerprint();
    if (await TestModeController.instance.isEnabled() &&
        (widget.liveEventsLoader == null || _adminLiveDescriptors().isEmpty)) return;
    if (!mounted || !_adminForeground || generation != _liveStreamGeneration) {
      return;
    }
    _adminSubscriptionFingerprint = _adminWindowFingerprint();
    final descriptors = _adminLiveDescriptors();
    if (descriptors.isNotEmpty) {
      _updateScreenState(() {
        for (final window in _adminModuleWindows(_module)) {
          window.awaitingLive = true;
        }
        _queueSnapshotNeedsReconcile = true;
      });
    }
    unawaited(_runWorkerLiveStream(generation));
  }


  List<Map<String, Object?>> _adminLiveDescriptors() {
    if (_adminWindowLiveFallback) return const [];
    final windows = _adminModuleWindows(_module);
    if (windows.isEmpty ||
        windows
            .any((w) => !w.loaded || w.pages.any((p) => p.wireValue == null)))
      return const [];
    return [
      for (final window in windows)
        {
          'id': window.liveId,
          'view': window.request.view,
          if (window.pages.first.isSequenceList)
            'projection': adminSequenceListProjection,
          'apparatus': window.request.apparatus,
          'target': window.request.target,
          'search': window.request.search,
          'length': max(20, window.length),
          'version': window.pages.first.version,
        }
    ];
  }

  String _adminWindowFingerprint() => jsonEncode([
    _adminPageAccount, _adminWindowLiveFallback,
    for (final descriptor in _adminLiveDescriptors())
      {...descriptor}..remove('version'),
  ]);

  void _scheduleAdminWindowSubscription() {
    if (!_adminLiveStarted || !_adminForeground || !_adminPaging || !mounted) return;
    if (_adminSubscriptionFingerprint != _adminWindowFingerprint() &&
        _adminLiveDescriptors().isNotEmpty) {
      _updateScreenState(() {
        for (final window in _adminModuleWindows(_module)) {
          window.awaitingLive = true;
        }
        _queueSnapshotNeedsReconcile = true;
      });
    }
    _adminSubscriptionTimer?.cancel();
    _adminSubscriptionTimer = Timer(const Duration(milliseconds: 30), () {
      if (!mounted || !_adminForeground) return;
      if (_adminSubscriptionFingerprint != _adminWindowFingerprint()) {
        unawaited(_restartAdminPagedLive());
      }
    });
  }

  void _queueAdminWindowLive(AdminProductionMapPageWindowMessage message, int generation,
      {required int? subscribedLength}) {
    final account = _adminPageAccount;
    _adminWindowEvents = _adminWindowEvents.then((_) async {
      if (!mounted || generation != _liveStreamGeneration || account != _adminPageAccount) return;
      final window = _adminModuleWindows(_module)
          .where((window) => window.liveId == message.window).firstOrNull;
      if (window == null || !window.loaded || _retiredSnapshotEpochs.contains(message.epoch)) return;
      if (subscribedLength == null || max(20, window.length) != subscribedLength) {
        // An HTTP append changes the subscribed prefix before the debounced
        // reconnect. Never let its old shorter stream erase newly loaded rows.
        _scheduleAdminWindowSubscription();
        return;
      }
      final publishedBefore = window.pages;
      final before = window.sequencePendingPages ?? publishedBefore;
      if (message.epoch == before.first.epoch &&
          message.revision < (before.first.revision ?? -1)) return;
      try {
        if (message.type == 'page_window_ready') {
          if (message.value['resync'] != false ||
              message.version != before.first.version ||
              message.epoch != before.first.epoch ||
              message.revision != before.first.revision ||
              before.any(_adminPageBehindSequenceMoves)) {
            throw StateError('page window needs reconciliation');
          }
          _updateScreenState(() {
            window.awaitingLive = false;
            window.cacheNeedsValidation = false;
            window.validated = window.invalidation;
            window.error = null;
            _rebuildAdminPageState();
          });
          ProductionDataRevision.notify(epoch: message.epoch, revision: message.revision);
          _saveAdminPageCache();
          return;
        }
        if (message.type == 'page_window_resync') throw StateError('page history unavailable');
        // Duplicate frames are harmless; applying a second patch would not be.
        if (message.version == before.first.version &&
            message.epoch == before.first.epoch && message.revision == before.first.revision) return;
        final next = await applyAdminOrderPageWindow(before, message);
        if (!mounted || generation != _liveStreamGeneration || account != _adminPageAccount) return;
        if (!identical(window.sequencePendingPages ?? window.pages, before)) {
          // A concurrent HTTP append or mutation reconciliation owns the newer
          // baseline. Re-subscribe from it rather than applying an old patch.
          await _restartAdminPagedLive();
          return;
        }
        if (next.any(_adminPageBehindSequenceMoves)) {
          if (_adminSequenceAcks.containsKey(window.request.apparatus)) {
            // Retain the wire baseline for the next incremental patch without
            // publishing pre-ACK colors or action permissions to the widgets.
            window.sequencePendingPages = next;
            return;
          }
          throw StateError('page window precedes confirmed sequence move');
        }
        _adminLiveEpoch = message.epoch;
        _adminLiveRevision = max(_adminLiveRevision, message.revision);
        window.sequencePendingPages = null;
        window.pages = next;
        window.validated = window.invalidation;
        window.error = null;
        ProductionDataRevision.notify(epoch: message.epoch, revision: message.revision);
        if (message.type == 'page_window_checkpoint' && !window.awaitingLive &&
            !_queueSnapshotNeedsReconcile && _adminActiveWindowVersionsMatch()) {
          // Certify the shared action snapshot only through the oldest active
          // window. A checkpoint must never authorize rows from another tab.
          final current = _canonicalQueueSnapshot;
          final active = [for (final w in _adminModuleWindows(_module))
            for (final page in w.pages) if (page.snapshot != null) page.snapshot!];
          if (current != null && active.isNotEmpty &&
              active.every((snapshot) => snapshot.epoch == current.epoch)) {
            final revision = active.map((snapshot) => snapshot.revision ?? 0).reduce(min);
            if (revision > (current.revision ?? -1)) {
              final advanced = AdminProductionMapLiveStateDelta(
                epoch: current.epoch, scope: current.scope,
                baseRevision: current.revision!, revision: revision, patch: const {},
              ).applyTo(current);
              _canonicalQueueSnapshot = advanced;
              _rememberSnapshotVersion(advanced);
              _sheetQueueSnapshot.value = advanced;
            }
          }
          _saveAdminPageCache();
          return;
        }
        _updateScreenState(() {
          window.awaitingLive = false;
          window.cacheNeedsValidation = false;
          if (window.request.view == 'sequence') {
            _sequenceNeedsSnapshot.remove(window.request.apparatus);
          }
          _rebuildAdminPageState();
          _clearOrdersLoadError();
        });
        for (var index = 0; index < next.length; index++) {
          final page = next[index];
          if (index >= publishedBefore.length ||
              !identical(page.snapshot?.maps, publishedBefore[index].snapshot?.maps) ||
              !identical(page.wireValue?['calculation_templates'],
                  publishedBefore[index].wireValue?['calculation_templates'])) {
            unawaited(_loadAdminPageMetrics(page, account));
          }
        }
        _saveAdminPageCache();
        _scheduleAdminWindowSubscription();
      } catch (_) {
        if (!mounted || generation != _liveStreamGeneration || account != _adminPageAccount) return;
        _updateScreenState(() {
          window.invalidation = ++_adminPageInvalidation;
          window.awaitingLive = true;
          _queueSnapshotNeedsReconcile = true;
        });
        if (_adminSequenceAcks.containsKey(window.request.apparatus)) {
          await _recoverAdminSequenceWindow(window.request.apparatus, window);
        } else {
          await _loadAdminWindow(window, force: true);
        }
        if (mounted && generation == _liveStreamGeneration && account == _adminPageAccount) {
          await _restartAdminPagedLive();
        }
      }
    });
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
    ProductionDataRevision.notify(epoch: epoch, revision: revision);
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
          !_adminActiveWindowVersionsMatch() ||
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
    _rememberAdminSequenceAck(apparatus, AdminSequenceMoveResult(
        next, delta.version, false,
        revision: delta.revision, epoch: delta.epoch), window: window);
  }
}
