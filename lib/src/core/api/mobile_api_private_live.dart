part of 'mobile_api.dart';

Uri privateLiveUri(String path, [Map<String, String>? query]) {
  final base = Uri.parse(MobileApi.baseUrl);
  return base.replace(
    scheme: base.scheme == 'https' ? 'wss' : 'ws',
    path: path,
    queryParameters: query,
  );
}

extension MobileApiPrivateLive on MobileApi {
  Stream<Map<String, dynamic>> connectPrivateLive(Uri route,
      {bool monitor = false}) {
    final origin = Uri.parse(MobileApi.baseUrl);
    final session = AppSession.instance;
    final token = requireToken();
    final scope = currentSessionReadScope();
    final expected = privateLiveUri(route.path);
    if (route.scheme != expected.scheme ||
        route.authority != expected.authority ||
        route.userInfo.isNotEmpty ||
        route.hasFragment ||
        route.queryParameters.containsKey('token') ||
        route.queryParameters.containsKey('ticket')) {
      throw ArgumentError('Invalid private WebSocket destination');
    }

    bool current() =>
        session.token == token && scope == currentSessionReadScope();
    const expired = MobileApiException(
        code: 'unauthorized',
        message: 'Sessiya muddati tugadi.',
        statusCode: 401);
    Future<void> expire() async {
      final accounts = SavedAccountRuntime.instance;
      if (accounts.isInitialized) {
        final store = accounts.store;
        await store.runAccountOperation(() async {
          if (!current()) return;
          await store.clearActive();
          await session.clear();
        });
      } else if (current()) {
        await session.clear();
      }
    }

    final controller = StreamController<Map<String, dynamic>>();
    StreamIterator<Map<String, dynamic>>? active;
    Completer<void>? paused;
    var cancelled = false;
    void checkSession() {
      if (cancelled || !current()) {
        throw const MobileApiException(
            code: 'session_changed',
            message: 'Ulanish hisob doirasi o‘zgardi.');
      }
    }

    Future<Uri> issue() async {
      checkSession();
      final response = await _post(
          origin.resolve('/v1/mobile/auth/live-ticket'),
          invalidatesSnapshots: false,
          headers: {..._headers(token), 'Content-Type': 'application/json'},
          body: jsonEncode({'path': route.path}));
      checkSession();
      if (response.statusCode == 401) throw expired;
      if (response.statusCode != 200) {
        throw MobileApiException(
            code: 'live_ticket_failed',
            message: 'Ulanish uchun ticket olinmadi.',
            statusCode: response.statusCode);
      }
      final ticket = (await decodeJsonMapPayload(response.body))['ticket'];
      if (ticket is! String || ticket.isEmpty) {
        throw const FormatException('Invalid live ticket');
      }
      checkSession();
      return route.replace(
          queryParameters: {...route.queryParametersAll, 'ticket': ticket});
    }

    Future<void> listen() async {
      try {
        for (var attempt = 0; attempt < 2; attempt++) {
          final signed = await issue();
          checkSession();
          final open =
              monitor ? connectSystemMonitorLive : connectWarehouseLive;
          final events = StreamIterator(open(signed, refreshTicket: issue));
          active = events;
          try {
            while (!cancelled && await events.moveNext()) {
              checkSession();
              final event = events.current;
              if (event['status'] == 401 || event['error'] == 'unauthorized') {
                throw expired;
              }
              controller.add(event);
              if (paused != null) await paused!.future;
            }
            // A clean close returns to the caller's existing reconnect backoff.
            return;
          } on LiveUpgradeFailure catch (failure) {
            checkSession();
            if (failure.status != null && failure.status != 401) rethrow;
            if (attempt == 0) continue;
            // Browser upgrades hide HTTP status. A normal GET with the rejected
            // ticket passes through the same auth middleware before upgrade checks.
            if (failure.status == 401 ||
                (await _httpClient
                            .get(signed.replace(scheme: origin.scheme))
                            .timeout(MobileApi._requestTimeout))
                        .statusCode ==
                    401) {
              throw expired;
            }
            rethrow;
          } finally {
            await events.cancel();
            active = null;
          }
        }
      } catch (error, stack) {
        if (!cancelled) {
          try {
            if (identical(error, expired)) await expire();
          } finally {
            if (!cancelled) controller.addError(error, stack);
          }
        }
      } finally {
        unawaited(controller.close());
      }
    }

    controller.onListen = () => unawaited(listen());
    controller.onPause = () {
      paused ??= Completer<void>();
    };
    void resume() {
      paused?.complete();
      paused = null;
    }

    controller.onResume = resume;
    controller.onCancel = () {
      cancelled = true;
      resume();
      return active?.cancel();
    };
    return controller.stream;
  }
}
