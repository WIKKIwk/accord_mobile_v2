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

  test('media validation and local recovery failures are user-facing', () {
    const durationFailure = MobileApiException(
      code: 'video_duration_too_long',
      message: 'invalid',
      statusCode: 422,
    );

    expect(chatMediaFailureMessage(durationFailure), contains('120'));
    expect(
      chatMediaFailureMessage(
        StateError('chat_media_local_file_missing'),
      ),
      contains('topilmadi'),
    );
    expect(
      chatMediaFailureMessage(
        TimeoutException('chat_media_processing_timeout'),
      ),
      contains('uzoq'),
    );
  });
}
