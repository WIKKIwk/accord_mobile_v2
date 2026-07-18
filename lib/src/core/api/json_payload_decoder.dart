import 'dart:convert';

import 'package:flutter/foundation.dart';

const int defaultBackgroundJsonThresholdCodeUnits = 128 * 1024;

Future<Object?> decodeJsonPayload(
  String source, {
  int backgroundThresholdCodeUnits = defaultBackgroundJsonThresholdCodeUnits,
}) async {
  if (kIsWeb || source.length < backgroundThresholdCodeUnits) {
    return jsonDecode(source);
  }
  return compute(
    _decodeJsonPayload,
    source,
    debugLabel: 'api-json-decode',
  );
}

Future<List<dynamic>> decodeJsonListPayload(
  String source, {
  int backgroundThresholdCodeUnits = defaultBackgroundJsonThresholdCodeUnits,
}) async {
  return await decodeJsonPayload(
    source,
    backgroundThresholdCodeUnits: backgroundThresholdCodeUnits,
  ) as List<dynamic>;
}

Future<Map<String, dynamic>> decodeJsonMapPayload(
  String source, {
  int backgroundThresholdCodeUnits = defaultBackgroundJsonThresholdCodeUnits,
}) async {
  return (await decodeJsonPayload(
    source,
    backgroundThresholdCodeUnits: backgroundThresholdCodeUnits,
  ) as Map)
      .cast<String, dynamic>();
}

Object? _decodeJsonPayload(String source) => jsonDecode(source);
