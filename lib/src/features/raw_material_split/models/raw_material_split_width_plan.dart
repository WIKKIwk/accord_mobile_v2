import 'raw_material_split_models.dart';

final rawSplitMinimumWidth = BigInt.from(355000000);

/// Exact millimetres for one side-by-side cutting plan. Historical results are
/// deliberately not validated here: older rolls may have narrower widths.
class RawSplitWidthPlan {
  RawSplitWidthPlan(String sourceWidth, List<String> inputs)
      : source = rawSplitQuantity(sourceWidth),
        widths = [],
        errors = [] {
    for (final input in inputs) {
      BigInt? width;
      String? error;
      if (input.trim().isNotEmpty) {
        try {
          width = rawSplitQuantity(input);
          if (width < rawSplitMinimumWidth) {
            error = 'Eni kamida 355 mm bo‘lsin';
          }
        } on FormatException {
          error = 'Enni to‘g‘ri kiriting';
        }
      }
      widths.add(width);
      errors.add(error);
    }
    remaining =
        source - widths.fold(BigInt.zero, (sum, w) => sum + (w ?? BigInt.zero));
    if (remaining.isNegative) {
      for (var i = 0; i < widths.length; i++) {
        if (widths[i] != null) {
          errors[i] ??= 'Enlar yig‘indisi asl endan oshdi';
        }
      }
    }
  }

  final BigInt source;
  final List<BigInt?> widths;
  final List<String?> errors;
  late final BigInt remaining;
  bool get valid => errors.every((e) => e == null);
  bool get complete => valid && widths.isNotEmpty && !widths.contains(null);
  bool get canAdd =>
      complete && remaining >= rawSplitMinimumWidth && widths.length < 100;
  int get maxRolls {
    final count = source ~/ rawSplitMinimumWidth;
    return count > BigInt.from(100) ? 100 : count.toInt();
  }

  void validateForSave() {
    for (final error in errors) {
      if (error != null) throw FormatException(error);
    }
    if (!complete) {
      throw const FormatException('Har bir rulon enini kiriting');
    }
    if (remaining >= rawSplitMinimumWidth) {
      throw const FormatException('Qolgan yaroqli en uchun ham rulon kiriting');
    }
  }
}
