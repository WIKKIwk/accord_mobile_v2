import 'dart:typed_data';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_cache.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_disk_store_base.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryDisk implements OrderImageDiskStore {
  int reads = 0;
  @override
  Future<Uint8List?> read(String key) async {
    reads++;
    return null;
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {}
  @override
  Future<void> remove(String key) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('memory peek reuses fresh bytes without disk or freshness renewal',
      () async {
    var now = DateTime.utc(2026, 10, 23);
    final disk = _MemoryDisk();
    final cache = OrderImageCache(disk: disk, now: () => now);
    final bytes = await cache.load(
        key: 'account/session/image/thumb',
        thumbnail: true,
        immutable: false,
        fetch: (_) async => http.Response.bytes([1, 2, 3], 200));
    final reads = disk.reads;
    expect(
        identical(
            cache.peek(key: 'account/session/image/thumb', immutable: false),
            bytes),
        isTrue);
    expect(cache.peek(key: 'unknown', immutable: false), isNull);
    expect(disk.reads, reads, reason: 'A peek never starts a disk read');
    now = now.add(const Duration(seconds: 20));
    expect(cache.peek(key: 'account/session/image/thumb', immutable: false),
        bytes);
    now = now.add(const Duration(seconds: 11));
    expect(cache.peek(key: 'account/session/image/thumb', immutable: false),
        isNull);
    expect(disk.reads, reads);
  });

  test('immutable peek obeys exact TTL, clock rollback, scope and clear',
      () async {
    final savedAt = DateTime.utc(2026, 10, 23);
    var now = savedAt;
    final cache = OrderImageCache(disk: _MemoryDisk(), now: () => now);
    final bytes = await cache.load(
        key: 'versioned-image',
        thumbnail: true,
        immutable: true,
        fetch: (_) async => http.Response.bytes([4, 5, 6], 200));
    expect(
        cache.peek(
            key: 'versioned-image', immutable: true, isCurrent: () => false),
        isNull);
    now = savedAt.subtract(const Duration(milliseconds: 1));
    expect(cache.peek(key: 'versioned-image', immutable: true), isNull);
    now = savedAt.add(const Duration(hours: 23));
    expect(
        identical(cache.peek(key: 'versioned-image', immutable: true), bytes),
        isTrue);
    now = savedAt.add(const Duration(days: 1));
    expect(cache.peek(key: 'versioned-image', immutable: true), isNull);
    now = savedAt;
    await cache.clear();
    expect(cache.peek(key: 'versioned-image', immutable: true), isNull);
  });

  test(
      'API peek shares cache key but isolates variant version account and session',
      () async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    OrderImageCache.debugOverride = OrderImageCache(disk: _MemoryDisk());
    AppSession.instance.token = 'peek-session';
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.admin,
        displayName: 'Admin',
        legalName: '',
        ref: 'peek-admin',
        phone: '',
        avatarUrl: '');
    addTearDown(() async {
      await OrderImageCache.instance.clear();
      OrderImageCache.debugOverride = null;
      AppSession.instance.token = null;
      AppSession.instance.profile = null;
    });
    final api = MobileApi.instance;
    final url = api.adminProductionMapOrderImageUrl('order-1', imageId: 'v1');
    var requests = 0;
    await http.runWithClient(() async {
      final bytes = await api.cachedOrderImageBytes(url, thumbnail: true);
      expect(
          identical(api.peekCachedOrderImageBytes(url, thumbnail: true), bytes),
          isTrue);
      expect(api.peekCachedOrderImageBytes(url), isNull,
          reason: 'A thumbnail is not full-image authority');
      expect(
          api.peekCachedOrderImageBytes(
              api.adminProductionMapOrderImageUrl('order-1', imageId: 'v2'),
              thumbnail: true),
          isNull);
      final second = await api.cachedOrderImageBytes(url, thumbnail: true);
      expect(identical(second, bytes), isTrue);
      expect(requests, 1,
          reason: 'A fresh preview/detail reuse must not download twice');
      AppSession.instance.token = 'different-session';
      expect(api.peekCachedOrderImageBytes(url, thumbnail: true), isNull);
      AppSession.instance.token = 'peek-session';
      AppSession.instance.profile = const SessionProfile(
          role: UserRole.admin,
          displayName: 'Other',
          legalName: '',
          ref: 'different-admin',
          phone: '',
          avatarUrl: '');
      expect(api.peekCachedOrderImageBytes(url, thumbnail: true), isNull);
      AppSession.instance.profile = const SessionProfile(
          role: UserRole.admin,
          displayName: 'Admin',
          legalName: '',
          ref: 'peek-admin',
          phone: '',
          avatarUrl: '');
      AppSession.instance.token = null;
      expect(api.peekCachedOrderImageBytes(url, thumbnail: true), isNull);
    },
        () => MockClient((request) async {
              requests++;
              expect(request.url.queryParameters['variant'], 'thumb-v1');
              return http.Response.bytes([7, 8, 9], 200);
            }));
  });
}
