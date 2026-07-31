import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await ServerEndpointStore.instance.clearOverride();
  });

  tearDown(() async {
    await ServerEndpointStore.instance.clearOverride();
  });

  test('normalizes a domain while rejecting paths and query strings', () {
    expect(
      ServerEndpointStore.normalize(' erp.example.com/ '),
      'https://erp.example.com',
    );
    expect(
      ServerEndpointStore.normalize('http://127.0.0.1:8080/'),
      'http://127.0.0.1:8080',
    );
    expect(
        ServerEndpointStore.normalize('https://erp.example.com/app'), isNull);
    expect(
      ServerEndpointStore.normalize('https://erp.example.com?tenant=demo'),
      isNull,
    );
  });

  test('persists the active endpoint independently from the compiled default',
      () async {
    await ServerEndpointStore.instance.setBaseUrl('https://erp.example.com/');

    expect(ServerEndpointStore.instance.baseUrl, 'https://erp.example.com');
    expect(ServerEndpointStore.instance.isRuntimeOverride, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs.getString('active_server_endpoint'), 'https://erp.example.com');
    expect(MobileApi.baseUrl, 'https://erp.example.com');
  });

  test('parses only the Mini RS ERP handshake contract', () {
    final handshake = MobileServerHandshake.fromJson(const {
      'service': 'mini_rs_erp',
      'product': 'mini_rs_erp',
      'api_contract': 'v1',
      'version': '0.1.0',
    });

    expect(handshake.isMiniRsErp, isTrue);
    expect(handshake.version, '0.1.0');
    expect(
      MobileServerHandshake.fromJson(const {
        'service': 'other-service',
        'product': 'mini_rs_erp',
        'api_contract': 'v1',
      }).isMiniRsErp,
      isFalse,
    );
  });
}
