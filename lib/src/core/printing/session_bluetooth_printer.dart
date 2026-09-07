import 'package:flutter/foundation.dart';

import '../native_bluetooth_printer.dart';

/// App sessiyasi davomida tanlangan Bluetooth printerni eslab qoladi.
///
/// Faqat xotirada (in-memory) saqlanadi: app process to'liq yopilganda o'zi
/// unutiladi, diskka yozilmaydi. GScale dagi
/// `gscale_last_print_device_v1` persistent mexanizmidan farqli — bu ataylab
/// sessiya bilan chegaralangan: keyingi kirishda user yana bir marta tanlaydi.
class SessionBluetoothPrinter {
  const SessionBluetoothPrinter._();

  static BluetoothPrinterProfile? _cached;

  /// Hozirgi kesh (validatsiyasiz). Faqat UI ko'rsatish uchun.
  static BluetoothPrinterProfile? get cached => _cached;

  static void remember(BluetoothPrinterProfile printer) {
    if (printer.address.trim().isEmpty) {
      return;
    }
    _cached = printer;
  }

  static void forget() {
    _cached = null;
  }

  /// Chop etish muvaffaqiyatsiz bo'lganda chaqiriladi: keshdagi manzil
  /// xatolik bergan manzil bilan bir xil bo'lsa, kesh tozalanadi — keyingi
  /// urinishda picker qayta ochiladi va user boshqa printer tanlay oladi.
  static void forgetIfMatches(String? address) {
    if (address == null || _cached == null) {
      return;
    }
    if (_normalizeAddress(_cached!.address) == _normalizeAddress(address)) {
      _cached = null;
    }
  }

  /// Keshdagi printerni qaytaradi, agar u hali ham qurilmada paired bo'lsa.
  ///
  /// iOS da paired ro'yxatni arzon tekshirib bo'lmaydi — kesh optimistik
  /// qaytadi. Validatsiya paytida platforma xatoligi bo'lsa kesh o'chirilmaydi,
  /// `null` qaytadi (picker ochilib, xatolik UI da ko'rinadi).
  /// Keshdagi manzil paired ro'yxatda topilmasa — kesh eskirgan deb o'chiriladi.
  static Future<BluetoothPrinterProfile?> resolveCached() async {
    final cached = _cached;
    if (cached == null || cached.address.trim().isEmpty) {
      return null;
    }
    if (kIsWeb) {
      return cached;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return cached;
    }
    try {
      final paired = await NativeBluetoothPrinter.pairedPrinters();
      final wanted = _normalizeAddress(cached.address);
      for (final printer in paired) {
        if (_normalizeAddress(printer.address) == wanted) {
          return printer.address.trim().isEmpty ? cached : printer;
        }
      }
      // Juftlikdan o'chirilgan — kesh eskirgan.
      _cached = null;
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _normalizeAddress(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-f0-9]'), '');
  }
}
