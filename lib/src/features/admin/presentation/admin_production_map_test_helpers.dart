part of 'admin_production_map_test_screen.dart';

const _maxLaminatsiyaRubberSizeMm = 1050;
const _laminatsiyaOversizeMessage =
    'Laminatsiya apparatga buyurtma kattalik qiladi, iltimos uni bo‘laklab oling';

class ProductionMapTestArgs {
  const ProductionMapTestArgs({
    this.orderContext,
    this.savedMap,
    this.readOnly = false,
  });

  final ProductionMapOrderContext? orderContext;
  final ProductionMapDefinition? savedMap;
  final bool readOnly;
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
    this.templateDraft,
  });

  final String templateId;
  final String orderCode;
  final String orderName;
  final String productName;
  final String itemCode;
  final double? rollCount;
  final double? widthMm;
  final CalculateOrderTemplate? templateDraft;
}

bool _isRezkaProductionNode(ProductionMapNode node) {
  return node.kind == 'apparatus' &&
      node.title.trim().toLowerCase().contains('rezka');
}

String _formatRezkaNumber(double value) => formatRawQuantity(value);

Future<String?> showProductionMapOrderNumberSheet(
  BuildContext context, {
  String initialValue = '',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (context) =>
        _ProductionMapOrderNumberDialog(initialValue: initialValue),
  );
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
  AdminWarehouse apparatus,
  ProductionMapOrderContext? orderContext,
) {
  if (productionMapIsLaminatsiyaApparatus(apparatus.warehouse) &&
      !_productionMapLaminatsiyaMatchesOrder(orderContext)) {
    return false;
  }
  final apparatusColorCount = productionMapPechatColorCount(
    apparatus.warehouse,
  );
  if (apparatusColorCount == null) {
    return true;
  }
  final context = orderContext;
  if (context == null) {
    return true;
  }
  if (_productionMapOrderIsFlexoProduct(context)) {
    return false;
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
) {
  if (_productionMapLaminatsiyaMatchesOrder(orderContext)) {
    return true;
  }
  final widthMm = orderContext?.widthMm;
  final frameCount = _productionMapOrderFrameCount(orderContext);
  if (widthMm == null || widthMm <= 0 || frameCount <= 0) {
    return false;
  }
  for (final node in nodes) {
    if (!_isRezkaProductionNode(node) || node.rezkaFrameGroups.isEmpty) {
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
