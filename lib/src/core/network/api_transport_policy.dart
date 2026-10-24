import 'package:flutter/foundation.dart';

/// Cleartext API connections are limited to loopback during local development.
bool allowsApiTransport(
  Uri uri, {
  bool allowDebugLoopback = kDebugMode,
}) {
  if (uri.host.isEmpty || uri.userInfo.isNotEmpty) return false;
  if (uri.scheme == 'https') return true;
  return allowDebugLoopback &&
      uri.scheme == 'http' &&
      const {'127.0.0.1', 'localhost', '::1'}.contains(uri.host.toLowerCase());
}
