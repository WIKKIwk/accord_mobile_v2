import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('queue action sends material barcode when provided', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Aparatchi',
      legalName: '',
      ref: 'ap-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.manage'],
    );

    await HttpOverrides.runZoned(() async {
      final states = await MobileApi.instance.adminApparatusQueueAction(
        apparatus: 'Pechat',
        orderId: 'zakaz-1',
        action: 'start',
        materialBarcode: 'RM-001',
      );

      expect(states, {'zakaz-1': 'in_progress'});
      expect(
        seenRequests,
        contains(
          'BODY POST /v1/mobile/admin/production-maps/queue-action '
          '{"apparatus":"Pechat","order_id":"zakaz-1","action":"start",'
          '"material_barcode":"RM-001"}',
        ),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });

  test('raw material rule and assignment endpoints use backend contract',
      () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.rule.manage', 'raw_material.assign'],
    );

    await HttpOverrides.runZoned(() async {
      final rule = await MobileApi.instance.adminSaveRawMaterialRule(
        apparatus: 'Pechat',
        itemGroups: const ['Kraska'],
      );
      final assignment = await MobileApi.instance.adminAssignRawMaterialToOrder(
        orderId: 'zakaz-1',
        barcode: 'RM-001',
        itemCode: 'KR-1',
        itemName: 'Qora kraska',
        itemGroup: 'Kraska',
      );

      expect(rule.apparatus, 'Pechat');
      expect(rule.itemGroups, ['Kraska']);
      expect(assignment.orderId, 'zakaz-1');
      expect(assignment.barcode, 'RM-001');
      expect(
        seenRequests,
        contains(
          'BODY PUT /v1/mobile/admin/raw-material-rules '
          '{"apparatus":"Pechat","item_groups":["Kraska"]}',
        ),
      );
      expect(
        seenRequests,
        contains(
          'BODY POST /v1/mobile/admin/raw-material-assignments '
          '{"order_id":"zakaz-1","barcode":"RM-001","item_code":"KR-1",'
          '"item_name":"Qora kraska","item_group":"Kraska"}',
        ),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });
}

class _RawMaterialApiHttpClient implements HttpClient {
  _RawMaterialApiHttpClient(this.seenRequests);

  final List<String> seenRequests;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final key =
        '$method ${url.path}${url.query.isEmpty ? '' : '?${url.query}'}';
    seenRequests.add(key);

    Object body;
    switch (key) {
      case 'POST /v1/mobile/admin/production-maps/queue-action':
        body = const {
          'states': {'zakaz-1': 'in_progress'},
        };
      case 'PUT /v1/mobile/admin/raw-material-rules':
        body = const {
          'apparatus': 'Pechat',
          'item_groups': ['Kraska'],
        };
      case 'POST /v1/mobile/admin/raw-material-assignments':
        body = const {
          'order_id': 'zakaz-1',
          'apparatus': 'Pechat',
          'barcode': 'RM-001',
          'item_code': 'KR-1',
          'item_name': 'Qora kraska',
          'item_group': 'Kraska',
          'assigned_by_ref': 'admin',
          'assigned_by_name': 'Admin',
          'assigned_at': '2026-06-16T10:00:00Z',
        };
      default:
        body = {'error': 'Unhandled request: $key'};
        return _FakeHttpClientRequest(
          response: _FakeHttpClientResponse(
            body: jsonEncode(body),
            statusCode: HttpStatus.notFound,
            requestKey: key,
            seenRequests: seenRequests,
          ),
        );
    }

    return _FakeHttpClientRequest(
      response: _FakeHttpClientResponse(
        body: jsonEncode(body),
        statusCode: HttpStatus.ok,
        requestKey: key,
        seenRequests: seenRequests,
      ),
    );
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  void close({bool force = false}) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest({required this.response});

  final _FakeHttpClientResponse response;
  final BytesBuilder _body = BytesBuilder();

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
  void write(Object? object) {
    if (object != null) {
      _body.add(utf8.encode(object.toString()));
    }
  }

  @override
  void add(List<int> data) {
    _body.add(data);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      _body.add(data);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    final body = utf8.decode(_body.takeBytes());
    if (body.isNotEmpty) {
      response.seenRequests.add('BODY ${response.requestKey} $body');
    }
    return response;
  }

  final _headers = _FakeHttpHeaders();

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
    required this.requestKey,
    required this.seenRequests,
  });

  final String body;
  final String requestKey;
  final List<String> seenRequests;

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
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => '';

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => const <Cookie>[];

  @override
  Future<Socket> detachSocket() => throw UnsupportedError('detachSocket');

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) =>
      Future<HttpClientResponse>.value(this);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _values = {};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _values.putIfAbsent(name, () => <String>[]).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name] = [value.toString()];
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }
}
