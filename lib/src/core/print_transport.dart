enum PrintTransport {
  offline('offline'),
  wifi('wifi');

  const PrintTransport(this.apiValue);

  final String apiValue;

  bool get isOffline => this == PrintTransport.offline;
}

const String offlineUsbDriverUrl = 'usb://local';
