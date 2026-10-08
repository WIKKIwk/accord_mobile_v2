import 'dart:io' show gzip;

// The ERP encoder emits one gzip member. Dart's decoder can accept a missing
// trailer, so verify its size and CRC before exposing a successful response.
List<int> decodeNativeGzip(List<int> bytes) {
  if (bytes.length < 18) {
    throw const FormatException('Incomplete native gzip response');
  }
  final decoded = gzip.decode(bytes);
  int trailerInt(int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
  if (trailerInt(bytes.length - 4) != (decoded.length & 0xffffffff)) {
    throw const FormatException('Incomplete native gzip response');
  }
  var crc = 0xffffffff;
  for (final byte in decoded) {
    crc = _crc32Table[(crc ^ byte) & 0xff] ^ (crc >> 8);
  }
  if ((crc ^ 0xffffffff) != trailerInt(bytes.length - 8)) {
    throw const FormatException('Invalid native gzip checksum');
  }
  return decoded;
}

final _crc32Table = List<int>.generate(256, (value) {
  var crc = value;
  for (var bit = 0; bit < 8; bit++) {
    crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
  }
  return crc;
}, growable: false);
