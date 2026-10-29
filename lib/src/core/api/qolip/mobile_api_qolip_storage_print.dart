part of '../mobile_api.dart';

extension MobileApiQolipStoragePrint on MobileApi {
  Future<UsbRpsPrintRequest> qolipPrintPaddonQr({
    required String code,
    required String driverUrl,
    String printer = '',
    String printMode = '',
    PrintTransport transport = PrintTransport.wifi,
  }) async {
    final normalized = code.trim().toUpperCase();
    final response = await _qolipStorageRequest('paddons/qr/print', body: {
      'qolip_code': normalized,
      'driver_url': driverUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
      'printer': printer,
      'print_mode': printMode,
      'print_count': 1,
      if (transport.isLocal) 'print_transport': transport.clientApiValue,
    });
    if (response['qr_payload'] != 'qolip-paddon:$normalized' ||
        response['print'] is! Map) {
      throw const FormatException('Invalid mold pallet print response');
    }
    final job = UsbRpsPrintRequest.fromPrintJson(
      Map<String, dynamic>.from(response['print'] as Map),
      paddonLabelLines: transport.isBluetooth
          ? _qolipPaddonBluetoothLabelLines(normalized, response['paddon'])
          : const [],
    );
    if (job.epc != 'qolip-paddon:$normalized' || !job.isPaddonCodeLabel) {
      throw const FormatException('Mold pallet print identity changed');
    }
    return job;
  }
}

List<String> _qolipPaddonBluetoothLabelLines(String code, Object? rawPaddon) {
  final paddon = rawPaddon is Map ? rawPaddon : null;
  final responseCode = paddon?['code']?.toString().trim().toUpperCase();
  if (responseCode != null && responseCode.isNotEmpty && responseCode != code) {
    throw const FormatException('Mold pallet summary identity changed');
  }
  final rawCount =
      responseCode == code && paddon != null ? paddon['item_count'] : null;
  final count = rawCount is num &&
          rawCount.isFinite &&
          rawCount >= 0 &&
          rawCount == rawCount.toInt()
      ? rawCount.toInt().toString()
      : '—';
  return ['Qolip paddoni: $code', 'Qoliplar soni: $count'];
}
