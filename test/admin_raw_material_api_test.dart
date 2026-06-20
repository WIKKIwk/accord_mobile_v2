import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  tearDown(() async {
    await TestModeController.instance.setEnabled(false);
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

  test('queue action explains incompatible raw material scan', () async {
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
      await expectLater(
        MobileApi.instance.adminApparatusQueueAction(
          apparatus: 'Pechat',
          orderId: 'zakaz-1',
          action: 'start',
          materialBarcode: 'OTHER-RM',
        ),
        throwsA(
          isA<MobileApiException>().having(
            (error) => error.message,
            'message',
            'Bu homashyo ish boshlash uchun mos emas',
          ),
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              queueActionErrorCode: 'raw_material_group_not_allowed',
            ));
  });

  test('queue progress action sends qty and reads progress batch', () async {
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
      final result = await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: 'Pechat',
        orderId: 'zakaz-1',
        action: 'pause',
        producedQty: 12.5,
        grossQty: 17,
        uom: 'm',
        driverUrl: ' http://127.0.0.1:39117/ ',
      );
      final batch = await MobileApi.instance.adminProgressQrLookup(
        'GSP:PROGRESS-1',
      );

      expect(result.states, {'zakaz-1': 'paused'});
      expect(result.progressBatch?.qrPayload, 'GSP:PROGRESS-1');
      expect(batch.status, 'paused');
      expect(
        seenRequests,
        contains(
          'BODY POST /v1/mobile/admin/production-maps/queue-action '
          '{"apparatus":"Pechat","order_id":"zakaz-1","action":"pause",'
          '"produced_qty":12.5,"gross_qty":17.0,"uom":"m",'
          '"driver_url":"http://127.0.0.1:39117"}',
        ),
      );
      expect(
        seenRequests,
        contains(
          'BODY POST /v1/mobile/admin/production-maps/progress-qr/lookup '
          '{"qr_payload":"GSP:PROGRESS-1"}',
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              queueActionProgress: true,
            ));
  });

  test('closed production orders endpoint parses full action logs', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['production_map.manage'],
    );

    await HttpOverrides.runZoned(() async {
      final orders = await MobileApi.instance.adminClosedProductionMapOrders();

      expect(orders, hasLength(1));
      expect(orders.first.orderId, 'zakaz-closed-route');
      expect(orders.first.orderNumber, '9401');
      expect(orders.first.closedByRef, 'worker-closed-lamin');
      expect(orders.first.logs, hasLength(2));
      expect(orders.first.logs.first.action, 'start');
      expect(orders.first.logs.last.apparatus, 'Laminatsiya 1');
      expect(
        seenRequests,
        contains('GET /v1/mobile/admin/production-maps/closed-orders'),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });

  test('test mode queue resume does not require progress qr', () async {
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Aparatchi',
      legalName: '',
      ref: 'ap-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.manage'],
    );
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: 'Pechat resume',
      orderIds: const ['zakaz-resume-1'],
    );

    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: 'Pechat resume',
      orderId: 'zakaz-resume-1',
      action: 'start',
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: 'Pechat resume',
      orderId: 'zakaz-resume-1',
      action: 'pause',
      producedQty: 3,
      uom: 'kg',
    );
    final resumed = await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: 'Pechat resume',
      orderId: 'zakaz-resume-1',
      action: 'resume',
    );

    expect(resumed.states, {'zakaz-resume-1': 'in_progress'});
    expect(resumed.progressBatch, isNull);
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
        requiresMaterial: true,
        itemGroups: const ['Kraska'],
      );
      final assignment = await MobileApi.instance.adminAssignRawMaterialToOrder(
        orderId: 'zakaz-1',
        barcode: 'RM-001',
      );

      expect(rule.apparatus, 'Pechat');
      expect(rule.requiresMaterial, isTrue);
      expect(rule.itemGroups, ['Kraska']);
      expect(assignment.orderId, 'zakaz-1');
      expect(assignment.barcode, 'RM-001');
      expect(assignment.stockStatus, 'in_use');
      expect(assignment.reservedOrderId, 'zakaz-1');
      expect(assignment.stockWarehouse, 'Kalidor');
      expect(
        seenRequests,
        contains(
          'BODY PUT /v1/mobile/admin/raw-material-rules '
          '{"apparatus":"Pechat","requires_material":true,"item_groups":["Kraska"]}',
        ),
      );
      expect(
        seenRequests,
        contains(
          'BODY POST /v1/mobile/admin/raw-material-assignments '
          '{"order_id":"zakaz-1","barcode":"RM-001"}',
        ),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });

  test('raw material assignment explains occupied barcode', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.assign'],
    );

    await HttpOverrides.runZoned(() async {
      await expectLater(
        MobileApi.instance.adminAssignRawMaterialToOrder(
          orderId: 'zakaz-2',
          barcode: 'RM-001',
        ),
        throwsA(
          isA<MobileApiException>().having(
            (error) => error.message,
            'message',
            'Bu homashyo boshqa zakaz uchun band qilingan',
          ),
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              assignmentErrorCode: 'raw_material_already_assigned',
            ));
  });

  test('raw material assignment explains barcode already linked to same order',
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
      capabilities: ['raw_material.assign'],
    );

    await HttpOverrides.runZoned(() async {
      await expectLater(
        MobileApi.instance.adminAssignRawMaterialToOrder(
          orderId: 'zakaz-1',
          barcode: 'RM-001',
        ),
        throwsA(
          isA<MobileApiException>().having(
            (error) => error.message,
            'message',
            'Bu homashyo allaqachon shu zakazga ulangan',
          ),
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              assignmentErrorCode: 'raw_material_already_assigned_to_order',
            ));
  });

  test('raw material assignment unlink uses backend contract', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.assign'],
    );

    await HttpOverrides.runZoned(() async {
      final removed = await MobileApi.instance.adminUnlinkRawMaterialAssignment(
        orderId: 'zakaz-1',
        barcode: 'RM-001',
      );

      expect(removed.orderId, 'zakaz-1');
      expect(removed.barcode, 'RM-001');
      expect(
        seenRequests,
        contains(
          'BODY DELETE /v1/mobile/admin/raw-material-assignments '
          '{"order_id":"zakaz-1","barcode":"RM-001"}',
        ),
      );
    }, createHttpClient: (_) => _RawMaterialApiHttpClient(seenRequests));
  });

  test('raw material assignment unlink explains locked stock', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.assign'],
    );

    await HttpOverrides.runZoned(() async {
      await expectLater(
        MobileApi.instance.adminUnlinkRawMaterialAssignment(
          orderId: 'zakaz-1',
          barcode: 'RM-001',
        ),
        throwsA(
          isA<MobileApiException>().having(
            (error) => error.message,
            'message',
            'Bu homashyo allaqachon ishga tushgan yoki ishlatilgan, uzib bo‘lmaydi',
          ),
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              unlinkErrorCode: 'raw_material_assignment_locked',
            ));
  });

  test('raw material assignment explains rulon size mismatch', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.assign'],
    );

    await HttpOverrides.runZoned(() async {
      await expectLater(
        MobileApi.instance.adminAssignRawMaterialToOrder(
          orderId: 'zakaz-1',
          barcode: 'RM-ROLL',
        ),
        throwsA(
          isA<MobileApiException>().having(
            (error) => error.message,
            'message',
            'Bu rulon bu buyurtma uchun mos emas',
          ),
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              assignmentErrorCode: 'raw_material_roll_size_mismatch',
            ));
  });

  test('raw material assignment explains missing rulon size', () async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.assign'],
    );

    await HttpOverrides.runZoned(() async {
      await expectLater(
        MobileApi.instance.adminAssignRawMaterialToOrder(
          orderId: 'zakaz-1',
          barcode: 'RM-ROLL',
        ),
        throwsA(
          isA<MobileApiException>().having(
            (error) => error.message,
            'message',
            'Rulon razmeri topilmadi',
          ),
        ),
      );
    },
        createHttpClient: (_) => _RawMaterialApiHttpClient(
              seenRequests,
              assignmentErrorCode: 'raw_material_roll_size_missing',
            ));
  });
}

class _RawMaterialApiHttpClient implements HttpClient {
  _RawMaterialApiHttpClient(
    this.seenRequests, {
    this.queueActionErrorCode = '',
    this.assignmentErrorCode = '',
    this.unlinkErrorCode = '',
    this.queueActionProgress = false,
  });

  final List<String> seenRequests;
  final String queueActionErrorCode;
  final String assignmentErrorCode;
  final String unlinkErrorCode;
  final bool queueActionProgress;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final key =
        '$method ${url.path}${url.query.isEmpty ? '' : '?${url.query}'}';
    seenRequests.add(key);

    Object body;
    switch (key) {
      case 'POST /v1/mobile/admin/production-maps/queue-action':
        if (queueActionErrorCode.isNotEmpty) {
          body = {'error': queueActionErrorCode};
          return _FakeHttpClientRequest(
            response: _FakeHttpClientResponse(
              body: jsonEncode(body),
              statusCode: HttpStatus.badRequest,
              requestKey: key,
              seenRequests: seenRequests,
            ),
          );
        }
        body = queueActionProgress
            ? const {
                'states': {'zakaz-1': 'paused'},
                'progress_batch': {
                  'batch_id': 'progress-1',
                  'session_id': 'session-1',
                  'apparatus': 'Pechat',
                  'order_id': 'zakaz-1',
                  'action': 'pause',
                  'status': 'paused',
                  'produced_qty': 12.5,
                  'uom': 'kg',
                  'qr_payload': 'GSP:PROGRESS-1',
                  'label_item_code': 'zakaz-1',
                  'label_item_name': 'Zakaz yarim tayyor',
                  'executor_name': 'Aparatchi',
                },
              }
            : const {
                'states': {'zakaz-1': 'in_progress'},
              };
      case 'POST /v1/mobile/admin/production-maps/progress-qr/lookup':
        body = const {
          'ok': true,
          'can_resume': true,
          'batch': {
            'batch_id': 'progress-1',
            'session_id': 'session-1',
            'apparatus': 'Pechat',
            'order_id': 'zakaz-1',
            'action': 'pause',
            'status': 'paused',
            'produced_qty': 12.5,
            'uom': 'kg',
            'qr_payload': 'GSP:PROGRESS-1',
            'label_item_code': 'zakaz-1',
            'label_item_name': 'Zakaz yarim tayyor',
            'executor_name': 'Aparatchi',
          },
        };
      case 'GET /v1/mobile/admin/production-maps/closed-orders':
        body = const {
          'ok': true,
          'closed_orders': [
            {
              'order_id': 'zakaz-closed-route',
              'order_number': '9401',
              'title': 'Closed route',
              'product_code': 'PECHAT-9401',
              'completed_at_unix': 1781780000,
              'closed_by_role': 'aparatchi',
              'closed_by_ref': 'worker-closed-lamin',
              'closed_by_display_name': 'Laminatsiyachi',
              'logs': [
                {
                  'event_id': 'event-1',
                  'apparatus': '7 ta rangli pechat',
                  'order_id': 'zakaz-closed-route',
                  'action': 'start',
                  'from_state': 'pending',
                  'to_state': 'in_progress',
                  'actor_role': 'aparatchi',
                  'actor_ref': 'worker-closed-pechat',
                  'actor_display_name': 'Pechatchi',
                  'created_at_unix': 1781779900,
                },
                {
                  'event_id': 'event-2',
                  'apparatus': 'Laminatsiya 1',
                  'order_id': 'zakaz-closed-route',
                  'action': 'complete',
                  'from_state': 'in_progress',
                  'to_state': 'completed',
                  'actor_role': 'aparatchi',
                  'actor_ref': 'worker-closed-lamin',
                  'actor_display_name': 'Laminatsiyachi',
                  'created_at_unix': 1781780000,
                },
              ],
            },
          ],
        };
      case 'PUT /v1/mobile/admin/raw-material-rules':
        body = const {
          'apparatus': 'Pechat',
          'requires_material': true,
          'item_groups': ['Kraska'],
        };
      case 'POST /v1/mobile/admin/raw-material-assignments':
        if (assignmentErrorCode.isNotEmpty) {
          body = {'error': assignmentErrorCode};
          return _FakeHttpClientRequest(
            response: _FakeHttpClientResponse(
              body: jsonEncode(body),
              statusCode: HttpStatus.badRequest,
              requestKey: key,
              seenRequests: seenRequests,
            ),
          );
        }
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
          'stock_status': 'in_use',
          'reserved_order_id': 'zakaz-1',
          'stock_warehouse': 'Kalidor',
        };
      case 'DELETE /v1/mobile/admin/raw-material-assignments':
        if (unlinkErrorCode.isNotEmpty) {
          body = {'error': unlinkErrorCode};
          return _FakeHttpClientRequest(
            response: _FakeHttpClientResponse(
              body: jsonEncode(body),
              statusCode: HttpStatus.badRequest,
              requestKey: key,
              seenRequests: seenRequests,
            ),
          );
        }
        body = const {
          'ok': true,
          'assignment': {
            'order_id': 'zakaz-1',
            'apparatus': 'Pechat',
            'barcode': 'RM-001',
            'item_code': 'KR-1',
            'item_name': 'Qora kraska',
            'item_group': 'Kraska',
            'assigned_by_ref': 'admin',
            'assigned_by_name': 'Admin',
            'assigned_at': '2026-06-16T10:00:00Z',
            'stock_status': 'available',
            'reserved_order_id': '',
            'stock_warehouse': 'Kalidor',
          },
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
