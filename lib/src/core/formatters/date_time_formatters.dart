String formatLocalDateTime(DateTime value) {
  final local = value.toLocal();
  return '${_two(local.day)}.${_two(local.month)}.${local.year} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

String formatUnixSecondsLocalDateTime(int unixSeconds) {
  if (unixSeconds <= 0) {
    return '';
  }
  return formatLocalDateTime(
    DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000, isUtc: true),
  );
}

String formatParsedLocalDateTimeOrRaw(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return '';
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }
  return formatLocalDateTime(parsed);
}

String _two(int value) => value.toString().padLeft(2, '0');
