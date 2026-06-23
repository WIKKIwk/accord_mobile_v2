String formatQuantity(
  double value, {
  int decimalPlaces = 2,
  bool trimTrailingZeros = false,
}) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  final fixed = value.toStringAsFixed(decimalPlaces);
  if (!trimTrailingZeros) {
    return fixed;
  }
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String formatRawQuantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toString();
}

String formatQuantityWithUnit(
  double value,
  String unit, {
  int decimalPlaces = 2,
  bool trimTrailingZeros = false,
}) {
  final qty = formatQuantity(
    value,
    decimalPlaces: decimalPlaces,
    trimTrailingZeros: trimTrailingZeros,
  );
  return [qty, if (unit.trim().isNotEmpty) unit.trim()].join(' ');
}
