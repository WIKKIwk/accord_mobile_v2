/// Returns the signed percentage when a positive measurement differs from the
/// reference by more than 10%. Exactly +/-10% remains within the allowed band.
///
/// Missing or invalid measurements belong to the form's existing validators.
double? rezkaOutputDeviationPercent({
  required double? reference,
  required double? actual,
}) {
  if (reference == null ||
      actual == null ||
      !reference.isFinite ||
      !actual.isFinite ||
      reference <= 0 ||
      actual <= 0) {
    return null;
  }

  final relativeDifference = actual / reference - 1;
  // Division at an exact boundary can introduce a few binary rounding bits.
  if (relativeDifference.abs() <= 0.1 + 1e-12) return null;

  final percentage = relativeDifference * 100;
  // Keep the warning display finite even for extreme but finite form inputs.
  return percentage.isFinite ? percentage : double.maxFinite;
}
