import 'package:flutter/services.dart';

/// Registers again after runtime Firebase setup and waits for Apple's callback.
class IosPushRegistration {
  static const channel = MethodChannel('accord/push_registration');

  static Future<void> ensureReady({required void Function() onReady}) async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'apnsReady') onReady();
    });
    await channel.invokeMethod<bool>('register');
  }
}
