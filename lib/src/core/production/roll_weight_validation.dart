// Match the backend's numeric(18,6) comparison and unknown-weight semantics.
int? _weightUnits(double? kg) {
  if (kg == null || !kg.isFinite || kg < 0 || kg >= 1e12) return null;
  return (kg * 1000000).round();
}

bool bobinaExceedsGross(double? grossKg, double? bobinaKg) {
  final gross = _weightUnits(grossKg);
  final bobina = _weightUnits(bobinaKg);
  return gross != null && gross > 0 && bobina != null && bobina > gross;
}

/// A tare-only edit preserves measured gross; a real kg edit replaces it.
double? correctedRollGrossKg({
  required double? previousFinishedGoodsKg,
  required double? finishedGoodsKg,
  required Object? previousGrossQty,
}) {
  if (_weightUnits(previousFinishedGoodsKg) != _weightUnits(finishedGoodsKg)) {
    return finishedGoodsKg;
  }
  if (previousGrossQty == null) return finishedGoodsKg;
  return previousGrossQty is num ? previousGrossQty.toDouble() : null;
}
