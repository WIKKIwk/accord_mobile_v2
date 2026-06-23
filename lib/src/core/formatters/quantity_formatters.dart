String formatQuantity(double value, {bool trimTrailingZeros = false}) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  final fixed = value.toStringAsFixed(2);
  if (!trimTrailingZeros) {
    return fixed;
  }
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
