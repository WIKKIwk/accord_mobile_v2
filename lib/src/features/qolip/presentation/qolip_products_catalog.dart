part of 'qolip_products_screen.dart';

extension _QolipProductsCatalog on _QolipProductsScreenState {
  void _rebuildContainers() {
    _allContainers = [
      for (final item in _catalogItems)
        _details[item.id] ??
            QolipProductContainer(
                catalogId: item.id,
                code: '',
                name: item.name,
                itemGroup: '',
                imageOrderId: item.orderImageOrderId,
                children: const [])
    ];
    _cachedContainers = _allContainers;
    _cachedProducts = [
      for (final container in _allContainers) ...container.children
    ];
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    _query = _search.text.trim();
    final page = await MobileApi.instance.qolipCatalogPage(query: _query);
    if (!mounted || generation != _loadGeneration) return;
    _update(() {
      _catalogItems
        ..clear()
        ..addAll(page.items);
      _nextCursor = page.nextCursor;
      _rebuildContainers();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  Future<void> _reload({String? preserveExpandedContainerKey}) async {
    _searchDebounce?.cancel();
    ++_selectionGeneration;
    _details.clear();
    _detailRequests.clear();
    _detailErrors.clear();
    _selectionMode = null;
    _selectedContainerKeys.clear();
    _selectedQolipCodes.clear();
    _pageError = null;
    _loadingMore = false;
    _expandedContainerKey = preserveExpandedContainerKey;
    // Editing a product keeps the loaded name pages and the scroll position.
    if (_query.isEmpty &&
        preserveExpandedContainerKey != null &&
        _catalogItems.any((item) => item.id == preserveExpandedContainerKey)) {
      ++_loadGeneration;
      _update(_rebuildContainers);
      final container = _allContainers
          .firstWhere((item) => item.key == preserveExpandedContainerKey);
      await _ensureDetails(container);
      return;
    }
    _catalogItems.clear();
    _nextCursor = null;
    final next = _load();
    _update(() {
      _cachedProducts = null;
      _allContainers = const [];
      _cachedContainers = const [];
      _future = next;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    try {
      await next;
    } catch (_) {/* The first-page FutureBuilder owns retry. */}
  }

  void _handleScroll() {
    if (!mounted || !_scroll.hasClients || _query != _search.text.trim()) {
      return;
    }
    if (_scroll.position.extentAfter < 500 &&
        _nextCursor != null &&
        !_loadingMore &&
        _pageError == null) {
      unawaited(_loadMore());
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore || _query != _search.text.trim()) return;
    final generation = _loadGeneration;
    _update(() {
      _loadingMore = true;
      _pageError = null;
    });
    try {
      final page = await MobileApi.instance
          .qolipCatalogPage(query: _query, cursor: cursor);
      if (!mounted || generation != _loadGeneration) return;
      final known = _catalogItems.map((item) => item.id).toSet();
      _update(() {
        _catalogItems.addAll(page.items.where((item) => known.add(item.id)));
        _nextCursor = page.nextCursor;
        _rebuildContainers();
      });
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        _update(() => _pageError = error);
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        _update(() => _loadingMore = false);
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
      }
    }
  }

  Future<void> _toggleContainerExpanded(QolipProductContainer container) async {
    final closing = _expandedContainerKey == container.key;
    _update(() => _expandedContainerKey = closing ? null : container.key);
    if (!closing) await _ensureDetails(container);
  }

  Future<QolipProductContainer?> _ensureDetails(
      QolipProductContainer container) {
    final id = container.key;
    final cached = _details[id];
    if (cached != null) return Future.value(cached);
    final pending = _detailRequests[id];
    if (pending != null) return pending;
    final generation = _loadGeneration;
    _detailErrors.remove(id);
    late final Future<QolipProductContainer?> request;
    request = (() async {
      try {
        final products = await MobileApi.instance.qolipCatalogDetails(id);
        if (!mounted || generation != _loadGeneration) return null;
        final groups = groupQolipProductsByContainer(products);
        if (groups.length != 1) {
          throw const FormatException('Invalid Qolip product details');
        }
        final group = groups.single;
        final resolved = QolipProductContainer(
            catalogId: id,
            code: group.code,
            name: container.name,
            itemGroup: group.itemGroup,
            imageOrderId: container.orderImageOrderId,
            children: group.children);
        _update(() {
          _details[id] = resolved;
          _rebuildContainers();
        });
        return resolved;
      } catch (error) {
        if (mounted && generation == _loadGeneration) {
          _update(() {
            _detailErrors[id] = error;
            _expandedContainerKey = id;
          });
        }
        return null;
      } finally {
        if (mounted &&
            generation == _loadGeneration &&
            identical(_detailRequests[id], request)) {
          _update(() => _detailRequests.remove(id));
        }
      }
    })();
    _update(() => _detailRequests[id] = request);
    return request;
  }

  String? _catalogKeyForCode(String code) => _allContainers
      .where((item) => item.code.toLowerCase() == code.toLowerCase())
      .firstOrNull
      ?.key;
}
