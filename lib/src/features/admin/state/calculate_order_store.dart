export '../../../core/api/mobile_api.dart' show CalculateOrderTemplate;

import '../../../core/api/mobile_api.dart';
import '../../../core/session/session_read_scope.dart';
import 'package:flutter/foundation.dart';

abstract class CalculateOrderTemplateClient {
  Future<List<CalculateOrderTemplate>> listTemplates();
  Future<CalculateOrderTemplate> upsertTemplate(
    CalculateOrderTemplate template,
  );
  Future<void> deleteTemplate(String id);
}

class MobileApiCalculateOrderTemplateClient
    implements CalculateOrderTemplateClient {
  const MobileApiCalculateOrderTemplateClient();

  @override
  Future<List<CalculateOrderTemplate>> listTemplates() {
    return MobileApi.instance.calculateOrderTemplates();
  }

  @override
  Future<CalculateOrderTemplate> upsertTemplate(
    CalculateOrderTemplate template,
  ) {
    return MobileApi.instance.upsertCalculateOrderTemplate(template);
  }

  @override
  Future<void> deleteTemplate(String id) {
    return MobileApi.instance.deleteCalculateOrderTemplate(id);
  }
}

class CalculateOrderTemplateStore extends ChangeNotifier {
  CalculateOrderTemplateStore({
    CalculateOrderTemplateClient? client,
    String Function()? readScope,
  })  : _client = client ?? const MobileApiCalculateOrderTemplateClient(),
        _readScope = readScope ?? currentSessionReadScope;

  static final CalculateOrderTemplateStore instance =
      CalculateOrderTemplateStore();

  final CalculateOrderTemplateClient _client;
  final String Function() _readScope;
  List<CalculateOrderTemplate> _templates = const <CalculateOrderTemplate>[];
  String? _scope;
  int _generation = 0;
  _TemplateArchiveRead? _archiveRead;
  bool _loaded = false;
  bool _disposed = false;

  List<CalculateOrderTemplate> get templates {
    _synchronizeScope();
    return List<CalculateOrderTemplate>.unmodifiable(_templates);
  }

  /// Template ro'yxati serverdan kamida bir marta muvaffaqiyatli yuklanganmi.
  ///
  /// Admin bo'lmagan rollarda `/v1/mobile/calculate/orders` 403 qaytaradi —
  /// bu holda cover rasmlar order-image endpointi orqali yuklanadi.
  bool get isLoaded {
    _synchronizeScope();
    return _loaded;
  }

  CalculateOrderTemplateStoreScope captureScope() {
    return CalculateOrderTemplateStoreScope._(
      _synchronizeScope(),
      _generation,
    );
  }

  bool isCurrentScope(CalculateOrderTemplateStoreScope scope) =>
      _matches(scope);

  Future<void> load({bool force = false}) {
    final scope = captureScope();
    if (_loaded && !force) {
      return Future.value();
    }
    final pending = _archiveRead;
    if (pending != null) {
      return pending.future;
    }
    final read = _TemplateArchiveRead(scope);
    _archiveRead = read;
    read.future = _loadArchive(read);
    return read.future;
  }

  Future<void> _loadArchive(_TemplateArchiveRead read) async {
    try {
      var templates = _dedupeTemplates(await _client.listTemplates());
      if (!_matches(read.scope) || !identical(_archiveRead, read)) {
        return;
      }
      // Preserve writes committed while this older archive snapshot was read.
      for (final mutation in read.mutations) {
        templates = mutation(templates);
      }
      _templates = templates;
      _loaded = true;
      notifyListeners();
    } catch (_) {
      if (_matches(read.scope)) rethrow;
    } finally {
      if (identical(_archiveRead, read)) {
        _archiveRead = null;
      }
    }
  }

  Future<CalculateOrderTemplate> upsert(CalculateOrderTemplate template) async {
    final scope = captureScope();
    final saved = await _client.upsertTemplate(template);
    // The write response is authoritative. A separate archive read must not
    // turn a committed save into a failure and block opening the new order.
    if (_matches(scope)) _remember(saved);
    return saved;
  }

  void remember(
    CalculateOrderTemplate template, {
    CalculateOrderTemplateStoreScope? scope,
  }) {
    final expectedScope = scope ?? captureScope();
    if (!_matches(expectedScope)) return;
    _remember(template);
  }

  void _remember(CalculateOrderTemplate template) {
    List<CalculateOrderTemplate> apply(List<CalculateOrderTemplate> templates) {
      return _dedupeTemplates([
        template,
        ...templates.where((item) => item.id != template.id),
      ]);
    }

    _templates = apply(_templates);
    _archiveRead?.mutations.add(apply);
    // A known saved template is only a partial archive until listTemplates ran.
    notifyListeners();
  }

  Future<void> delete(String id) async {
    final scope = captureScope();
    await _client.deleteTemplate(id);
    if (!_matches(scope)) return;
    List<CalculateOrderTemplate> apply(List<CalculateOrderTemplate> templates) {
      return templates.where((template) => template.id != id).toList();
    }

    _templates = apply(_templates);
    _archiveRead?.mutations.add(apply);
    notifyListeners();
  }

  String _synchronizeScope() {
    final next = _readScope();
    if (_scope != next) {
      _clear(next);
    }
    return next;
  }

  bool _matches(CalculateOrderTemplateStoreScope scope) {
    return !_disposed &&
        scope._scope == _synchronizeScope() &&
        scope._generation == _generation;
  }

  void _clear(String scope) {
    _scope = scope;
    _generation++;
    _archiveRead = null;
    _templates = const <CalculateOrderTemplate>[];
    _loaded = false;
  }

  void reset() {
    _clear(_readScope());
    notifyListeners();
  }

  Future<void> debugReset() async => reset();

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _archiveRead = null;
    super.dispose();
  }
}

/// Retains the originating account/server even if an async save outlives it.
class CalculateOrderTemplateStoreScope {
  const CalculateOrderTemplateStoreScope._(this._scope, this._generation);

  final String _scope;
  final int _generation;
}

class _TemplateArchiveRead {
  _TemplateArchiveRead(this.scope);

  final CalculateOrderTemplateStoreScope scope;
  final mutations =
      <List<CalculateOrderTemplate> Function(List<CalculateOrderTemplate>)>[];
  late final Future<void> future;
}

List<CalculateOrderTemplate> _dedupeTemplates(
  List<CalculateOrderTemplate> templates,
) {
  final seen = <String>{};
  final result = <CalculateOrderTemplate>[];
  for (final template in templates) {
    final code = template.code.trim().toLowerCase();
    final key = code.isNotEmpty ? 'code:$code' : 'id:${template.id.trim()}';
    if (key == 'id:') {
      result.add(template);
      continue;
    }
    if (seen.add(key)) {
      result.add(template);
    }
  }
  return result;
}
