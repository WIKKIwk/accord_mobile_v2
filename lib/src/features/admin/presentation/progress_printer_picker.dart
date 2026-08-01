import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/native_bluetooth_printer.dart';
import '../../../core/native_usb_printer.dart';
import '../../../core/print_transport.dart';
import '../../gscale/gscale_mobile_app.dart'
    show DiscoveredServer, driverUrlForRs, showPrintDevicePicker;

class ProgressPrinterOption {
  const ProgressPrinterOption({
    required this.server,
    required this.driverUrl,
    required this.printerLabel,
    this.printer = '',
    this.printMode = '',
  })  : transport = PrintTransport.wifi,
        offlinePrinter = null,
        bluetoothPrinter = null;

  ProgressPrinterOption.offline(UsbPrinterProfile profile)
      : server = null,
        driverUrl = offlineUsbDriverUrl,
        printerLabel = profile.displayName,
        transport = PrintTransport.offline,
        printer = profile.printer,
        printMode = profile.printMode,
        offlinePrinter = profile,
        bluetoothPrinter = null;

  ProgressPrinterOption.bluetooth(BluetoothPrinterProfile profile)
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

Future<ProgressPrinterOption?> pickProgressPrinter(
  BuildContext context, {
  Future<String?> Function(BuildContext context)? driverUrlPicker,
}) async {
  if (driverUrlPicker != null) {
    final driverUrl = await driverUrlPicker(context);
    if (driverUrl == null) {
      return null;
    }
    return ProgressPrinterOption(
      server: null,
      driverUrl: driverUrl,
      printerLabel: 'RPS printer',
    );
  }

  final selection = await showPrintDevicePicker(context);
  if (selection == null) {
    return null;
  }
  if (selection.transport.isOffline) {
    final printer = selection.offlinePrinter;
    return printer == null ? null : ProgressPrinterOption.offline(printer);
  }
  if (selection.transport.isBluetooth) {
    final printer = selection.bluetoothPrinter;
    return printer == null ? null : ProgressPrinterOption.bluetooth(printer);
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

Future<ProgressPrinterOption?> _connectedProgressPrinter(
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
    return ProgressPrinterOption(
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
