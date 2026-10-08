part of 'native_iroh_transport_test.dart';

void _registerNativeGzipTests(String cached) {
  const channel = MethodChannel('accord/iroh_transport');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final chunked in [false, true]) {
    for (final method in ['GET', 'POST']) {
      test('native $method gzip preserves bytes with chunked=$chunked',
          () async {
        SharedPreferences.setMockInitialValues(
            {'iroh_endpoint_v2:https://test.invalid': cached});
        final original = utf8.encode(jsonEncode({
          'rev': 17,
          'epoch': 'fixture',
          'orders': List.generate(100, (i) => {'id': '$i', 'name': 'O‘zbek 字'}),
        }));
        final compressed = gzip.encode(original);
        var requests = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'isSupported') return true;
          if (call.method != 'request') return null;
          final args = call.arguments as Map;
          if (args['path'] == '/healthz') {
            return {'statusCode': 200, 'body': utf8.encode('{"ok":true}')};
          }
          requests++;
          expect(args['method'], method);
          expect((args['headers'] as Map)['accept-encoding'], 'gzip');
          expect(
              (args['headers'] as Map).containsKey('Accept-Encoding'), isFalse);
          final wire = chunked
              ? [
                  ...ascii.encode('${compressed.length.toRadixString(16)}\r\n'),
                  ...compressed,
                  ...ascii.encode('\r\n0\r\n\r\n')
                ]
              : compressed;
          return {
            'statusCode': 200,
            'headers': {
              'content-encoding': 'gzip',
              'content-type': 'application/json; charset=utf-8',
              if (chunked) 'transfer-encoding': 'chunked',
              if (!chunked) 'content-length': compressed.length.toString(),
            },
            'body': Uint8List.fromList(wire),
          };
        });
        final uri = Uri.parse('https://test.invalid/v1/mobile/test');
        await http.runWithClient(() async {
          await NativeIrohTransport.warmUp(uri);
          final response = await NativeIrohTransport.send(
            method: method,
            uri: uri,
            headers: {'Accept-Encoding': 'br'},
            body: '{}',
          );
          expect(response.bodyBytes, original);
          expect(response.headers['content-encoding'], isNull);
          expect(response.headers['transfer-encoding'], isNull);
          expect(
              response.headers['content-length'], original.length.toString());
          expect(jsonDecode(response.body)['rev'], 17);
        },
            () => MockClient(
                (_) async => throw StateError('unexpected HTTP replay')));
        expect(requests, 1);
      });
    }
  }

  for (final failure in ['truncated', 'checksum', 'length', 'unsupported']) {
    for (final method in ['GET', 'POST']) {
      test('native $method rejects $failure gzip without replaying writes',
          () async {
        SharedPreferences.setMockInitialValues(
            {'iroh_endpoint_v2:https://test.invalid': cached});
        final compressed = gzip.encode(utf8.encode('{"ok":true,"rev":17}'));
        final wire = List<int>.from(compressed);
        if (failure == 'truncated')
          wire.removeRange(wire.length - 8, wire.length);
        if (failure == 'checksum') wire[wire.length - 8] ^= 1;
        var requests = 0, httpReads = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'isSupported') return true;
          if (call.method != 'request') return null;
          if ((call.arguments as Map)['path'] == '/healthz') {
            return {'statusCode': 200, 'body': utf8.encode('{"ok":true}')};
          }
          requests++;
          return {
            'statusCode': 200,
            'headers': {
              'content-encoding': failure == 'unsupported' ? 'br' : 'gzip',
              'content-length':
                  (wire.length + (failure == 'length' ? 1 : 0)).toString(),
            },
            'body': Uint8List.fromList(wire),
          };
        });
        final uri = Uri.parse('https://test.invalid/v1/mobile/test');
        await http.runWithClient(() async {
          await NativeIrohTransport.warmUp(uri);
          final pending =
              NativeIrohTransport.send(method: method, uri: uri, body: '{}');
          if (method == 'GET') {
            expect((await pending).body, '{"ok":true,"rev":18}');
          } else {
            await expectLater(pending, throwsA(isA<Exception>()));
          }
        },
            () => MockClient((request) async {
                  httpReads++;
                  expect(request.method, 'GET');
                  return http.Response('{"ok":true,"rev":18}', 200);
                }));
        expect(requests, 1);
        expect(httpReads, method == 'GET' ? 1 : 0);
      });
    }
  }

  for (final method in ['GET', 'HEAD']) {
    test('native $method bodyless gzip metadata is not decoded', () async {
      SharedPreferences.setMockInitialValues(
          {'iroh_endpoint_v2:https://test.invalid': cached});
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isSupported') return true;
        if (call.method != 'request') return null;
        if ((call.arguments as Map)['path'] == '/healthz') {
          return {'statusCode': 200, 'body': utf8.encode('{"ok":true}')};
        }
        return {
          'statusCode': method == 'HEAD' ? 200 : 304,
          'headers': {
            'content-encoding': 'gzip',
            'content-length': method == 'HEAD' ? '1234' : '0'
          },
          'body': <int>[],
        };
      });
      final uri = Uri.parse('https://test.invalid/v1/mobile/test');
      await http.runWithClient(() async {
        await NativeIrohTransport.warmUp(uri);
        final response =
            await NativeIrohTransport.send(method: method, uri: uri);
        expect(response.statusCode, method == 'HEAD' ? 200 : 304);
        expect(response.bodyBytes, isEmpty);
      },
          () => MockClient(
              (_) async => throw StateError('unexpected HTTP replay')));
    });
  }
}
