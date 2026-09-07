import 'package:accord_mobile_v2/src/core/native_bluetooth_printer.dart';
import 'package:accord_mobile_v2/src/core/printing/session_bluetooth_printer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('accord/bluetooth_printer');

  setUp(() {
    SessionBluetoothPrinter.forget();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    SessionBluetoothPrinter.forget();
  });

  void mockPairedPrinters(List<Map<String, Object?>> printers) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'pairedPrinters');
      return <Object?>[...printers];
    });
  }

  test('remember keeps the printer only in memory for the session', () {
    expect(SessionBluetoothPrinter.cached, isNull);

    SessionBluetoothPrinter.remember(
      const BluetoothPrinterProfile(
        name: 'XP-P323B',
        address: '00:11:22:33:44:55',
      ),
    );

    expect(SessionBluetoothPrinter.cached?.address, '00:11:22:33:44:55');

    SessionBluetoothPrinter.forget();
    expect(SessionBluetoothPrinter.cached, isNull);
  });

  test('remember ignores an empty address', () {
    SessionBluetoothPrinter.remember(
      const BluetoothPrinterProfile(name: 'XP-P323B', address: '  '),
    );

    expect(SessionBluetoothPrinter.cached, isNull);
  });

  test('forgetIfMatches clears only the matching printer', () {
    SessionBluetoothPrinter.remember(
      const BluetoothPrinterProfile(
        name: 'XP-P323B',
        address: '00:11:22:33:44:55',
      ),
    );

    SessionBluetoothPrinter.forgetIfMatches('AA:BB:CC:DD:EE:FF');
    expect(SessionBluetoothPrinter.cached, isNotNull);

    // Manzil formati farqli yozilsa ham mos kelishi kerak.
    SessionBluetoothPrinter.forgetIfMatches('00-11-22-33-44-55');
    expect(SessionBluetoothPrinter.cached, isNull);
  });

  test('resolveCached returns the printer while it stays paired', () async {
    SessionBluetoothPrinter.remember(
      const BluetoothPrinterProfile(
        name: 'Eski nom',
        address: '00:11:22:33:44:55',
      ),
    );
    mockPairedPrinters([
      <String, Object?>{
        'name': 'XP-P323B',
        'address': '00:11:22:33:44:55',
      },
      <String, Object?>{
        'name': 'Boshqa',
        'address': 'AA:BB:CC:DD:EE:FF',
      },
    ]);

    final resolved = await SessionBluetoothPrinter.resolveCached();

    expect(resolved?.address, '00:11:22:33:44:55');
    // Paired ro'yxatdagi dolzarb nom qaytadi.
    expect(resolved?.name, 'XP-P323B');
    expect(SessionBluetoothPrinter.cached, isNotNull);
  });

  test('resolveCached forgets the printer once it is unpaired', () async {
    SessionBluetoothPrinter.remember(
      const BluetoothPrinterProfile(
        name: 'XP-P323B',
        address: '00:11:22:33:44:55',
      ),
    );
    mockPairedPrinters([
      <String, Object?>{
        'name': 'Boshqa',
        'address': 'AA:BB:CC:DD:EE:FF',
      },
    ]);

    final resolved = await SessionBluetoothPrinter.resolveCached();

    expect(resolved, isNull);
    expect(SessionBluetoothPrinter.cached, isNull);
  });

  test('resolveCached keeps the cache when validation fails', () async {
    SessionBluetoothPrinter.remember(
      const BluetoothPrinterProfile(
        name: 'XP-P323B',
        address: '00:11:22:33:44:55',
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'PERMISSION_DENIED');
    });

    final resolved = await SessionBluetoothPrinter.resolveCached();

    expect(resolved, isNull);
    // Keyingi urinishda picker ochiladi, kesh o'chirilmaydi.
    expect(SessionBluetoothPrinter.cached, isNotNull);
  });
}
