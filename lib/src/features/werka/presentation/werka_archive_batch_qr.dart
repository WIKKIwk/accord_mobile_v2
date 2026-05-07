import 'dart:convert';

class WerkaArchiveBatchQrPayload {
  const WerkaArchiveBatchQrPayload({
    required this.sessionID,
    required this.itemName,
    required this.qtyText,
    required this.qty,
    required this.batchTime,
    required this.rawValue,
  });

  final String sessionID;
  final String itemName;
  final String qtyText;
  final double qty;
  final String batchTime;
  final String rawValue;

  static WerkaArchiveBatchQrPayload? tryParse(String rawValue) {
    final raw = rawValue.trim();
    if (raw.isEmpty) {
      return null;
    }

    final encoded = _archiveEncodedPayload(raw);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    final decoded = _decodeBase64Url(encoded);
    if (decoded == null) {
      return null;
    }

    final lines =
        decoded.split('\n').map((line) => line.trim()).toList(growable: false);
    if (lines.length < 5 || lines.first.toUpperCase() != 'ARCHIVE') {
      return null;
    }

    final qtyText = lines[3];
    final qty = double.tryParse(qtyText.replaceAll(',', '.')) ?? 0;
    if (qty <= 0) {
      return null;
    }

    return WerkaArchiveBatchQrPayload(
      sessionID: lines[1],
      itemName: lines[2],
      qtyText: qtyText,
      qty: qty,
      batchTime: lines[4],
      rawValue: raw,
    );
  }

  static String? _archiveEncodedPayload(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.pathSegments.isNotEmpty) {
      final segments = uri.pathSegments
          .where((segment) => segment.trim().isNotEmpty)
          .toList(growable: false);
      if (segments.length >= 2 && segments.first.toUpperCase() == 'A') {
        return segments[1].trim();
      }
    }

    final marker = raw.indexOf('/A/');
    if (marker >= 0) {
      return raw.substring(marker + 3).split('/').first.trim();
    }

    return null;
  }

  static String? _decodeBase64Url(String encoded) {
    try {
      return utf8.decode(base64Url.decode(base64Url.normalize(encoded)));
    } catch (_) {
      return null;
    }
  }
}
