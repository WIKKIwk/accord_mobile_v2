import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/network/api_transport_policy.dart';
import 'package:accord_mobile_v2/src/core/session/accounts/saved_account_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await ServerEndpointStore.instance.load();
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

  test('rejects cleartext public and LAN API origins', () async {
    for (final endpoint in [
      'http://erp.example.com',
      'http://192.168.1.10:8081',
      'http://10.0.0.1:8081',
      'http://localhost.evil.example',
    ]) {
      expect(ServerEndpointStore.normalize(endpoint), isNull);
      await expectLater(ServerEndpointStore.instance.setBaseUrl(endpoint),
          throwsFormatException);
    }
  });

  test('release transport rejects HTTP even on loopback', () {
    for (final endpoint in [
      'http://127.0.0.1:8081',
      'http://localhost:8081',
      'http://[::1]:8081',
    ]) {
      expect(allowsApiTransport(Uri.parse(endpoint), allowDebugLoopback: false),
          isFalse);
    }
    expect(
        allowsApiTransport(Uri.parse('https://erp.example.com'),
            allowDebugLoopback: false),
        isTrue);
  });

  test('saved accounts cannot restore a cleartext remote API origin', () {
    expect(() => SavedAccount.normalizeBaseUrl('http://erp.example.com'),
        throwsFormatException);
    expect(SavedAccount.normalizeBaseUrl('https://erp.example.com/'),
        'https://erp.example.com');
  });

  test('drops previously saved cleartext origins before restoring a session',
      () async {
    SharedPreferences.setMockInitialValues({
      'active_server_endpoint': 'http://erp.example.com',
      'saved_server_endpoints_v1': jsonEncode([
        {
          'base_url': 'http://erp.example.com',
          'last_used_at': '2026-10-24T00:00:00Z'
        },
        {
          'base_url': 'https://safe.example.com',
          'last_used_at': '2026-10-24T00:00:00Z'
        },
      ]),
    });
    final store = ServerEndpointStore.instance;
    await store.load();
    expect(store.baseUrl, ServerEndpointStore.compiledBaseUrl);
    expect(store.savedEndpoints.map((entry) => entry.baseUrl),
        isNot(contains('http://erp.example.com')));
    expect(store.savedEndpoints.map((entry) => entry.baseUrl),
        contains('https://safe.example.com'));
  });

  test('persists multiple saved endpoints for quick switching', () async {
    final store = ServerEndpointStore.instance;

    await store.saveEndpoint('erp-one.example.com');
    await store.saveEndpoint('https://erp-two.example.com/');

    expect(
      store.savedEndpoints.map((endpoint) => endpoint.baseUrl),
      containsAll(<String>[
        'https://erp-one.example.com',
        'https://erp-two.example.com',
        ServerEndpointStore.compiledBaseUrl,
      ]),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('saved_server_endpoints_v1'),
      allOf(
        contains('https://erp-one.example.com'),
        contains('https://erp-two.example.com'),
      ),
    );

    await store.load();
    expect(
      store.savedEndpoints.map((endpoint) => endpoint.baseUrl),
      containsAll(<String>[
        'https://erp-one.example.com',
        'https://erp-two.example.com',
      ]),
    );
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
