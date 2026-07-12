import 'dart:async';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/features/chat/state/chat_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('network and server chat failures are retryable', () {
    expect(isTransientChatFailure(TimeoutException('timeout')), isTrue);
    expect(isTransientChatFailure(http.ClientException('offline')), isTrue);
    expect(
      isTransientChatFailure(
        const MobileApiException(
          code: 'chat_store_failed',
          message: 'failed',
          statusCode: 500,
        ),
      ),
      isTrue,
    );
  });

  test('authorization failure has a useful message and is not retried', () {
    const failure = MobileApiException(
      code: 'authentication_required',
      message: 'failed',
      statusCode: 401,
    );

    expect(isTransientChatFailure(failure), isFalse);
    expect(chatFailureMessage(failure), contains('Sessiya'));
  });
}
