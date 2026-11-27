import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/session/session.dart';
import '../../../core/session/session_read_scope.dart';
import '../models/preparation_models.dart';

typedef _Cursor = ({String epoch, int revision});
typedef FormulaLibraryLive = Stream<Map<String, dynamic>> Function(
    String epoch, int revision);

/// One account's library can be reused across both tabs and page openings.
/// A subscription exists only while it has a screen and the app is visible.
class PreparationFormulaLibraryStore extends ChangeNotifier
    with WidgetsBindingObserver {
  PreparationFormulaLibraryStore({FormulaLibraryLive? connectLive})
      : _connect =
            connectLive ?? MobileApi.instance.preparationFormulaLibraryLive {
    AppSession.instance.revision.addListener(_sessionChanged);
  }

  static final instance = PreparationFormulaLibraryStore();
  final FormulaLibraryLive _connect;
  String? _scope;
  int _generation = 0, _liveGeneration = 0, _screens = 0, _retryAttempt = 0;
  bool _visible = true, _ready = false;
  Future<void>? _pending;
  Completer<void>? _manualSync;
  _Cursor? _cursor;
  List<PreparationFormulaSet>? _sets;
  List<PreparationFormulaCatalogEntry>? _recipes;
  final _recipesByProduct = <String, List<PreparationFormulaCatalogEntry>>{};
  StreamSubscription<Map<String, dynamic>>? _stream;
  Timer? _retry;
  Object? error;

  List<PreparationFormulaSet> get sets => _sets ?? const [];
  List<PreparationFormulaCatalogEntry> get recipes => _recipes ?? const [];
  bool hasList(bool saved) => saved ? _recipes != null : _sets != null;
  List<PreparationFormulaCatalogEntry> recipesFor(String product) =>
      _recipesByProduct[product] ?? const [];

  String? get _sessionScope =>
      AppSession.instance.isLoggedIn ? currentSessionReadScope() : null;
  bool get _current => _scope != null && _scope == _sessionScope;

  void attach() {
    _sessionChanged();
    _scope = _sessionScope;
    if (_screens++ == 0) {
      final binding = WidgetsBinding.instance;
      _visible = _isVisible(binding.lifecycleState);
      binding.addObserver(this);
    }
  }

  void detach() {
    if (--_screens != 0) return;
    WidgetsBinding.instance.removeObserver(this);
    _stopLive();
  }

  static bool _isVisible(AppLifecycleState? state) =>
      state == null ||
      state == AppLifecycleState.resumed ||
      state == AppLifecycleState.inactive;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = _isVisible(state);
    if (_visible) {
      _startLive();
    } else {
      _stopLive();
    }
  }

  void _sessionChanged() {
    if (_scope == null || _scope == _sessionScope) return;
    _reset();
    notifyListeners();
  }

  void _reset() {
    _scope = null;
    _generation++;
    _pending = null;
    _evictLists();
    _retryAttempt = 0;
    error = null;
    _stopLive();
  }

  bool _loaded(bool saved) => _recipes != null && (saved || _sets != null);

  Future<void> ensure(bool saved) async {
    if (!_current) return;
    final pending = _pending;
    if (pending != null) {
      await pending;
      if (!_current || error != null) return;
    }
    if (_loaded(saved)) {
      _startLive();
    } else {
      await _read(saved);
    }
  }

  Future<void> refresh(bool saved) async {
    if (!_current) return;
    if (_ready && _cursor != null) {
      _stopLive();
      final sync = _manualSync = Completer<void>();
      _startLive();
      await sync.future.timeout(const Duration(seconds: 10), onTimeout: () {});
      if (identical(_manualSync, sync)) _manualSync = null;
    } else {
      await _read(saved, force: true);
    }
  }

  Future<void> afterEdit({required bool saved}) async {
    if (!_current) return;
    if (_cursor == null) {
      await _read(saved, force: true);
    } else if (!_ready) {
      _stopLive();
      _startLive();
    }
  }

  void renamedSet(String id, String name) {
    // Older servers do not send a delta. Preserve their immediate rename.
    if (!_current || _sets == null) return;
    if (_cursor != null) {
      unawaited(afterEdit(saved: false));
      return;
    }
    _sets = [
      for (final set in sets)
        if (set.id == id) set.copyWith(name: name) else set,
    ];
    notifyListeners();
  }

  void removedFormula(String setId, PreparationScopedFormula removed) {
    if (!_current) return;
    if (_cursor != null) {
      unawaited(afterEdit(saved: false));
      return;
    }
    final set = sets.where((row) => row.id == setId).firstOrNull;
    if (set == null) return;
    final remaining = set.formulas
        .where((row) =>
            row.materialId != removed.materialId ||
            row.variantId != removed.variantId ||
            row.formula.name != removed.formula.name)
        .toList();
    _sets = [
      for (final row in sets)
        if (row.id != setId)
          row
        else if (remaining.isNotEmpty)
          row.copyWith(formulas: remaining),
    ];
    notifyListeners();
  }

  Future<void> _read(bool saved, {bool force = false}) {
    final existing = _pending;
    if (existing != null) return existing;
    final generation = _generation;
    bool current() => _current && generation == _generation;
    _stopLive();
    error = null;
    late final Future<void> pending;
    pending = () async {
      try {
        final data =
            await MobileApi.instance.preparationFormulaLibrary(saved: saved);
        if (!current()) return;
        var nextSets = _decodeSets(data['sets']);
        var nextRecipes = _decodeRecipes(data['formulas']);
        final cursor =
            data['cursor'] == null ? null : _decodeCursor(data['cursor']);
        if (cursor != null && (nextSets == null || nextRecipes == null)) {
          throw const FormatException('Incomplete formula library snapshot');
        }
        if (saved && nextRecipes == null || !saved && nextSets == null) {
          throw const FormatException('Missing formula list');
        }
        // The first visit to another tab may still need its list on older ERP
        // versions. Reuse any list already loaded for this account.
        if (nextRecipes == null && (_recipes == null || force)) {
          nextRecipes = await MobileApi.instance.preparationFormulaCatalog();
        }
        if (force && nextSets == null && _sets != null) {
          nextSets = await MobileApi.instance.preparationFormulaSets();
        }
        if (!current()) return;
        if (nextSets != null) _sets = nextSets;
        if (nextRecipes != null) _setRecipes(nextRecipes);
        _cursor = cursor;
      } catch (failure) {
        if (current()) {
          if (failure is MobileApiException &&
              (failure.statusCode == 401 || failure.statusCode == 403)) {
            _evictLists();
          }
          error = failure;
        }
      } finally {
        if (current()) {
          if (identical(_pending, pending)) _pending = null;
          notifyListeners();
          _startLive();
        }
      }
    }();
    _pending = pending;
    return pending;
  }

  void _startLive() {
    final cursor = _cursor;
    if (!_current ||
        !_visible ||
        _screens == 0 ||
        _pending != null ||
        cursor == null ||
        _stream != null ||
        _retry != null) {
      return;
    }
    final generation = ++_liveGeneration;
    bool active() => _current && generation == _liveGeneration;
    try {
      _stream = _connect(cursor.epoch, cursor.revision).listen(
        (frame) {
          if (!active()) return;
          if (frame['status'] == 401 || frame['status'] == 403) {
            _accessEnded(frame['status'] as int);
            return;
          }
          try {
            _apply(frame);
            _ready = true;
            _retryAttempt = 0;
            _finishManualSync();
          } on FormatException {
            // Ask for a fresh baseline if the stream cannot extend this one.
            _cursor = (epoch: '', revision: 0);
            _reconnect();
          } on TypeError {
            _cursor = (epoch: '', revision: 0);
            _reconnect();
          }
        },
        onError: (Object failure) {
          if (!active()) return;
          if (failure is MobileApiException &&
              (failure.statusCode == 401 || failure.statusCode == 403)) {
            _accessEnded(failure.statusCode!);
          } else {
            _reconnect();
          }
        },
        onDone: () {
          if (active()) _reconnect();
        },
      );
    } catch (_) {
      if (active()) _reconnect();
    }
  }

  void _apply(Map<String, dynamic> frame) {
    final cursor = _decodeCursor(frame['cursor']);
    final base = _cursor!;
    final kind = frame['type'];
    if (kind != 'snapshot' &&
        (cursor.epoch != base.epoch || cursor.revision < base.revision)) {
      throw const FormatException('Invalid formula library revision');
    }
    if (kind == 'checkpoint') {
      _cursor = cursor;
      if (error != null) {
        error = null;
        notifyListeners();
      }
      return;
    }
    final sets = _decodeSets(frame['sets']);
    final recipes = _decodeRecipes(frame['formulas']);
    if (sets == null || recipes == null) {
      throw const FormatException('Missing formula list');
    }
    if (kind == 'snapshot') {
      _sets = sets;
      _setRecipes(recipes);
    } else {
      if (kind != 'delta' ||
          frame['base_revision'] != base.revision ||
          cursor.revision <= base.revision) {
        throw const FormatException('Missing formula library base');
      }
      final products = Set<String>.from(frame['products'] as List);
      if (products.isEmpty ||
          sets.any((row) => !products.contains(row.productCode)) ||
          recipes.any((row) => !products.contains(row.productCode))) {
        throw const FormatException('Invalid formula library delta');
      }
      _sets = [
        ...this.sets.where((row) => !products.contains(row.productCode)),
        ...sets,
      ]..sort((a, b) => _sortRows(a.sortAt, a.id, b.sortAt, b.id));
      _setRecipes([
        ...this.recipes.where((row) => !products.contains(row.productCode)),
        ...recipes,
      ]..sort((a, b) => _sortRows(a.sortAt, a.id, b.sortAt, b.id)));
    }
    _cursor = cursor;
    error = null;
    notifyListeners();
  }

  static int _sortRows(int a, String aId, int b, String bId) {
    final time = b.compareTo(a);
    return time == 0 ? aId.compareTo(bId) : time;
  }

  void _setRecipes(List<PreparationFormulaCatalogEntry> values) {
    _recipes = values;
    _recipesByProduct.clear();
    for (final recipe in values) {
      (_recipesByProduct[recipe.productCode] ??= []).add(recipe);
    }
  }

  void _reconnect() {
    _stopLive();
    final shift = _retryAttempt < 5 ? _retryAttempt++ : 5;
    _retry = Timer(Duration(milliseconds: 500 << shift), () {
      _retry = null;
      _startLive();
    });
  }

  void _stopLive() {
    _liveGeneration++;
    _ready = false;
    _retry?.cancel();
    _retry = null;
    unawaited(_stream?.cancel());
    _stream = null;
    _finishManualSync();
  }

  void _finishManualSync() {
    _manualSync?.complete();
    _manualSync = null;
  }

  void _evictLists() {
    _sets = null;
    _recipes = null;
    _recipesByProduct.clear();
    _cursor = null;
  }

  void _accessEnded(int status) {
    _stopLive();
    _evictLists();
    error = MobileApiException(
      code: status == 401 ? 'unauthorized' : 'forbidden',
      message: 'Formulalar yuklanmadi',
      statusCode: status,
    );
    notifyListeners();
  }

  static _Cursor _decodeCursor(Object? raw) {
    if (raw is Map &&
        raw['epoch'] is String &&
        raw['revision'] is int &&
        (raw['epoch'] as String).isNotEmpty &&
        (raw['revision'] as int) >= 0) {
      return (epoch: raw['epoch'] as String, revision: raw['revision'] as int);
    }
    throw const FormatException('Invalid formula library cursor');
  }

  static List<PreparationFormulaSet>? _decodeSets(Object? raw) => (raw as List?)
      ?.map((row) =>
          PreparationFormulaSet.fromJson((row as Map).cast<String, dynamic>()))
      .toList();

  static List<PreparationFormulaCatalogEntry>? _decodeRecipes(Object? raw) =>
      (raw as List?)
          ?.map((row) => PreparationFormulaCatalogEntry.fromJson(
              (row as Map).cast<String, dynamic>()))
          .toList();

  @override
  void dispose() {
    AppSession.instance.revision.removeListener(_sessionChanged);
    if (_screens > 0) WidgetsBinding.instance.removeObserver(this);
    _reset();
    super.dispose();
  }
}
