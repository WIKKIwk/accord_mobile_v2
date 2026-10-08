import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:math';

import 'package:accord_mobile_v2/src/core/network/native_gzip_decoder_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('1000 gzip messages preserve every decoded byte', () {
    final random = Random(17);
    for (var sample = 0; sample < 1000; sample++) {
      final bytes =
          List<int>.generate(sample % 1024, (_) => random.nextInt(256));
      expect(decodeNativeGzip(gzip.encode(bytes)), bytes,
          reason: 'sample $sample');
    }
  });

  test('every incomplete gzip prefix and damaged trailer is rejected', () {
    final compressed = gzip.encode(utf8.encode(jsonEncode({
      'rev': 17,
      'orders': List.generate(100, (i) => {'id': i, 'name': 'O‘zbek 字'}),
    })));
    for (var cut = 0; cut < compressed.length; cut++) {
      expect(() => decodeNativeGzip(compressed.sublist(0, cut)),
          throwsA(isA<Exception>()),
          reason: 'prefix $cut');
    }
    for (var offset = compressed.length - 8;
        offset < compressed.length;
        offset++) {
      final damaged = List<int>.from(compressed)..[offset] ^= 1;
      expect(() => decodeNativeGzip(damaged), throwsA(isA<Exception>()),
          reason: 'trailer byte $offset');
    }
  });
}
