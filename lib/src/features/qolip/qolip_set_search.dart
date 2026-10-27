import '../../core/api/mobile_api.dart';
import '../../core/search/search_normalizer.dart';
import '../../core/session/session_read_scope.dart';
import 'qolip_search_engine.dart';

final _setDocuments = Expando<QolipSearchDocument>();
final _setNameDocuments = Expando<QolipSearchDocument>();

Future<List<QolipManagedSet>> searchQolipSets(
  Iterable<QolipManagedSet> sets,
  String query, {
  bool includeMoldCodes = true,
  bool Function()? isCurrent,
}) async {
  final documents = includeMoldCodes ? _setDocuments : _setNameDocuments;
  final matches = await filterQolipSearch(
    sets.where((entry) => entry.set.members.isNotEmpty),
    query,
    (QolipManagedSet entry) => documents[entry] ??= QolipSearchDocument([
      entry.name,
      entry.set.id,
      if (includeMoldCodes) ...entry.set.members.map((mold) => mold.qolipCode),
    ]),
    isCurrent: isCurrent,
  );
  if (matches == null) return const [];
  final needle = query.trim().toLowerCase();
  int score(QolipManagedSet entry) {
    if (entry.set.id.toLowerCase() == needle ||
        (includeMoldCodes &&
            entry.set.members
                .any((mold) => mold.qolipCode.toLowerCase() == needle))) {
      return 100000;
    }
    if (entry.name.toLowerCase() == needle) return 90000;
    return searchRelevanceScore(query: query, primary: entry.name, secondary: [
      entry.set.id,
      if (includeMoldCodes) ...entry.set.members.map((mold) => mold.qolipCode),
    ]);
  }

  matches.sort((a, b) {
    final relevance = score(b).compareTo(score(a));
    if (relevance != 0) return relevance;
    final name =
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    return name != 0 ? name : a.set.id.compareTo(b.set.id);
  });
  return matches;
}

/// Share one scoped catalog read between typing, selection and saving a form.
class QolipSetLookup {
  String? _scope;
  Future<List<QolipManagedSet>>? _future;

  String get _currentScope =>
      '${MobileApi.baseUrl}|${currentSessionReadScope()}';
  bool get isCurrent => _scope == _currentScope;

  Future<List<QolipManagedSet>> load({bool refresh = false}) {
    final scope = _currentScope;
    if (refresh || _scope != scope) {
      _scope = scope;
      _future = null;
    }
    return _future ??= _load(scope);
  }

  Future<List<QolipManagedSet>> _load(String scope) async {
    try {
      final sets = await MobileApi.instance.qolipManagedSets();
      if (scope != _currentScope) {
        throw const MobileApiException(
            code: 'session_scope_changed', message: 'session_scope_changed');
      }
      return sets;
    } catch (_) {
      if (_scope == scope) _future = null;
      rethrow;
    }
  }
}
