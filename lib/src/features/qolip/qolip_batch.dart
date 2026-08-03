const int qolipBatchMaxCount = 100;

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
  if (input.isEmpty) {
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
  final count = int.tryParse(suffix);
  if (prefix.isEmpty ||
      count == null ||
      count <= 0 ||
      count > qolipBatchMaxCount) {
    return null;
  }

  return QolipBatchCodeDraft(
    input: input,
    prefix: '$prefix-',
    count: count,
    codes: [
      for (var index = 1; index <= count; index++)
        '$prefix-${index.toString().padLeft(suffix.length, '0')}',
    ],
  );
}
