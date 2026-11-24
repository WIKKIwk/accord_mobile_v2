import 'dart:async';

import 'warehouse_live_client_stub.dart'
    if (dart.library.io) 'warehouse_live_client_io.dart'
    if (dart.library.html) 'warehouse_live_client_web.dart';

Stream<Map<String, dynamic>> connectWarehouseLive(Uri uri, {Future<Uri> Function()? refreshTicket}) {
  return connectWarehouseLivePlatform(uri, refreshTicket: refreshTicket);
}

Stream<Map<String, dynamic>> connectSystemMonitorLive(Uri uri, {Future<Uri> Function()? refreshTicket}) {
  return connectSystemMonitorLivePlatform(uri, refreshTicket: refreshTicket);
}
