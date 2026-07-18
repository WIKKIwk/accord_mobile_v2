import 'package:accord_mobile_v2/src/features/shared/data/profile_avatar_cache.dart';
import 'package:accord_mobile_v2/src/features/shared/data/profile_cover_cache.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  const profile = SessionProfile(
    role: UserRole.admin,
    displayName: 'Admin',
    legalName: '',
    ref: 'session-image-cache-test',
    phone: '',
    avatarUrl: 'https://example.com/avatar.png',
  );

  tearDown(() async {
    await ProfileAvatarCache.clearAll();
    await ProfileCoverCache.clearAll();
  });

  test('profile images stay in memory and clear with the session', () async {
    final avatarBytes = [1, 2, 3];
    final coverBytes = [4, 5, 6];

    await ProfileAvatarCache.cacheFromBytes(profile, avatarBytes, 'avatar');
    await ProfileCoverCache.cacheFromBytes(profile, coverBytes);

    expect(await ProfileAvatarCache.getCached(profile), avatarBytes);
    expect(await ProfileCoverCache.getCached(profile), coverBytes);

    await ProfileAvatarCache.clearAll();
    await ProfileCoverCache.clearAll();

    expect(await ProfileAvatarCache.getCached(profile), isNull);
    expect(await ProfileCoverCache.getCached(profile), isNull);
  });

  test('refresh bypasses the in-memory avatar value', () async {
    final client = _FakeImageClient([7, 8, 9]);
    ProfileAvatarCache.debugHttpClient = client;
    addTearDown(() => ProfileAvatarCache.debugHttpClient = null);

    await ProfileAvatarCache.cacheFromBytes(profile, [1, 2, 3], 'avatar');
    final refreshed = await ProfileAvatarCache.refreshFromUrl(profile);

    expect(refreshed, [7, 8, 9]);
    expect(client.requests, 1);
  });

  test('ensureCached shares an in-flight avatar download', () async {
    final client = _FakeImageClient([7, 8, 9]);
    ProfileAvatarCache.debugHttpClient = client;
    addTearDown(() => ProfileAvatarCache.debugHttpClient = null);

    final results = await Future.wait([
      ProfileAvatarCache.ensureCached(profile),
      ProfileAvatarCache.ensureCached(profile),
    ]);

    expect(results[0], [7, 8, 9]);
    expect(results[1], [7, 8, 9]);
    expect(client.requests, 1);
  });
}

class _FakeImageClient extends Object implements http.Client {
  _FakeImageClient(this.bytes);

  final List<int> bytes;
  int requests = 0;

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    requests++;
    return http.Response.bytes(bytes, 200);
  }

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
