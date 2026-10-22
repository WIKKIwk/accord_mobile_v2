import 'dart:convert';

// FNV-1a 64 uses two 32-bit limbs so the VM and Dart web compute the same
// fingerprint without BigInt allocations or JavaScript integer truncation.
String sequenceFingerprint(List<String> values) {
  var high = 0xcbf29ce4;
  var low = 0x84222325;
  void byte(int value) {
    low = (low ^ value).toUnsigned(32);
    final product = low * 0x1b3;
    high =
        (high * 0x1b3 + (product ~/ 0x100000000) + (low & 0x00ffffff) * 0x100)
            .toUnsigned(32);
    low = product.toUnsigned(32);
  }

  for (final value in values) {
    for (final value in utf8.encode(value)) {
      byte(value);
    }
    byte(0xff);
  }
  return high.toRadixString(16).padLeft(8, '0') +
      low.toRadixString(16).padLeft(8, '0');
}

List<String> applySequenceEdit(List<String> before, Object? raw) {
  if (raw is! Map ||
      raw['base_len'] is! int ||
      raw['base_len'] != before.length ||
      raw['base_hash'] != sequenceFingerprint(before) ||
      raw['len'] is! int ||
      (raw['len'] as int) < 0 ||
      raw['hash'] is! String ||
      !RegExp(r'^[0-9a-f]{16}$').hasMatch(raw['hash'] as String) ||
      raw['ops'] is! List ||
      before.toSet().length != before.length) {
    throw const FormatException('invalid sequence edit baseline');
  }
  final result = <String>[];
  final seen = <String>{};
  final length = raw['len'] as int;
  void add(String id) {
    if (id.isEmpty || result.length >= length || !seen.add(id)) {
      throw const FormatException('invalid sequence edit identity');
    }
    result.add(id);
  }

  for (final rawOp in raw['ops'] as List) {
    if (rawOp is! List || rawOp.isEmpty || rawOp[0] is! int) {
      throw const FormatException('invalid sequence edit operation');
    }
    if (rawOp[0] == 0 &&
        rawOp.length == 3 &&
        rawOp[1] is int &&
        rawOp[2] is int) {
      final start = rawOp[1] as int;
      final count = rawOp[2] as int;
      if (start < 0 ||
          count <= 0 ||
          start > before.length ||
          count > before.length - start ||
          count > length - result.length) {
        throw const FormatException('sequence edit range out of bounds');
      }
      for (var i = start; i < start + count; i++) {
        add(before[i]);
      }
    } else if (rawOp[0] == 1 && rawOp.length == 2 && rawOp[1] is List) {
      final inserted = _strings(rawOp[1]);
      if (inserted.isEmpty || inserted.length > length - result.length) {
        throw const FormatException('invalid sequence edit insertion');
      }
      for (final id in inserted) {
        add(id);
      }
    } else {
      throw const FormatException('unknown sequence edit operation');
    }
  }
  if (result.length != length || raw['hash'] != sequenceFingerprint(result)) {
    throw const FormatException('sequence edit result mismatch');
  }
  return result;
}

List<String> _strings(Object? raw) {
  if (raw is! List || raw.any((value) => value is! String || value.isEmpty)) {
    throw const FormatException('sequence string list required');
  }
  return raw.cast<String>();
}
