import '../../core/search/search_normalizer.dart';
import '../shared/models/app_models.dart';

bool qolipLocationSearchMatches(String query, QolipLocationEntry item) {
  return qolipSearchMatches(query, [
    item.itemName,
    item.itemCode,
    item.qolipCode,
    '${item.size}',
    item.block,
    item.warehouse,
    item.locationLabel,
  ]);
}

bool qolipProductSearchMatches(String query, QolipProduct product) {
  return qolipSearchMatches(query, [
    product.name,
    product.code,
    product.itemGroup,
    product.qolipCode,
    if (product.qolipSize > 0) '${product.qolipSize}',
    ...product.customerNames,
  ]);
}

bool qolipCheckoutSearchMatches(String query, QolipCheckoutEntry checkout) {
  return qolipSearchMatches(query, [
    checkout.issuedToName,
    checkout.itemName,
    checkout.itemCode,
    checkout.qolipCode,
    checkout.block,
    checkout.warehouse,
    checkout.locationLabel,
    '${checkout.size}',
  ]);
}

bool qolipBlockSearchMatches(String query, QolipBlock block) {
  return qolipSearchMatches(query, [block.name, block.warehouse]);
}

bool qolipWorkerSearchMatches(String query, QolipWorkerOption worker) {
  return qolipSearchMatches(query, [worker.name, worker.level]);
}

/// Qolipchi search is intentionally more forgiving than the shared catalog
/// search. It accepts mixed Latin/Cyrillic text, misplaced separators, swapped
/// adjacent letters, and a small number of insertions, deletions or typos.
bool qolipSearchMatches(String query, Iterable<String> values) {
  final variants = _queryVariants(query);
  if (variants.isEmpty) {
    return true;
  }

  final normalizedValues = values
      .map(normalizeForSearch)
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  if (normalizedValues.isEmpty) {
    return false;
  }

  final searchableParts = <String>{
    for (final value in normalizedValues) ...[
      _compact(value),
      ..._tokens(value),
    ],
  }..removeWhere((value) => value.isEmpty);

  for (final variant in variants) {
    if (_matchesVariant(
      variant.value,
      normalizedValues,
      searchableParts,
      allowFuzzy: variant.allowFuzzy,
    )) {
      return true;
    }
  }
  return false;
}

bool _matchesVariant(
  String query,
  List<String> normalizedValues,
  Set<String> searchableParts, {
  required bool allowFuzzy,
}) {
  if (normalizedValues.any((value) => value.contains(query))) {
    return true;
  }

  final compactQuery = _compact(query);
  if (compactQuery.isEmpty) {
    return false;
  }
  if (searchableParts.any((value) => value.contains(compactQuery))) {
    return true;
  }
  if (allowFuzzy &&
      _canFuzzyMatch(compactQuery) &&
      searchableParts.any(
        (value) => _fuzzyContains(value, compactQuery),
      )) {
    return true;
  }

  final queryTokens = _tokens(query)
      .where((token) => token.length >= 2)
      .toList(growable: false);
  if (queryTokens.length < 2) {
    return false;
  }

  // Match every word independently so word order and fields do not matter.
  return queryTokens.every(
    (token) => searchableParts.any(
      (value) =>
          value.contains(token) ||
          (allowFuzzy && _canFuzzyMatch(token) && _fuzzyContains(value, token)),
    ),
  );
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

bool _fuzzyContains(String value, String query) {
  if (value.isEmpty || query.isEmpty) {
    return false;
  }
  if (value.contains(query)) {
    return true;
  }

  final maxDistance = _maxDistance(query);
  final shortestWindow = (query.length - maxDistance).clamp(1, value.length);
  final longestWindow = (query.length + maxDistance).clamp(1, value.length);
  for (var windowLength = shortestWindow;
      windowLength <= longestWindow;
      windowLength++) {
    for (var start = 0; start <= value.length - windowLength; start++) {
      final window = value.substring(start, start + windowLength);
      if (_boundedDamerauLevenshtein(
            window,
            query,
            maxDistance: maxDistance,
          ) !=
          null) {
        return true;
      }
    }
  }
  return false;
}

int? _boundedDamerauLevenshtein(
  String left,
  String right, {
  required int maxDistance,
}) {
  if ((left.length - right.length).abs() > maxDistance) {
    return null;
  }

  var previousPrevious = <int>[];
  var previous = List<int>.generate(right.length + 1, (index) => index);
  for (var leftIndex = 1; leftIndex <= left.length; leftIndex++) {
    final current = List<int>.filled(right.length + 1, 0);
    current[0] = leftIndex;
    for (var rightIndex = 1; rightIndex <= right.length; rightIndex++) {
      final substitutionCost =
          left[leftIndex - 1] == right[rightIndex - 1] ? 0 : 1;
      var distance = _minimum3(
        previous[rightIndex] + 1,
        current[rightIndex - 1] + 1,
        previous[rightIndex - 1] + substitutionCost,
      );
      if (leftIndex > 1 &&
          rightIndex > 1 &&
          left[leftIndex - 1] == right[rightIndex - 2] &&
          left[leftIndex - 2] == right[rightIndex - 1]) {
        final transposed = previousPrevious[rightIndex - 2] + 1;
        if (transposed < distance) {
          distance = transposed;
        }
      }
      current[rightIndex] = distance;
    }
    previousPrevious = previous;
    previous = current;
  }

  final distance = previous.last;
  return distance <= maxDistance ? distance : null;
}

int _minimum3(int first, int second, int third) {
  final smallest = first < second ? first : second;
  return smallest < third ? smallest : third;
}

List<String> _tokens(String input) => input
    .split(RegExp(r'[^a-z0-9]+'))
    .where((token) => token.isNotEmpty)
    .toList(growable: false);

String _compact(String input) => input.replaceAll(RegExp(r'[^a-z0-9]+'), '');

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
