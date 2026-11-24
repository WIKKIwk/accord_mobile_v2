part of '../mobile_api.dart';

/// One cancellable watch per account, shared by mounted Qolip screens.
class QolipStorageWatch extends ChangeNotifier {
  QolipStorageWatch._();

  static final instance = QolipStorageWatch._();

  String? _scope;
  String? _revision;
  Completer<void>? _abort;
  int _consumers = 0;
  bool get _hasConsumers => hasListeners || _consumers > 0;

  String? get revision =>
      _scope == currentSessionReadScope() ? _revision : null;

  void _seed(Object? revision, String scope) {
    if (revision is! String ||
        revision.isEmpty ||
        scope != currentSessionReadScope() ||
        !AppSession.instance.isLoggedIn) {
      return;
    }
    if (_scope != scope) {
      _stop();
      _scope = scope;
      _revision = null;
    }
    _revision ??= revision;
    _start();
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _start();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!_hasConsumers) _stop();
  }

  VoidCallback retain() {
    _consumers++;
    _start();
    return () {
      _consumers--;
      if (!_hasConsumers) _stop();
    };
  }

  void _start() {
    final scope = _scope;
    if (!_hasConsumers ||
        _abort != null ||
        scope == null ||
        revision == null ||
        !AppSession.instance.isLoggedIn) {
      return;
    }
    final abort = Completer<void>();
    _abort = abort;
    unawaited(_watch(scope, abort));
  }

  void _stop() {
    _abort?.complete();
    _abort = null;
  }

  Future<void> _watch(String scope, Completer<void> abort) async {
    bool isCurrent() =>
        identical(_abort, abort) &&
        _hasConsumers &&
        scope == currentSessionReadScope() &&
        AppSession.instance.isLoggedIn;
    try {
      while (isCurrent()) {
        final elapsed = Stopwatch()..start();
        try {
          final next = await MobileApi.instance
              ._waitQolipStorageRevision(_revision!, scope, abort.future);
          if (!isCurrent() || next == null) return;
          if (next != _revision) {
            _revision = next;
            QolipCatalogStore.instance.invalidateStorage();
            notifyListeners();
            continue;
          }
          if (elapsed.elapsed >= const Duration(seconds: 1)) continue;
        } catch (_) {
          if (!isCurrent()) return;
        }
        final delay = Completer<void>();
        final timer = Timer(const Duration(seconds: 3), delay.complete);
        await Future.any([delay.future, abort.future]);
        timer.cancel();
      }
    } finally {
      if (identical(_abort, abort)) _abort = null;
    }
  }
}

extension on MobileApi {
  Future<String?> _waitQolipStorageRevision(
      String after, String scope, Future<void> abort) async {
    final uri =
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/storage/revision')
            .replace(queryParameters: {'after': after});
    final response = await _sendAuthorized(() async {
      if (scope != currentSessionReadScope()) {
        throw StateError('Qolip storage account changed');
      }
      final headers = _headers(requireToken());
      late final Future<http.Response> pending;
      if (NativeIrohTransport.canUseFor(uri)) {
        pending = NativeIrohTransport.send(
            method: 'GET',
            uri: uri,
            headers: headers,
            fallbackClient: _httpClient);
      } else {
        final request = http.AbortableRequest('GET', uri, abortTrigger: abort)
          ..headers.addAll(headers);
        pending = _httpClient.send(request).then(http.Response.fromStream);
      }
      return pending.timeout(const Duration(seconds: 17));
    });
    if (response.statusCode == 401 ||
        response.statusCode == 403 ||
        response.statusCode == 404) {
      return null;
    }
    if (response.statusCode != 200) {
      throw StateError('Qolip storage revision failed');
    }
    final data = await decodeJsonMapPayload(response.body);
    final revision = data['storage_revision'];
    if (revision is! String || revision.isEmpty) {
      throw const FormatException('Missing Qolip storage revision');
    }
    return revision;
  }
}
