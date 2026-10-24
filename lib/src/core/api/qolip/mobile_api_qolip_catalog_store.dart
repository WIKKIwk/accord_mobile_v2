part of '../mobile_api.dart';

class QolipCatalogWindow {
  List<QolipCatalogItem> items = const [];
  String? nextCursor;
  bool loaded = false;
  double scrollOffset = 0;
}

/// Session-scoped name pages. Preparation and visible pages share reads;
/// successful writes publish their own delta, without a timer or socket.
class QolipCatalogStore extends ChangeNotifier {
  static final instance = QolipCatalogStore();
  String? _scope;
  int _generation = 0;
  int _writeVersion = 0;
  int _detailsGeneration = 0;
  final _windows = <String, QolipCatalogWindow>{};
  final _requests = <String, Future<QolipCatalogWindow>>{};
  final _details = <String, List<QolipProduct>>{};
  final _searchTerms = <String, List<String>>{};
  final _detailReads = <String, Future<List<QolipProduct>>>{};
  final _overrides = <String, QolipCatalogItem?>{};

  String get _currentScope => jsonEncode([
        currentSessionReadScope(),
        AppSession.instance.isTestModeSession,
      ]);

  void _synchronize() {
    if (_scope == _currentScope) return;
    reset();
    _scope = _currentScope;
  }

  void reset() {
    _generation++;
    _writeVersion++;
    _scope = null;
    _windows.clear();
    _requests.clear();
    _details.clear();
    _searchTerms.clear();
    _detailReads.clear();
    _overrides.clear();
  }

  QolipCatalogWindow window(String query) {
    _synchronize();
    return _windows.putIfAbsent(
        query.trim().toLowerCase(), QolipCatalogWindow.new);
  }

  List<QolipProduct>? details(String id) {
    _synchronize();
    return _details[id];
  }

  void invalidateDetails() {
    _detailsGeneration++;
    _details.clear();
    _detailReads.clear();
    notifyListeners();
  }

  Future<void> prepare() async {
    try {
      await first();
    } catch (_) {/* Optional preparation is retried when the page opens. */}
  }

  Future<QolipCatalogWindow> first({String query = '', bool force = false}) {
    final target = window(query);
    if (force) {
      // A manual refresh replaces the baseline and every cached detail.
      reset();
      _scope = _currentScope;
      return first(query: query);
    }
    if (target.loaded) return Future.value(target);
    return _read(query, null, target);
  }

  Future<QolipCatalogWindow> more(String query) {
    final target = window(query);
    if (!target.loaded) return first(query: query);
    if (target.nextCursor == null) return Future.value(target);
    return _read(query, target.nextCursor, target);
  }

  Future<QolipCatalogWindow> _read(
      String query, String? cursor, QolipCatalogWindow target) {
    final key = jsonEncode([query.trim().toLowerCase(), cursor]);
    final existing = _requests[key];
    if (existing != null) return existing;
    final generation = _generation;
    final scope = _scope;
    late final Future<QolipCatalogWindow> pending;
    pending = (() async {
      try {
        final page = await MobileApi.instance
            .qolipCatalogPage(query: query, cursor: cursor);
        if (generation != _generation || scope != _currentScope) {
          throw StateError('Qolip catalog session changed');
        }
        final rows = <String, QolipCatalogItem>{
          if (cursor != null)
            for (final item in target.items) item.id: item,
          for (final item in page.items) item.id: item,
        };
        _applyOverrides(rows, query);
        target.items = _sorted(rows.values);
        target.nextCursor = page.nextCursor;
        target.loaded = true;
        return target;
      } finally {
        if (identical(_requests[key], pending)) _requests.remove(key);
      }
    })();
    _requests[key] = pending;
    return pending;
  }

  Future<List<QolipProduct>> loadDetails(String id) {
    _synchronize();
    final cached = _details[id];
    if (cached != null) return Future.value(cached);
    final existing = _detailReads[id];
    if (existing != null) return existing;
    final generation = _generation;
    final version = _writeVersion;
    final detailGeneration = _detailsGeneration;
    final scope = _scope;
    late final Future<List<QolipProduct>> pending;
    pending = (() async {
      try {
        final products = await MobileApi.instance.qolipCatalogDetails(id);
        if (generation != _generation || scope != _currentScope) {
          throw StateError('Qolip catalog session changed');
        }
        if (detailGeneration != _detailsGeneration) {
          throw StateError('Qolip availability changed');
        }
        if (version != _writeVersion && _overrides.containsKey(id)) {
          final current = _details[id];
          if (current == null) throw StateError('Qolip product removed');
          return current;
        }
        _details[id] = products;
        _searchTerms[id] = _terms(products);
        return products;
      } finally {
        if (identical(_detailReads[id], pending)) _detailReads.remove(id);
      }
    })();
    _detailReads[id] = pending;
    return pending;
  }

  void applyResponse(Map<String, dynamic> response, String requestScope) {
    if (requestScope != currentSessionReadScope()) return;
    _synchronize();
    final delta = response['catalog_delta'];
    if (delta is! Map || delta['reset'] == true) {
      reset();
      notifyListeners();
      return;
    }
    try {
      final upserts = (delta['upserts'] as List).map((raw) {
        final row = raw as Map;
        final products = (row['products'] as List)
            .map((raw) =>
                QolipProduct.fromJson((raw as Map).cast<String, dynamic>()))
            .toList(growable: false);
        if (products.isEmpty) {
          throw const FormatException('Empty catalog delta');
        }
        return (
          QolipCatalogItem(
              id: row['id'] as String,
              name: row['name'] as String,
              orderImageOrderId: row['order_image_order_id'] as String? ?? ''),
          products
        );
      }).toList();
      final removed = (delta['removed_ids'] as List).cast<String>();
      _writeVersion++;
      for (final id in removed) {
        _overrides[id] = null;
        _details.remove(id);
        _searchTerms.remove(id);
      }
      for (final (item, products) in upserts) {
        _overrides[item.id] = item;
        _details[item.id] = List.unmodifiable(products);
        _searchTerms[item.id] = _terms(products);
      }
      for (final entry in _windows.entries) {
        final rows = {for (final item in entry.value.items) item.id: item};
        _applyOverrides(rows, entry.key);
        entry.value.items = _sorted(rows.values);
      }
      notifyListeners();
    } catch (_) {
      reset();
      notifyListeners();
    }
  }

  Future<void> applyTestMode() async {
    if (_windows.isEmpty && _details.isEmpty) return;
    final scope = currentSessionReadScope();
    final products = await MobileApi.instance
        .qolipProducts(limit: 20000, withQolipOnly: true);
    final groups = <String, List<QolipProduct>>{};
    for (final product in products.where((item) => item.qolipCode.isNotEmpty)) {
      groups
          .putIfAbsent(product.code.trim().toLowerCase(), () => [])
          .add(product);
    }
    final upserts = [
      for (final entry in groups.entries)
        {
          'id': qolipCatalogId(entry.key),
          'name': entry.value.first.name,
          'order_image_order_id': entry.value.first.orderImageOrderId,
          'products': [
            for (final item in entry.value)
              {
                'code': item.code,
                'name': item.name,
                'item_group': item.itemGroup,
                'warehouse': item.warehouse,
                'qolip_code': item.qolipCode,
                'qolip_set_id': item.qolipSetId,
                'size': item.qolipSize,
                'color': item.qolipColor,
                'has_qolip_spec': item.hasQolipSpec,
                'is_in_use': item.isInUse,
                'is_extension': item.isExtension,
                'customer_names': item.customerNames,
                'order_image_order_id': item.orderImageOrderId,
              }
          ],
        }
    ];
    final ids = upserts.map((item) => item['id']).toSet();
    applyResponse({
      'catalog_delta': {
        'upserts': upserts,
        'removed_ids': [
          for (final window in _windows.values)
            for (final item in window.items)
              if (!ids.contains(item.id)) item.id
        ]
      }
    }, scope);
  }

  void _applyOverrides(Map<String, QolipCatalogItem> rows, String query) {
    for (final entry in _overrides.entries) {
      final item = entry.value;
      if (item == null || !_matches(item, query)) {
        rows.remove(entry.key);
      } else {
        rows[entry.key] = item;
      }
    }
  }

  bool _matches(QolipCatalogItem item, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || item.name.toLowerCase().contains(q)) return true;
    return (_searchTerms[item.id] ?? const <String>[])
        .any((value) => value.toLowerCase().contains(q));
  }

  List<String> _terms(List<QolipProduct> products) => [
        for (final product in products) ...[
          product.code,
          product.qolipCode,
          ...product.customerNames
        ],
      ];

  List<QolipCatalogItem> _sorted(Iterable<QolipCatalogItem> values) =>
      List.unmodifiable(values.toList()
        ..sort((a, b) {
          final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          return name == 0 ? a.id.compareTo(b.id) : name;
        }));
}

String qolipCatalogId(String code) =>
    'qp1.${base64Url.encode(utf8.encode(code.trim().toLowerCase())).replaceAll('=', '')}';
