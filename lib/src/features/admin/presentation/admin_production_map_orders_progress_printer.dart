part of 'admin_production_map_orders_screen.dart';

class _ProgressPrinterOption {
  const _ProgressPrinterOption({
    required this.server,
    required this.driverUrl,
    required this.printerLabel,
    this.printer = '',
    this.printMode = '',
  })  : transport = PrintTransport.wifi,
        offlinePrinter = null,
        bluetoothPrinter = null;

  _ProgressPrinterOption.offline(UsbPrinterProfile profile)
      : server = null,
        driverUrl = offlineUsbDriverUrl,
        printerLabel = profile.displayName,
        transport = PrintTransport.offline,
        printer = profile.printer,
        printMode = profile.printMode,
        offlinePrinter = profile,
        bluetoothPrinter = null;

  _ProgressPrinterOption.bluetooth(BluetoothPrinterProfile profile)
      : server = null,
        driverUrl = offlineUsbDriverUrl,
        printerLabel = profile.displayName,
        transport = PrintTransport.bluetooth,
        printer = profile.printer,
        printMode = profile.printMode,
        offlinePrinter = null,
        bluetoothPrinter = profile;

  final DiscoveredServer? server;
  final String driverUrl;
  final String printerLabel;
  final PrintTransport transport;
  final String printer;
  final String printMode;
  final UsbPrinterProfile? offlinePrinter;
  final BluetoothPrinterProfile? bluetoothPrinter;
}

Future<_ProgressPrinterOption?> _showProgressPrinterPicker(
  BuildContext context,
) async {
  final selection = await showPrintDevicePicker(context);
  if (selection == null) {
    return null;
  }
  if (selection.transport.isOffline) {
    final printer = selection.offlinePrinter;
    return printer == null ? null : _ProgressPrinterOption.offline(printer);
  }
  if (selection.transport.isBluetooth) {
    final printer = selection.bluetoothPrinter;
    return printer == null ? null : _ProgressPrinterOption.bluetooth(printer);
  }
  final server = selection.server;
  if (server == null) {
    return null;
  }
  final client = http.Client();
  try {
    return await _connectedProgressPrinter(client, server);
  } finally {
    client.close();
  }
}

Future<_ProgressPrinterOption?> _pickProgressPrinter(
  BuildContext context,
  Future<String?> Function(BuildContext context)? progressDriverUrlPicker,
) async {
  if (progressDriverUrlPicker != null) {
    final driverUrl = await progressDriverUrlPicker(context);
    if (driverUrl == null) {
      return null;
    }
    return _ProgressPrinterOption(
      server: null,
      driverUrl: driverUrl,
      printerLabel: 'RPS printer',
    );
  }
  return _showProgressPrinterPicker(context);
}

Future<_ProgressPrinterOption?> _connectedProgressPrinter(
  http.Client client,
  DiscoveredServer server,
) async {
  try {
    final response = await client
        .get(Uri.parse('${server.endpoint.baseUrl}/v1/mobile/monitor/state'))
        .timeout(const Duration(seconds: 2));
    if (response.statusCode < 200 || response.statusCode > 299) {
      return null;
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final printerRaw = (payload['printer'] as Map?)?.cast<String, dynamic>() ??
        ((payload['state'] as Map?)?['printer'] as Map?)
            ?.cast<String, dynamic>();
    if (printerRaw == null) {
      return null;
    }
    final connected =
        _jsonBool(printerRaw['connected']) || _jsonBool(printerRaw['ok']);
    if (!connected) {
      return null;
    }
    final kind = _jsonText(printerRaw['kind'], fallback: 'printer');
    return _ProgressPrinterOption(
      server: server,
      driverUrl: driverUrlForRs(server).replaceFirst(RegExp(r'/+$'), ''),
      printerLabel: _jsonText(printerRaw['label'], fallback: kind),
      printer: kind,
      printMode: kind.trim().toLowerCase() == 'godex' ? 'label' : 'rfid',
    );
  } catch (_) {
    return null;
  }
}

bool _jsonBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}

String _jsonText(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
