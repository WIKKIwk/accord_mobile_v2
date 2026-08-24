import 'package:accord_mobile_v2/src/core/session/accounts/platform_account_secret_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('accord/secure_account_storage');
  final values = <String, String>{};

  setUp(() {
    values.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final arguments = Map<String, dynamic>.from(call.arguments as Map);
      final key = arguments['key'] as String;
      switch (call.method) {
        case 'read':
          return values[key];
        case 'write':
          values[key] = arguments['value'] as String;
          return null;
        case 'delete':
          values.remove(key);
          return null;
      }
      throw PlatformException(code: 'unexpected_method');
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('writes reads and deletes a secret through the native channel',
      () async {
    const store = PlatformAccountSecretStore();

    await store.write('account-key', 'secret-value');
    expect(await store.read('account-key'), 'secret-value');

    await store.delete('account-key');
    expect(await store.read('account-key'), isNull);
  });

  test('rejects empty secret keys before calling the native channel', () async {
    const store = PlatformAccountSecretStore();

    await expectLater(store.read('   '), throwsArgumentError);
    await expectLater(store.write('', 'value'), throwsArgumentError);
    await expectLater(store.delete('\n'), throwsArgumentError);
  });
}
