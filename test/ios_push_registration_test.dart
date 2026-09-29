import 'dart:async';

import 'package:accord_mobile_v2/src/core/notifications/service/ios_push_registration.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(IosPushRegistration.channel, null);
    IosPushRegistration.channel.setMethodCallHandler(null);
  });

  test('waits for Apple registration instead of failing on an absent token',
      () async {
    final appleResponse = Completer<bool>();
    var completed = false;
    messenger.setMockMethodCallHandler(IosPushRegistration.channel, (call) {
      expect(call.method, 'register');
      return appleResponse.future;
    });
    final pending = IosPushRegistration.ensureReady(onReady: () {})
        .then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    appleResponse.complete(true);
    await pending;
    expect(completed, isTrue);
  });

  test('preserves native entitlement error and Apple diagnostics', () async {
    messenger.setMockMethodCallHandler(IosPushRegistration.channel, (_) async {
      throw PlatformException(
        code: 'push_config_apns_entitlement_missing',
        message: 'No valid aps-environment entitlement',
        details: {'domain': 'NSCocoaErrorDomain', 'code': 3000},
      );
    });
    await expectLater(
        IosPushRegistration.ensureReady(onReady: () {}),
        throwsA(isA<PlatformException>()
            .having(
                (e) => e.code, 'code', 'push_config_apns_entitlement_missing')
            .having((e) => e.details['code'], 'Apple code', 3000)));
  });

  test('notifies the service if APNs finishes after the registration timeout',
      () async {
    var ready = 0;
    messenger.setMockMethodCallHandler(IosPushRegistration.channel, (_) async {
      throw PlatformException(code: 'push_config_apns_unavailable');
    });
    await expectLater(IosPushRegistration.ensureReady(onReady: () => ready++),
        throwsA(isA<PlatformException>()));
    final handled = Completer<void>();
    await messenger.handlePlatformMessage(
        IosPushRegistration.channel.name,
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('apnsReady')),
        (_) => handled.complete());
    await handled.future;
    expect(ready, 1);
  });
}
