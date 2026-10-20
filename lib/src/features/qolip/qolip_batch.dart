const int qolipBatchMaxCount = 9;

class QolipBatchCodeDraft {
  const QolipBatchCodeDraft({
    required this.input,
    required this.prefix,
    required this.count,
    required this.codes,
  });

  final String input;
  final String prefix;
  final int count;
  final List<String> codes;
}

QolipBatchCodeDraft? parseQolipBatchCode(String raw) {
  final input = raw.trim();
  if (input.isEmpty || input.endsWith('0')) {
    return null;
  }

  final match = RegExp(r'^(.*)-([0-9]+)$').firstMatch(input);
  if (match == null) {
    return QolipBatchCodeDraft(
      input: input,
      prefix: '',
      count: 1,
      codes: <String>[input],
    );
  }

  final prefix = match.group(1)!.trim();
  final suffix = match.group(2)!;
  final count = int.parse(suffix[suffix.length - 1]);
  if (prefix.isEmpty || count <= 0 || count > qolipBatchMaxCount) {
    return null;
  }

  // Only the last digit is the count; retain the rest of the mold code.
  final codePrefix = '$prefix-${suffix.substring(0, suffix.length - 1)}';
  return QolipBatchCodeDraft(
    input: input,
    prefix: codePrefix,
    count: count,
    codes: [
      for (var index = 1; index <= count; index++) '$codePrefix$index',
    ],
  );
}
