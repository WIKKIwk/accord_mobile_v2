import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Retry only an explicitly supplied GET operation. Mutation callers never use
/// this helper, because a lost response does not mean a write was not committed.
Future<http.Response> resilientApiRead(
  Uri uri,
  Future<http.Response> Function(Future<void> abortTrigger) send, {
  Duration attemptTimeout = const Duration(seconds: 10),
  Duration totalTimeout = const Duration(seconds: 15),
  Duration retryDelay = const Duration(milliseconds: 150),
  bool retryTransient = true,
}) async {
  final elapsed = Stopwatch()..start();
  final attempts = retryTransient ? 2 : 1;
  for (var attempt = 1; attempt <= attempts; attempt++) {
    final remaining = totalTimeout - elapsed.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException('API read deadline exceeded', totalTimeout);
    }
    final timeout = remaining < attemptTimeout ? remaining : attemptTimeout;
    final abort = Completer<void>();
    String? failure;
    try {
      final response = await send(abort.future).timeout(timeout, onTimeout: () {
        abort.complete();
        throw TimeoutException('API read attempt timed out', timeout);
      });
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      final html = uri.path.startsWith('/v1/mobile/') &&
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (contentType.contains('text/html') ||
              (contentType.isEmpty &&
                  RegExp(r'^\s*<(?:!doctype\s+html|html)[\s>]',
                          caseSensitive: false)
                      .hasMatch(response.body)));
      if (html) {
        failure = 'unexpected_html';
        if (attempt == attempts) {
          throw http.ClientException('API returned HTML instead of data', uri);
        }
      } else if (const {502, 503, 504}.contains(response.statusCode)) {
        failure = 'http_${response.statusCode}';
        if (attempt == attempts) {
          _readDiagnostic(uri, attempt, failure);
          return response;
        }
      } else {
        return response;
      }
    } on TimeoutException {
      failure ??= 'timeout';
      if (attempt == attempts) {
        _readDiagnostic(uri, attempt, failure);
        rethrow;
      }
    } on http.ClientException catch (error) {
      failure ??= _clientFailure(error);
      if (attempt == attempts ||
          failure == 'transport_policy' ||
          failure == 'tls') {
        _readDiagnostic(uri, attempt, failure);
        rethrow;
      }
    }
    _readDiagnostic(uri, attempt, failure);
    final delayBudget = totalTimeout - elapsed.elapsed;
    if (delayBudget <= retryDelay) {
      throw TimeoutException('API read deadline exceeded', totalTimeout);
    }
    await Future<void>.delayed(retryDelay);
  }
  throw StateError('API read attempts exhausted');
}

String _clientFailure(http.ClientException error) {
  final message = error.message.toLowerCase();
  if (message.contains('require https') ||
      message.contains('too many api redirects')) {
    return 'transport_policy';
  }
  if (message.contains('certificate') || message.contains('handshake')) {
    return 'tls';
  }
  if (message.contains('connection reset')) return 'connection_reset';
  if (message.contains('connection closed') ||
      message.contains('connection aborted')) {
    return 'connection_closed';
  }
  if (message.contains('failed host lookup')) return 'dns';
  return 'transport';
}

void _readDiagnostic(Uri uri, int attempt, String reason) {
  // Deliberately omit query parameters, credentials, headers and response bodies.
  debugPrint('mobile_api_read GET ${uri.path} attempt=$attempt reason=$reason');
}
