import 'dart:convert';
import 'dart:io';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixtureHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Opt in with a disposable Axum/PostgreSQL fixture, never the saved server.
  final fixturePath = Platform.environment['ACCORD_REWORK_E2E_FIXTURE'];

  test('generated IDs complete the native API and PostgreSQL rework lifecycle',
      () async {
    final fixture = jsonDecode(await File(fixturePath!).readAsString())
        as Map<String, dynamic>;
    final baseUrl = fixture['base_url'] as String;
    final endpoint = Uri.parse(baseUrl);
    expect(fixture['isolated'], isTrue);
    expect(endpoint.scheme, 'http');
    expect(endpoint.host, isIn(['127.0.0.1', 'localhost', '::1']));
    final codes = (fixture['qolip_codes'] as List).cast<String>();
    expect(codes.toSet(), hasLength(2));

    SharedPreferences.setMockInitialValues({});
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(false);
    await ServerEndpointStore.instance.setBaseUrl(baseUrl);
    AppSession.instance.token = fixture['token'] as String;
    AppSession.instance.profile = SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Rework fixture',
      legalName: '',
      ref: fixture['principal_ref'] as String,
      phone: '',
      avatarUrl: '',
      capabilities: const ['qolip.manage'],
    );
    AppSession.instance.revision.value++;

    addTearDown(() async {
      AppSession.instance.token = null;
      AppSession.instance.profile = null;
      resetMobileApiTestModeData();
      await ServerEndpointStore.instance.clearOverride();
    });

    await HttpOverrides.runWithHttpOverrides(() async {
      final client = IOClient(HttpClient());
      try {
        await http.runWithClient(() async {
          final api = MobileApi.instance;
          expect(await api.qolipReworks(), isEmpty);
          expect(
              (await api.qolipMileage(codes.first)).trackingEnabled, isFalse);

          final sendId = newQolipReworkRequestId();
          final sent = await api.qolipSendToRework(
            requestId: sendId,
            qolipCodes: [
              ' ${codes.first.toUpperCase()} ',
              codes.last,
              codes.first.toLowerCase(),
            ],
          );
          expect(sent, hasLength(2));
          expect(sent.every((entry) => entry.isOpen), isTrue);
          final replay =
              await api.qolipSendToRework(requestId: sendId, qolipCodes: codes);
          expect(replay.map((entry) => entry.id),
              orderedEquals(sent.map((entry) => entry.id)));
          await expectLater(
            api.qolipSendToRework(requestId: sendId, qolipCodes: [codes.first]),
            throwsA(isA<MobileApiException>().having((error) => error.code,
                'code', 'qolip_rework_request_conflict')),
          );
          expect(await api.qolipReworks(), hasLength(2));

          final first = sent.singleWhere((entry) =>
              entry.qolipCode.toLowerCase() == codes.first.toLowerCase());
          final second = sent.singleWhere((entry) => entry.id != first.id);
          final returnId = newQolipReworkRequestId();
          final returned = await api.qolipReturnFromRework(
              requestId: returnId, reworkIds: [first.id]);
          expect(returned.single.isOpen, isFalse);
          final returnReplay = await api.qolipReturnFromRework(
              requestId: returnId, reworkIds: [first.id]);
          expect(returnReplay.single.returnedAt, returned.single.returnedAt);
          expect((await api.qolipReworks()).single.id, second.id);
          final mileage = await api.qolipMileage(codes.first);
          expect(mileage.trackingEnabled, isTrue);
          expect(mileage.currentMeter, 0);
          expect(mileage.cycles, hasLength(1));
          expect((await api.qolipMileage(codes.last)).trackingEnabled, isFalse);

          await api.qolipReturnFromRework(
              requestId: newQolipReworkRequestId(), reworkIds: [second.id]);
          expect(await api.qolipReworks(), isEmpty);
          expect(await api.qolipReworks(status: 'returned'), hasLength(2));

          final nextVisit = await api.qolipSendToRework(
              requestId: newQolipReworkRequestId(), qolipCodes: [codes.first]);
          expect(nextVisit.single.id, isNot(first.id));
          await expectLater(
            api.qolipReturnFromRework(
                requestId: newQolipReworkRequestId(), reworkIds: [first.id]),
            throwsA(isA<MobileApiException>().having(
                (error) => error.code, 'code', 'qolip_rework_conflict')),
          );
          await api.qolipReturnFromRework(
              requestId: newQolipReworkRequestId(),
              reworkIds: [nextVisit.single.id]);
          expect(await api.qolipReworks(), isEmpty);
          expect((await api.qolipMileage(codes.first)).cycles, hasLength(2));
        }, () => client);
      } finally {
        client.close();
      }
    }, _FixtureHttpOverrides());
  },
      skip: fixturePath == null
          ? 'requires isolated HTTP/PostgreSQL fixture'
          : false);
}
