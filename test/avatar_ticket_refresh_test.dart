import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/chat/models/chat_models.dart';
import 'package:accord_mobile_v2/src/features/shared/data/profile_avatar_cache.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/shared/presentation/widgets/refreshing_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const old = 'https://images.example/view?ticket=old&v=5';
  const renewed = 'https://images.example/view?ticket=new&v=5';
  const profile = SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'self',
      phone: '',
      avatarUrl: old);
  final session = AppSession.instance;
  setUp(() {
    session.token = 'session';
    session.profile = profile;
  });
  tearDown(() async {
    session.token = null;
    session.profile = null;
    await ProfileAvatarCache.clearAll();
  });

  for (final failsAgain in [false, true]) {
    test(
        'own avatar obtains the API URL and retries once (second failure = $failsAgain)',
        () async {
      final seen = <String>[];
      await http.runWithClient(() async {
        final result = await ProfileAvatarCache.ensureCached(profile);
        expect(result, failsAgain ? isNull : equals([1, 2, 3]));
      },
          () => MockClient((request) async {
                seen.add(request.url.path == '/v1/mobile/profile'
                    ? 'profile'
                    : request.url.toString());
                if (request.url.path == '/v1/mobile/profile') {
                  expect(request.headers['authorization'], 'Bearer session');
                  return http.Response(
                      jsonEncode({...profile.toJson(), 'avatar_url': renewed}),
                      200);
                }
                expect(request.headers['authorization'], isNull);
                return request.url.toString() == renewed && !failsAgain
                    ? http.Response.bytes([1, 2, 3], 200)
                    : http.Response('', 401);
              }));
      expect(seen, [old, 'profile', renewed]);
    });
  }

  testWidgets(
      'thumbnail and preview receive only one replacement image per failed URL',
      (tester) async {
    var refreshes = 0;
    final urls = <String>[];
    late VoidCallback reportFailure;
    await tester.pumpWidget(RefreshingAvatar(
        url: old,
        refreshUrl: () async {
          refreshes++;
          return renewed;
        },
        builder: (image, onError) {
          urls.add((image as NetworkImage).url);
          reportFailure = onError;
          return const SizedBox();
        }));
    expect(urls, [old]);
    reportFailure();
    reportFailure();
    await tester.pumpAndSettle();
    expect(urls.last, renewed);
    reportFailure();
    await tester.pumpAndSettle();
    expect(refreshes, 1);
  });

  test(
      'chat refresh matches the peer by role and ref across conversation pages',
      () async {
    const peer = ChatPrincipal(
        principalId: 'worker:one',
        role: UserRole.aparatchi,
        ref: 'one',
        displayName: 'Operator',
        avatarUrl: old);
    final offsets = <String?>[];
    final urls = await http.runWithClient(
        () => Future.wait([
              MobileApi.instance.chatPeerAvatarUrl(peer),
              MobileApi.instance.chatPeerAvatarUrl(peer)
            ]),
        () => MockClient((request) async {
              expect(request.url.path, '/v1/mobile/chat/conversations');
              expect(request.headers['authorization'], 'Bearer session');
              offsets.add(request.url.queryParameters['offset']);
              final first = offsets.length == 1;
              return http.Response(
                  jsonEncode({
                    'items': [
                      {
                        'peer': {
                          ...peer.toJson(),
                          'role': first ? 'supplier' : 'aparatchi',
                          'avatar_url': first ? 'wrong' : renewed
                        }
                      }
                    ],
                    'has_more': first
                  }),
                  200);
            }));
    expect(urls, [renewed, renewed]);
    expect(offsets, [null, '1']);
  });
}
