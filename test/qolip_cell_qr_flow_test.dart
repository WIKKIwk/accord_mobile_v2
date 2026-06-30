import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    AppSession.instance.token = 'qolip-token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Qolipchi',
      legalName: '',
      ref: 'qolipchi-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['qolip.manage'],
    );
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('qolip cell qr lookup resolves scanned cell address', () async {
    final seenRequests = <String>[];

    await HttpOverrides.runZoned(() async {
      final cell = await MobileApi.instance.qolipCellQrLookup('CELL-QR-A3');

      expect(cell.block, 'A blok');
      expect(cell.warehouse, 'Qolip ombor');
      expect(cell.rowLetter, 'A');
      expect(cell.columnNumber, 3);
      expect(cell.locationLabel, 'A3');
      expect(
        seenRequests,
        contains('GET /v1/mobile/qolip/cell-qr?qr=CELL-QR-A3'),
      );
    }, createHttpClient: (_) => _QolipCellQrHttpClient(seenRequests));
  });

  test('qolip code qr print sends qolip code as stable payload', () async {
    final seenRequests = <String>[];
    final seenBodies = <String>[];

    await HttpOverrides.runZoned(() async {
      final qr = await MobileApi.instance.qolipPrintCodeQr(
        qolipCode: 'QOLIP-0007',
        driverUrl: 'http://127.0.0.1:39117',
        printer: 'zebra',
        printMode: 'rfid',
      );

      expect(qr.qolipCode, 'QOLIP-0007');
      expect(qr.qrPayload, 'QOLIP-0007');
      expect(
        seenRequests,
        contains('POST /v1/mobile/qolip/code-qr/print?'),
      );
      final body = jsonDecode(seenBodies.single) as Map<String, dynamic>;
      expect(body['qolip_code'], 'QOLIP-0007');
      expect(body['driver_url'], 'http://127.0.0.1:39117');
      expect(body['printer'], 'zebra');
      expect(body['print_mode'], 'rfid');
    },
        createHttpClient: (_) =>
            _QolipCellQrHttpClient(seenRequests, seenBodies));
  });

  test('qolip product lookup resolves scanned qolip code', () async {
    final seenRequests = <String>[];

    await HttpOverrides.runZoned(() async {
      final product = await MobileApi.instance.qolipProductByQr('QOLIP-0007');

      expect(product.qolipCode, 'QOLIP-0007');
      expect(product.name, 'Kross qolip');
      expect(
        seenRequests,
        contains(
          'GET /v1/mobile/qolip/products?q=QOLIP-0007&limit=20&with_qolip=true',
        ),
      );
    }, createHttpClient: (_) => _QolipCellQrHttpClient(seenRequests));
  });

  test('qolip location save sends selected child qolip code and size',
      () async {
    final seenRequests = <String>[];
    final seenBodies = <String>[];

    await HttpOverrides.runZoned(() async {
      await MobileApi.instance.qolipSaveLocation(
        block: const QolipBlock(name: 'A blok', warehouse: 'Qolip ombor'),
        product: const QolipProduct(
          code: 'ITEM-001',
          name: 'Kross qolip',
          itemGroup: 'Qolip',
          qolipCode: 'QOLIP-0002',
          qolipSize: 42,
          hasQolipSpec: true,
        ),
        quantity: 1,
        rowLetter: 'A',
        columnNumber: 2,
      );

      expect(seenRequests, contains('POST /v1/mobile/qolip/locations?'));
      final body = jsonDecode(seenBodies.single) as Map<String, dynamic>;
      expect(body['item_code'], 'ITEM-001');
      expect(body['qolip_code'], 'QOLIP-0002');
      expect(body['size'], 42);
      expect(body['quantity'], 1);
    },
        createHttpClient: (_) =>
            _QolipCellQrHttpClient(seenRequests, seenBodies));
  });
}

class _QolipCellQrHttpClient implements HttpClient {
  _QolipCellQrHttpClient(this.seenRequests, [List<String>? seenBodies])
      : seenBodies = seenBodies ?? <String>[];

  final List<String> seenRequests;
  final List<String> seenBodies;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final key = '$method ${url.path}?${url.query}';
    seenRequests.add(key);

    if (method == 'GET' && url.path == '/v1/mobile/qolip/cell-qr') {
      return _FakeHttpClientRequest(
        response: _FakeHttpClientResponse(
          body: jsonEncode({
            'ok': true,
            'cell_qr': {
              'id': 'qolip-cell:qolip_ombor:a_blok:a:3',
              'block': 'A blok',
              'warehouse': 'Qolip ombor',
              'row_letter': 'A',
              'column_number': 3,
              'location_label': 'A3',
              'qr_payload': 'CELL-QR-A3',
            },
          }),
          statusCode: HttpStatus.ok,
        ),
      );
    }

    if (method == 'GET' && url.path == '/v1/mobile/qolip/products') {
      return _FakeHttpClientRequest(
        response: _FakeHttpClientResponse(
          body: jsonEncode({
            'ok': true,
            'products': [
              {
                'code': 'ITEM-001',
                'name': 'Kross qolip',
                'item_group': 'Qolip',
                'qolip_code': 'QOLIP-0007',
                'size': 42,
                'has_qolip_spec': true,
              },
            ],
          }),
          statusCode: HttpStatus.ok,
        ),
      );
    }

    if (method == 'POST' && url.path == '/v1/mobile/qolip/code-qr/print') {
      return _FakeHttpClientRequest(
        onBody: seenBodies.add,
        response: _FakeHttpClientResponse(
          body: jsonEncode({
            'ok': true,
            'qolip_qr': {
              'qolip_code': 'QOLIP-0007',
              'qr_payload': 'QOLIP-0007',
              'item_code': 'ITEM-001',
              'item_name': 'Kross qolip',
              'item_group': 'Qolip',
              'size': 42,
            },
          }),
          statusCode: HttpStatus.ok,
        ),
      );
    }

    if (method == 'POST' && url.path == '/v1/mobile/qolip/locations') {
      return _FakeHttpClientRequest(
        onBody: seenBodies.add,
        response: _FakeHttpClientResponse(
          body: jsonEncode({
            'ok': true,
            'location': {
              'id': 'qolip:a:ITEM-001:QOLIP-0002:42:A:2',
              'block': 'A blok',
              'warehouse': 'Qolip ombor',
              'item_code': 'ITEM-001',
              'item_name': 'Kross qolip',
              'qolip_code': 'QOLIP-0002',
              'size': 42,
              'quantity': 1,
              'row_letter': 'A',
              'column_number': 2,
              'location_label': 'A2',
            },
          }),
          statusCode: HttpStatus.ok,
        ),
      );
    }

    return _FakeHttpClientRequest(
      response: _FakeHttpClientResponse(
        body: jsonEncode({'error': 'Unhandled request: $key'}),
        statusCode: HttpStatus.notFound,
      ),
    );
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  void close({bool force = false}) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest({required this.response, this.onBody});

  final _FakeHttpClientResponse response;
  final void Function(String body)? onBody;
  final _headers = _FakeHttpHeaders();
  final List<int> _body = [];

  @override
  bool persistentConnection = true;

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = -1;

  @override
  bool bufferOutput = true;

  @override
  List<Cookie> get cookies => const <Cookie>[];

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _body.addAll(chunk);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    onBody?.call(utf8.decode(_body));
    return response;
  }

  @override
  HttpHeaders get headers => _headers;

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding value) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse({
    required this.body,
    required this.statusCode,
  });

  final String body;

  @override
  final int statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([utf8.encode(body)]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  int get contentLength => utf8.encode(body).length;

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  bool persistentConnection = false;

  @override
  String get reasonPhrase => 'OK';

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  void set(
    String name,
    Object value, {
    bool preserveHeaderCase = false,
  }) {}

  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
