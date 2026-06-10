int productionMapRubberSizeFromWidth(double widthMm) {
  return (widthMm / 50).ceil().clamp(1, 26).toInt() * 50;
}

int? productionMapPechatColorCount(String title) {
  final match = RegExp(
    r'\b([789])\s*(?:ta)?\s*rangli\s*(?:pechat|val)\b',
    caseSensitive: false,
  ).firstMatch(title.trim().toLowerCase());
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(1) ?? '');
}

bool productionMapPechatCanHandleOrder({
  required int apparatusColorCount,
  required double? rollCount,
  required double? widthMm,
}) {
  if (rollCount != null && rollCount > apparatusColorCount) {
    return false;
  }
  if (widthMm == null || widthMm <= 0) {
    return true;
  }
  final rubberSize = productionMapRubberSizeFromWidth(widthMm);
  return switch (apparatusColorCount) {
    7 => rubberSize <= 800,
    8 => rubberSize >= 150 && rubberSize <= 1000,
    9 => rubberSize >= 800 && rubberSize <= 1300,
    _ => false,
  };
}

bool productionMapPechatCanMoveOrder({
  required int apparatusColorCount,
  required double? rollCount,
  required double? widthMm,
}) {
  if (rollCount == null || rollCount <= 0 || widthMm == null || widthMm <= 0) {
    return apparatusColorCount != 9;
  }
  return productionMapPechatCanHandleOrder(
    apparatusColorCount: apparatusColorCount,
    rollCount: rollCount,
    widthMm: widthMm,
  );
}
