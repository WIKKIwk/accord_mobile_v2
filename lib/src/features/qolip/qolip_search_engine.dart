import 'dart:async';

import '../../core/search/search_normalizer.dart';

/// Immutable search fields, prepared once per source object.
class QolipSearchDocument {
  QolipSearchDocument(Iterable<String> values) {
    final fields =
        values.map(_prepareField).where((field) => field.$1.isNotEmpty);
    final compactFields = <String>{};
    for (final field in fields) {
      normalized.add(field.$1);
      if (field.$2.isNotEmpty) compactFields.add(field.$2);
    }
    // Every word is already a substring of its compact field. Keeping both
    // caused the same fuzzy comparison to run twice without adding matches.
    compact = compactFields.toList(growable: false);
  }

  final List<String> normalized = [];
  late final List<String> compact;
}

// Repeated names/warehouses/customer fields are shared between mold records.
// A bounded LRU also keeps cold indexing cheap without retaining old catalogs.
final _fields = <String, (String, String)>{};
(String, String) _prepareField(String value) {
  final cached = _fields.remove(value);
  if (cached != null) {
    _fields[value] = cached;
    return cached;
  }
  final normalized = normalizeForSearch(value);
  final prepared = (normalized, _compact(normalized));
  if (_fields.length >= 2048) _fields.remove(_fields.keys.first);
  _fields[value] = prepared;
  return prepared;
}

class QolipSearchQuery {
  QolipSearchQuery(String query)
      : _variants = _queryVariants(query)
            .map((variant) => _SearchVariant(variant.value, variant.allowFuzzy))
            .toList(growable: false);

  final List<_SearchVariant> _variants;
  // Many molds share product names, customers, blocks and warehouses.
  // Bound memory even when searching a large catalog or pasting long text.
  final Map<(String, String), bool> _fuzzyCache = {};

  bool get isEmpty => _variants.isEmpty;

  bool matches(QolipSearchDocument document) {
    if (isEmpty) return true;
    for (final variant in _variants) {
      if (document.normalized.any((v) => v.contains(variant.value)) ||
          (variant.compact.isNotEmpty &&
              document.compact.any((v) => v.contains(variant.compact)))) {
        return true;
      }
    }
    for (final variant in _variants) {
      if (variant.compact.isEmpty) continue;
      if (variant.allowFuzzy &&
          _canFuzzyMatch(variant.compact) &&
          document.compact.any((v) => _fuzzy(v, variant.compact))) {
        return true;
      }
      if (variant.tokens.length >= 2 &&
          variant.tokens.every((token) => document.compact.any((v) =>
              v.contains(token) ||
              (variant.allowFuzzy &&
                  _canFuzzyMatch(token) &&
                  _fuzzy(v, token))))) {
        return true;
      }
    }
    return false;
  }

  bool _fuzzy(String value, String query) {
    final key = (value, query);
    final cached = _fuzzyCache[key];
    if (cached != null) return cached;
    final result = _fuzzyContains(value, query);
    if (_fuzzyCache.length < 4096) _fuzzyCache[key] = result;
    return result;
  }
}

class _SearchVariant {
  _SearchVariant(this.value, this.allowFuzzy)
      : compact = _compact(value),
        tokens =
            _tokens(value).where((t) => t.length >= 2).toList(growable: false);
  final String value;
  final bool allowFuzzy;
  final String compact;
  final List<String> tokens;
}

/// Yield between small CPU slices on both native and web. A newer query can
/// cancel this scan before it consumes the rest of a large catalog. Merely
/// wrapping a synchronous full scan in a Future would still freeze typing.
Future<List<T>?> filterQolipSearch<T>(
  Iterable<T> items,
  String query,
  QolipSearchDocument Function(T) documentFor, {
  bool Function()? isCurrent,
}) async {
  final prepared = QolipSearchQuery(query);
  final result = <T>[];
  final slice = Stopwatch()..start();
  for (final item in items) {
    if (isCurrent != null && !isCurrent()) return null;
    if (prepared.isEmpty || prepared.matches(documentFor(item))) {
      result.add(item);
    }
    if (slice.elapsedMicroseconds >= 2000) {
      await Future<void>.delayed(Duration.zero);
      slice.reset();
    }
  }
  return isCurrent == null || isCurrent() ? result : null;
}

List<({String value, bool allowFuzzy})> _queryVariants(String query) {
  final variants = <({String value, bool allowFuzzy})>[];

  void add(String value, {required bool allowFuzzy}) {
    final normalized = normalizeForSearch(value);
    if (normalized.isNotEmpty &&
        !variants.any((variant) => variant.value == normalized)) {
      variants.add((value: normalized, allowFuzzy: allowFuzzy));
    }
  }

  add(query, allowFuzzy: true);

  final scriptCounts = _scriptLetterCounts(query);
  final hasDigits = query.runes.any((rune) => rune >= 0x30 && rune <= 0x39);
  if (!hasDigits && scriptCounts.$1 >= 4 && scriptCounts.$2 == 0) {
    add(_latinKeyboardToCyrillic(query), allowFuzzy: false);
  } else if (!hasDigits && scriptCounts.$2 >= 4 && scriptCounts.$1 == 0) {
    add(_cyrillicKeyboardToLatin(query), allowFuzzy: false);
  }

  return variants;
}

(int, int) _scriptLetterCounts(String input) {
  var latin = 0;
  var cyrillic = 0;
  for (final rune in input.toLowerCase().runes) {
    if (rune >= 0x61 && rune <= 0x7a) {
      latin += 1;
    } else if ((rune >= 0x0400 && rune <= 0x04ff) ||
        rune == 0x04e8 ||
        rune == 0x04e9) {
      cyrillic += 1;
    }
  }
  return (latin, cyrillic);
}

bool _canFuzzyMatch(String query) =>
    query.length >= 3 &&
    !query.runes.any((rune) => rune >= 0x30 && rune <= 0x39);

int _maxDistance(String query) {
  if (query.length <= 6) {
    return 1;
  }
  if (query.length <= 10) {
    return 2;
  }
  return 3;
}

// Semi-global optimal-string-alignment distance: a free prefix lets a match
// begin at any position, and checking each row lets it end anywhere. This is
// equivalent to checking all substrings of length query.length +/- tolerance,
// including adjacent transpositions, but takes O(value.length * query.length)
// work and reuses three rows instead of allocating a matrix for every window.
bool _fuzzyContains(String value, String query) {
  final tolerance = _maxDistance(query);
  if (value.length < query.length - tolerance) return false;
  final width = query.length + 1;
  var previousPrevious = List<int>.filled(width, 0);
  var previous = List<int>.generate(width, (i) => i);
  var current = List<int>.filled(width, 0);
  for (var i = 1; i <= value.length; i++) {
    current[0] = 0;
    final character = value.codeUnitAt(i - 1);
    for (var j = 1; j < width; j++) {
      final cost = character == query.codeUnitAt(j - 1) ? 0 : 1;
      var distance = _minimum3(
          previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost);
      if (i > 1 &&
          j > 1 &&
          character == query.codeUnitAt(j - 2) &&
          value.codeUnitAt(i - 2) == query.codeUnitAt(j - 1)) {
        final transposed = previousPrevious[j - 2] + 1;
        if (transposed < distance) distance = transposed;
      }
      current[j] = distance;
    }
    if (current.last <= tolerance) return true;
    final spare = previousPrevious;
    previousPrevious = previous;
    previous = current;
    current = spare;
  }
  return false;
}

int _minimum3(int a, int b, int c) {
  final minimum = a < b ? a : b;
  return minimum < c ? minimum : c;
}

final _separators = RegExp(r'[^a-z0-9]+');
List<String> _tokens(String value) => value
    .split(_separators)
    .where((token) => token.isNotEmpty)
    .toList(growable: false);
String _compact(String value) => value.replaceAll(_separators, '');

const _latinKeyboard = 'qwertyuiopasdfghjklzxcvbnm';
const _cyrillicKeyboard = 'йцукенгшщзфывапролдячсмить';

String _latinKeyboardToCyrillic(String input) =>
    _mapKeyboard(input, from: _latinKeyboard, to: _cyrillicKeyboard);

String _cyrillicKeyboardToLatin(String input) =>
    _mapKeyboard(input, from: _cyrillicKeyboard, to: _latinKeyboard);

String _mapKeyboard(
  String input, {
  required String from,
  required String to,
}) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final character = String.fromCharCode(rune);
    final index = from.indexOf(character);
    buffer.write(index < 0 ? character : to[index]);
  }
  return buffer.toString();
}
