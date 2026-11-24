part of 'preparation_production_screen.dart';

typedef _JournalFilter = ({_ProductionView view, String query, String status});

const _journalPageSize = 50;
const _maxJournalWindow = 10000;
const _maxCachedJournalFilters = 8;

class _CachedJournal {
  const _CachedJournal(this.rows, this.pages, this.nextOffset, this.checkpoint);

  final List<PreparationProductionRow> rows;
  final int pages;
  final int? nextOffset;
  final PreparationJournalCheckpoint? checkpoint;

  _CachedJournal apply(
      _ProductionView view, Map<String, dynamic> frame, int pages) {
    const invalid = FormatException('Jurnal sinxronlash javobi noto‘g‘ri');
    final previous = checkpoint;
    final type = frame['type'];
    if (type == 'unchanged') {
      if (previous == null || frame['version'] != previous.version) {
        throw invalid;
      }
      return this;
    }
    if (previous == null ? type != 'snapshot' : type != 'delta') throw invalid;
    if (frame['base_version'] != previous?.version) throw invalid;
    final next = PreparationJournalCheckpoint.decode(frame['journal_sync']);
    final upserts = frame['upserts'];
    final more = frame['has_more'];
    final offset = frame['next_offset'];
    if (next == null ||
        upserts is! Map<String, dynamic> ||
        more is! bool ||
        next.hashes.length > pages * _journalPageSize ||
        (more
            ? offset is! int || offset != next.hashes.length || offset == 0
            : offset != null)) {
      throw invalid;
    }
    final available = <String, PreparationProductionRow>{
      if (previous != null)
        for (var i = 0; i < previous.hashes.length; i++)
          previous.hashes[i]: rows[i],
    };
    for (final entry in upserts.entries) {
      final data = entry.value;
      if (data is! Map<String, dynamic> || available.containsKey(entry.key)) {
        throw invalid;
      }
      available[entry.key] = switch (view) {
        _ProductionView.orders => PreparationProductionOrder.fromJson(data),
        _ProductionView.batches => PreparationProductionBatch.fromJson(data),
        _ProductionView.rolls => PreparationProductionRoll.fromJson(data),
        _ProductionView.paddons => PreparationMaterialPaddon.fromJson(data),
      };
    }
    final ordered = <PreparationProductionRow>[];
    final ids = <String>{};
    for (final hash in next.hashes) {
      final row = available[hash];
      if (row == null || !ids.add(row.journalKey)) throw invalid;
      ordered.add(row);
    }
    return _CachedJournal(ordered, pages, offset as int?, next);
  }
}

mixin _ProductionJournalSync
    on _JournalState<PreparationProductionScreen, PreparationProductionRow> {
  _JournalFilter get _journalFilter;

  final _journalCache = <_JournalFilter, _CachedJournal>{};
  Completer<void>? _journalAbort;
  Timer? _journalWatchTimer;
  bool _journalSyncing = false;
  bool _syncUnavailable = false;

  _CachedJournal? get _cachedJournal => _journalCache[_journalFilter];

  @override
  bool get _pollPages => _syncUnavailable || _cachedJournal?.checkpoint == null;

  @override
  bool get _userReadBusy => _pollPages ? super._userReadBusy : _journalSyncing;

  void _rememberJournal(_JournalFilter filter, _CachedJournal window) {
    _journalCache.remove(filter);
    _journalCache[filter] = window;
    if (_journalCache.length > _maxCachedJournalFilters) {
      _journalCache.remove(_journalCache.keys.first);
    }
  }

  void _restoreJournal(_CachedJournal? window) {
    if (window != null) _rememberJournal(_journalFilter, window);
    items = window?.rows ?? [];
    nextOffset = window?.nextOffset;
    hasMore = nextOffset != null;
    _loadedPages = window?.pages ?? 0;
    error = null;
    loading = window == null;
  }

  @override
  void received(PreparationProductionPage page) {
    if (widget.materialPaddonsOnly) return;
    final checkpoint = page.journalCheckpoint;
    _rememberJournal(
      _journalFilter,
      _CachedJournal(
        items,
        _loadedPages,
        hasMore ? nextOffset : null,
        !_syncUnavailable &&
                _loadedPages == 1 &&
                checkpoint?.hashes.length == items.length
            ? checkpoint
            : null,
      ),
    );
    _scheduleJournalWatch();
  }

  @override
  void clearSummary() {
    _stopJournalSync();
    _journalCache.clear();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.isCurrentOf(context) != false) {
      _scheduleJournalWatch();
    } else if (!_journalSyncing) {
      _stopJournalSync();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _scheduleJournalWatch();
    } else if (!_journalSyncing) {
      _stopJournalSync();
    }
  }

  @override
  void dispose() {
    _stopJournalSync();
    super.dispose();
  }

  void _stopJournalSync() {
    _journalWatchTimer?.cancel();
    _journalAbort?.complete();
    _journalAbort = null;
    _journalSyncing = false;
  }

  void _scheduleJournalWatch(
      [Duration delay = const Duration(milliseconds: 250)]) {
    _journalWatchTimer?.cancel();
    if (_pollPages || _journalAbort != null) return;
    _journalWatchTimer = Timer(delay, () {
      if (canRefresh) unawaited(_syncJournal(watch: true));
    });
  }

  @override
  Future<void> load({bool append = false, bool silent = false}) async {
    if (!mounted || !currentAccount) return;
    final window = _cachedJournal;
    if (_pollPages ||
        (append && window!.pages * _journalPageSize >= _maxJournalWindow)) {
      _stopJournalSync();
      return super.load(append: append, silent: silent);
    }
    if (append && !hasMore) return;
    await _syncJournal(append: append, silent: silent);
  }

  Future<void> _syncJournal(
      {bool watch = false, bool append = false, bool silent = false}) async {
    final before = _cachedJournal;
    if (_pollPages || (watch && _journalAbort != null)) return;
    final filter = _journalFilter;
    final pages = before!.pages + (append ? 1 : 0);
    _stopJournalSync();
    final abort = _journalAbort = Completer<void>();
    bool isCurrent() =>
        mounted &&
        currentAccount &&
        identical(_journalAbort, abort) &&
        filter == _journalFilter;

    if (!watch) {
      setState(() {
        _journalSyncing = true;
        loading = append && !silent;
        error = null;
      });
    }

    Future<Map<String, dynamic>> read(PreparationJournalCheckpoint? baseline) =>
        MobileApi.instance.syncPreparationJournal(
          view: filter.view.name,
          query: filter.query,
          status: filter.status,
          length: pages * _journalPageSize,
          baseline: baseline,
          watch: watch && baseline != null,
          abort: abort.future,
        );

    var retry = false;
    try {
      final frame = await read(before.checkpoint);
      if (!isCurrent()) return;
      _CachedJournal next;
      try {
        next = before.apply(filter.view, frame, pages);
      } on FormatException {
        final snapshot = await read(null);
        if (!isCurrent()) return;
        next = const _CachedJournal([], 0, null, null)
            .apply(filter.view, snapshot, pages);
      }
      if (!identical(before, next) || error != null) {
        setState(() => _restoreJournal(next));
      }
    } catch (failure) {
      if (!isCurrent()) return;
      retry = true;
      final status = failure is MobileApiException ? failure.statusCode : null;
      if (status == 404 || status == 405) {
        _syncUnavailable = true;
        _rememberJournal(filter,
            _CachedJournal(before.rows, before.pages, before.nextOffset, null));
      } else if (status == 401 || status == 403) {
        setState(() {
          clearSummary();
          _restoreJournal(null);
          loading = false;
          error = (failure as MobileApiException).message;
        });
      } else if (!watch && !silent) {
        setState(() => error = failure is MobileApiException
            ? failure.message
            : 'Ma’lumotlarni yuklab bo‘lmadi. Qayta urinib ko‘ring');
      }
    } finally {
      if (isCurrent()) {
        abort.complete();
        _journalAbort = null;
        if (_journalSyncing) {
          setState(() {
            _journalSyncing = false;
            loading = false;
          });
        }
        if (retry) {
          _scheduleJournalWatch(const Duration(seconds: 3));
        } else {
          _scheduleJournalWatch();
        }
      }
    }
    if (_syncUnavailable &&
        mounted &&
        currentAccount &&
        filter == _journalFilter) {
      await super.load(append: append, silent: silent || watch);
    }
  }
}
