enum PrintTransport {
  offline('offline'),
  bluetooth('bluetooth'),
  wifi('wifi');

  const PrintTransport(this.apiValue);

  final String apiValue;

  bool get isOffline => this == PrintTransport.offline;
  bool get isBluetooth => this == PrintTransport.bluetooth;
  bool get isLocal => isOffline || isBluetooth;

  String get clientApiValue =>
      isLocal ? PrintTransport.offline.apiValue : apiValue;
}

const String offlineUsbDriverUrl = 'usb://local';
