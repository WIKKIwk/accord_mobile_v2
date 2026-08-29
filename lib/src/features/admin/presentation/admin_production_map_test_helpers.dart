part of 'admin_production_map_test_screen.dart';

const _maxLaminatsiyaRubberSizeMm = 1050;
const _laminatsiyaOversizeMessage =
    'Laminatsiya apparatga buyurtma kattalik qiladi, iltimos uni bo‘laklab oling';

class ProductionMapTestArgs {
  const ProductionMapTestArgs({
    this.orderContext,
    this.savedMap,
    this.readOnly = false,
    this.templateOnly = false,
    this.lockedNodeIds = const {},
  });

  final ProductionMapOrderContext? orderContext;
  final ProductionMapDefinition? savedMap;
  final bool readOnly;
  final bool templateOnly;
  final Set<String> lockedNodeIds;
}

class ProductionMapOrderContext {
  const ProductionMapOrderContext({
    this.templateId = '',
    this.orderCode = '',
    required this.orderName,
    required this.productName,
    required this.itemCode,
    this.rollCount,
    this.widthMm,
    this.apparatus = '',
    this.apparatusId = '',
    this.templateDraft,
  });

  final String templateId;
  final String orderCode;
  final String orderName;
  final String productName;
  final String itemCode;
  final double? rollCount;
  final double? widthMm;
  final String apparatus;
  final String apparatusId;
  final CalculateOrderTemplate? templateDraft;
}

bool _productionMapOrderContextHasApparatus(
  ProductionMapOrderContext context,
) {
  final name = context.apparatus.trim();
  final id = context.apparatusId.trim();
  if (name.isEmpty && id.isEmpty) return false;
  if (name.isEmpty || !isCanonicalApparatusId(id)) {
    throw ArgumentError.value(
      id,
      'context.apparatusId',
      'Canonical apparatus ID and display name are required together',
    );
  }
  return true;
}

List<ProductionMapNode> productionMapOrderFlowNodes(
  ProductionMapOrderContext context,
) {
  final orderName =
      context.orderName.trim().isEmpty ? 'Zakaz' : context.orderName.trim();
  final productName = context.productName.trim().isEmpty
      ? 'Mahsulot'
      : context.productName.trim();
  final apparatus = context.apparatus.trim();
  final hasApparatus = _productionMapOrderContextHasApparatus(context);
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
    if (hasApparatus)
      ProductionMapNode(
        id: 'apparatus',
        kind: 'apparatus',
        title: apparatus,
        apparatusId: context.apparatusId.trim(),
        x: 420,
        y: 296,
      ),
    ProductionMapNode(
      id: 'end',
      kind: 'end',
      title: productName,
      itemCode: context.itemCode,
      x: 420,
      y: hasApparatus ? 428 : 296,
    ),
  ];
}

List<ProductionMapEdge> productionMapOrderFlowEdges(
  ProductionMapOrderContext context,
) {
  final hasApparatus = _productionMapOrderContextHasApparatus(context);
  return [
    const ProductionMapEdge(from: 'start', to: 'order'),
    if (hasApparatus) ...[
      const ProductionMapEdge(from: 'order', to: 'apparatus'),
      const ProductionMapEdge(from: 'apparatus', to: 'end'),
    ] else
      const ProductionMapEdge(from: 'order', to: 'end'),
  ];
}

bool _isRezkaProductionNode(
  ProductionMapNode node,
  Iterable<AdminApparatus> apparatusCatalog,
) {
  if (node.kind != 'apparatus') return false;
  final apparatusId = node.alternativeAssignedApparatusId.trim().isEmpty
      ? node.apparatusId.trim()
      : node.alternativeAssignedApparatusId.trim();
  return apparatusCatalog.any(
    (apparatus) =>
        apparatus.id.trim() == apparatusId &&
        apparatus.operation.trim().toLowerCase() == 'cut',
  );
}

String _formatRezkaNumber(double value) => formatRawQuantity(value);

Future<bool> showProductionMapOrderConfirmationSheet(
  BuildContext context,
) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (context) => const _ProductionMapOrderConfirmationDialog(),
  );
  return confirmed ?? false;
}

String productionMapBranchDisplayLabel(String branch) {
  return switch (branch.trim().toLowerCase()) {
    'true' => 'Shunda',
    'false' => 'Aks holda',
    _ => branch,
  };
}

bool productionMapCanCreateEdge(ProductionMapNode from, ProductionMapNode to) {
  return true;
}

bool productionMapApparatusMatchesOrder(
  AdminApparatus apparatus,
  ProductionMapOrderContext? orderContext,
) {
  if (apparatus.operation == 'laminate' &&
      !_productionMapLaminatsiyaMatchesOrder(orderContext)) {
    return false;
  }
  if (apparatus.operation != 'print') {
    return true;
  }
  final context = orderContext;
  if (context != null && _productionMapOrderIsFlexoProduct(context)) {
    return apparatus.technology == 'flexographic';
  }
  final apparatusColorCount = apparatus.colorStations;
  if (apparatusColorCount == null) {
    return true;
  }
  if (context == null) {
    return true;
  }
  final recommended = productionMapRecommendedPechatColorCount(
    rollCount: context.rollCount,
    widthMm: context.widthMm,
  );
  if (recommended == null) {
    return context.rollCount == null && context.widthMm == null;
  }
  return productionMapPechatCanHandleOrder(
    apparatusColorCount: apparatusColorCount,
    rollCount: context.rollCount,
    widthMm: context.widthMm,
  );
}

bool _productionMapOrderIsFlexoProduct(ProductionMapOrderContext context) {
  final haystack = [
    context.orderName,
    context.productName,
    context.itemCode,
  ].join(' ').toLowerCase();
  return const [
    'fleksa',
    'fleska',
    'flex',
    'flexe',
    'flexo',
  ].any(haystack.contains);
}

bool _productionMapLaminatsiyaMatchesOrder(
  ProductionMapOrderContext? orderContext,
) {
  final widthMm = orderContext?.widthMm;
  return _productionMapWidthFitsLaminatsiya(widthMm);
}

bool _productionMapLaminatsiyaMatchesCurrentMap(
  ProductionMapOrderContext? orderContext,
  Iterable<ProductionMapNode> nodes,
  Iterable<AdminApparatus> apparatusCatalog,
) {
  if (_productionMapLaminatsiyaMatchesOrder(orderContext)) {
    return true;
  }
  final widthMm = orderContext?.widthMm;
  if (widthMm == null || widthMm <= 0) {
    return false;
  }
  for (final node in nodes) {
    if (!_isRezkaProductionNode(node, apparatusCatalog)) {
      continue;
    }
    final frameCount = _productionMapRezkaFrameCount(node);
    if (frameCount <= 0) {
      continue;
    }
    if (node.rezkaFrameGroups.isEmpty) {
      if (_productionMapWidthFitsLaminatsiya(widthMm / frameCount)) {
        return true;
      }
      continue;
    }
    final totalFrames = node.rezkaFrameGroups.fold<int>(
      0,
      (sum, group) => sum + group,
    );
    if (totalFrames != frameCount) {
      continue;
    }
    final allGroupsFit = node.rezkaFrameGroups.every((group) {
      final groupWidth = widthMm * group / frameCount;
      return _productionMapWidthFitsLaminatsiya(groupWidth);
    });
    if (allGroupsFit) {
      return true;
    }
  }
  return false;
}

int _productionMapRezkaFrameCount(ProductionMapNode node) {
  final frameCount = node.rezkaKadrCount ?? 0;
  return frameCount > 0 ? frameCount : 0;
}

int _productionMapOrderFrameCount(ProductionMapOrderContext? orderContext) {
  final frameCount = orderContext?.templateDraft?.frameCount ?? 0;
  if (frameCount <= 0) {
    return 0;
  }
  return frameCount.round();
}

bool _productionMapWidthFitsLaminatsiya(double? widthMm) {
  if (widthMm == null || widthMm <= 0) {
    return true;
  }
  return productionMapRubberSizeFromWidth(widthMm) <=
      _maxLaminatsiyaRubberSizeMm;
}
