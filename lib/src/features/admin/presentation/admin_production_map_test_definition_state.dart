part of 'admin_production_map_test_screen.dart';

extension _AdminProductionMapTestDefinitionState
    on _AdminProductionMapTestScreenState {
  void _syncNextNodeIndexFromExistingNodes() {
    var maxIndex = 0;
    for (final node in nodes) {
      final match = RegExp(r'_(\d+)$').firstMatch(node.id.trim());
      if (match == null) {
        continue;
      }
      final value = int.tryParse(match.group(1) ?? '');
      if (value != null && value > maxIndex) {
        maxIndex = value;
      }
    }
    if (maxIndex >= _nextNodeIndex) {
      _nextNodeIndex = maxIndex + 1;
    }
  }

  Future<void> _loadApparatusGroups() async {
    try {
      final groups = await MobileApi.instance.adminApparatusGroups();
      if (mounted) {
        _updateScreenState(() => _apparatusGroups = groups);
      }
    } catch (_) {
      return;
    }
  }

  List<ProductionMapNode> _defaultTestNodes() {
    return [
      const ProductionMapNode(
        id: 'start',
        kind: 'start',
        title: 'Start',
        x: 420,
        y: 32,
      ),
      const ProductionMapNode(
        id: 'cpp_calc',
        kind: 'formula',
        title: 'CPP hisob',
        x: 420,
        y: 164,
        formula: ProductionFormula(
          target: 'cpp_kg',
          expression: 'order_qty * 1.08',
        ),
      ),
      const ProductionMapNode(
        id: 'qty_check',
        kind: 'condition',
        title: 'Katta partiyami?',
        x: 420,
        y: 296,
        formula: ProductionFormula(target: '', expression: 'order_qty >= 100'),
      ),
      const ProductionMapNode(
        id: 'end',
        kind: 'end',
        title: 'End',
        x: 420,
        y: 520,
      ),
    ];
  }

  List<ProductionMapEdge> _defaultTestEdges() {
    return [
      const ProductionMapEdge(from: 'start', to: 'cpp_calc'),
      const ProductionMapEdge(from: 'cpp_calc', to: 'qty_check'),
    ];
  }

  List<ProductionMapNode> _orderFlowNodes(ProductionMapOrderContext context) {
    final orderName =
        context.orderName.trim().isEmpty ? 'Zakaz' : context.orderName.trim();
    final productName = context.productName.trim().isEmpty
        ? 'Mahsulot'
        : context.productName.trim();
    return [
      const ProductionMapNode(
        id: 'start',
        kind: 'start',
        title: 'Start',
        x: 420,
        y: 32,
      ),
      ProductionMapNode(
        id: 'order',
        kind: 'task',
        title: orderName,
        roleCode: 'zakaz',
        x: 420,
        y: 164,
      ),
      ProductionMapNode(
        id: 'end',
        kind: 'end',
        title: productName,
        itemCode: context.itemCode,
        x: 420,
        y: 296,
      ),
    ];
  }

  List<ProductionMapEdge> _orderFlowEdges() {
    return [
      const ProductionMapEdge(from: 'start', to: 'order'),
      const ProductionMapEdge(from: 'order', to: 'end'),
    ];
  }

  Future<void> _saveMap() async {
    if (widget.readOnly) {
      return;
    }
    if (_savingMap) {
      return;
    }
    final orderNumber = _orderMode ? await _resolveOrderNumberForSave() : null;
    if (_orderMode && orderNumber == null) {
      return;
    }
    _updateScreenState(() => _savingMap = true);
    try {
      final definition = _currentMapDefinition(orderNumber: orderNumber);
      final draft = _templateDraft;
      if (draft != null) {
        final templateDefinition = definition.withoutAlternativeAssignments();
        // Single server-side operation: map + zakaz saved together.
        final result = await MobileApi.instance.adminSaveProductionMapWithOrder(
          map: templateDefinition,
          template: draft,
        );
        if (!mounted) {
          return;
        }
        _lastSavedTemplate = result.template;
        _templateDraft = result.template ?? draft;
        final savedTemplate = result.template;
        if (savedTemplate != null) {
          CalculateOrderTemplateStore.instance.remember(savedTemplate);
        }
        if (orderNumber != null) {
          _orderNumber = orderNumber;
        }
        showAdminTopNotice(context, 'Production map va zakaz saqlandi');
      } else {
        await MobileApi.instance.adminSaveProductionMap(definition);
        if (!mounted) {
          return;
        }
        if (orderNumber != null) {
          _orderNumber = orderNumber;
        }
        showAdminTopNotice(context, 'Production map saqlandi');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        error is MobileApiException
            ? error.message
            : 'Production map saqlanmadi',
      );
    } finally {
      if (mounted) {
        _updateScreenState(() => _savingMap = false);
      }
    }
  }

  bool get _orderNumberLocked =>
      RegExp(r'^\d{4}$').hasMatch(_orderNumber.trim());

  Future<String?> _resolveOrderNumberForSave() async {
    if (_orderNumberLocked) {
      return _orderNumber.trim();
    }
    return _requestOrderNumber();
  }

  Future<String?> _requestOrderNumber() {
    // Uniqueness is enforced server-side on save (duplicate_order_number);
    // the dialog only checks the 4-digit format.
    return showProductionMapOrderNumberSheet(
      context,
      initialValue: _orderNumber,
    );
  }

  ProductionMapDefinition _currentMapDefinition({String? orderNumber}) {
    final context = widget.orderContext;
    final savedMap = widget.savedMap;
    final normalizedOrderNumber = (orderNumber ?? _orderNumber).trim();
    final title = context == null
        ? (savedMap?.title.trim().isNotEmpty ?? false)
            ? savedMap!.title.trim()
            : 'Production map test'
        : (context.orderName.trim().isEmpty
            ? 'Zakaz'
            : context.orderName.trim());
    final productCode = context == null
        ? (savedMap?.productCode.trim().isNotEmpty ?? false)
            ? savedMap!.productCode.trim()
            : 'production-map-test'
        : _firstNonEmpty([
            context.itemCode,
            context.productName,
            context.orderName,
            context.templateId,
          ]);
    return ProductionMapDefinition(
      id: _orderMode
          ? ((savedMap?.id.trim().isNotEmpty ?? false)
              ? savedMap!.id.trim()
              : _zakazMapId(normalizedOrderNumber, context: context))
          : (context == null
              ? (savedMap?.id.trim().isNotEmpty ?? false)
                  ? savedMap!.id.trim()
                  : 'production-map-test'
              : _orderMapId(context, normalizedOrderNumber)),
      productCode: productCode,
      title: title,
      code: _orderMode && normalizedOrderNumber.isNotEmpty
          ? normalizedOrderNumber
          : _firstNonEmpty([context?.orderCode ?? '', savedMap?.code ?? '']),
      orderNumber: normalizedOrderNumber,
      // Re-saving an opened zakaz must keep its pechat constraints.
      rollCount: context?.rollCount ?? savedMap?.rollCount,
      widthMm: context?.widthMm ?? savedMap?.widthMm,
      nodes: List<ProductionMapNode>.unmodifiable(nodes),
      edges: List<ProductionMapEdge>.unmodifiable(edges),
    );
  }

  String _zakazMapId(String orderNumber, {ProductionMapOrderContext? context}) {
    if (RegExp(r'^\d{4}$').hasMatch(orderNumber)) {
      return 'zakaz-$orderNumber';
    }
    if (context != null) {
      return _orderMapId(context, orderNumber);
    }
    return 'production-map-test';
  }

  String _orderMapId(ProductionMapOrderContext context, String orderNumber) {
    if (RegExp(r'^\d{4}$').hasMatch(orderNumber)) {
      return 'zakaz-$orderNumber';
    }
    final source = _firstNonEmpty([
      context.templateId,
      context.orderName,
      context.productName,
      context.itemCode,
    ]);
    return 'zakaz-${_slug(source)}';
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return 'zakaz';
  }

  String _slug(String value) {
    final lower = value.trim().toLowerCase();
    final buffer = StringBuffer();
    var lastDash = false;
    for (final unit in lower.codeUnits) {
      final isLetter = unit >= 97 && unit <= 122;
      final isDigit = unit >= 48 && unit <= 57;
      if (isLetter || isDigit) {
        buffer.writeCharCode(unit);
        lastDash = false;
      } else if (!lastDash) {
        buffer.write('-');
        lastDash = true;
      }
    }
    final slug = buffer.toString().replaceAll(RegExp('^-+|-+\$'), '');
    return slug.isEmpty ? 'zakaz' : slug;
  }
}
