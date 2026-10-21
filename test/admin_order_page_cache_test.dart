import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_order_page_cache.dart';
import 'package:flutter_test/flutter_test.dart';

AdminOrderPageCacheWindow _window(String view, {int pages = 1}) =>
    AdminOrderPageCacheWindow(
      AdminProductionOrderPageRequest(view: view),
      List.generate(
          pages,
          (index) => AdminProductionOrderPage(
                version: 'v1',
                epoch: 'server',
                revision: 1,
                offset: index * 20,
                total: pages * 20,
                orderIds: List.generate(20, (row) => '$view-$index-$row'),
                nextCursor: index + 1 < pages ? '${(index + 1) * 20}' : null,
              )),
    );

void _save(AdminOrderPageCache cache, AdminOrderPageCacheVisit visit,
    {Iterable<AdminOrderPageCacheWindow>? windows}) {
  cache.save(
      visit: visit,
      apparatus: const [],
      selectedApparatusId: 'apparatus',
      windows: windows ?? [_window('sequence')]);
}

void main() {
  test('admin page cache preserves server pages within one session', () {
    final cache = AdminOrderPageCache();
    final window = _window('sequence', pages: 2);
    _save(cache, cache.open('account'), windows: [window]);
    final restored = cache.open('account').snapshot!;
    expect(restored.windows.single.pages, hasLength(2));
    expect(identical(restored.windows.single.pages.first, window.pages.first),
        isTrue);
    expect(restored.selectedApparatusId, 'apparatus');
    expect(() => restored.windows.clear(), throwsUnsupportedError);
    expect(() => restored.windows.single.pages.clear(), throwsUnsupportedError);
  });

  test('admin page cache expires without extending age on repeated reads', () {
    var now = DateTime.utc(2026, 10, 21);
    final cache = AdminOrderPageCache(now: () => now);
    _save(cache, cache.open('account'));
    now = now.add(const Duration(minutes: 4));
    expect(cache.open('account').snapshot, isNotNull);
    now = now.add(const Duration(minutes: 1));
    expect(cache.open('account').snapshot, isNull);
  });

  test('admin page cache rejects clock rollback', () {
    var now = DateTime.utc(2026, 10, 21);
    final cache = AdminOrderPageCache(now: () => now);
    _save(cache, cache.open('account'));
    now = now.subtract(const Duration(seconds: 1));
    expect(cache.open('account').snapshot, isNull);
  });

  test('admin page cache unconfirmed revisits cannot renew an old baseline',
      () {
    var now = DateTime.utc(2026, 10, 21);
    final cache = AdminOrderPageCache(now: () => now);
    _save(cache, cache.open('account'));
    now = now.add(const Duration(minutes: 4));
    final visit = cache.open('account');
    cache.save(
        visit: visit,
        apparatus: const [],
        selectedApparatusId: null,
        windows: visit.snapshot!.windows,
        refreshAge: false);
    now = now.add(const Duration(minutes: 1));
    expect(cache.open('account').snapshot, isNull);
  });

  test(
      'admin page cache clears on scope change and cannot resurrect an old visit',
      () {
    final cache = AdminOrderPageCache();
    final old = cache.open('account-a');
    _save(cache, old);
    final next = cache.open('account-b');
    expect(next.snapshot, isNull);
    _save(cache, old);
    expect(cache.open('account-b').snapshot, isNull);
    expect(cache.open('account-a').snapshot, isNull);
  });

  test(
      'admin page cache clear invalidates pending writes from the same account',
      () {
    final cache = AdminOrderPageCache();
    final old = cache.open('account');
    _save(cache, old);
    cache.clear();
    _save(cache, old);
    expect(cache.open('account').snapshot, isNull);
  });

  test('admin page cache newer visits own the next saved baseline', () {
    final cache = AdminOrderPageCache();
    final old = cache.open('account');
    final current = cache.open('account');
    _save(cache, current, windows: [_window('current')]);
    _save(cache, old, windows: [_window('old')]);
    expect(
        cache.open('account').snapshot!.windows.single.request.view, 'current');
  });

  test('admin page cache old errors cannot invalidate a newer visit', () {
    final cache = AdminOrderPageCache();
    final old = cache.open('account');
    final current = cache.open('account');
    _save(cache, current);
    cache.invalidate(old);
    final next = cache.open('account');
    expect(next.snapshot, isNotNull);
    cache.invalidate(next);
    expect(cache.open('account').snapshot, isNull);
  });

  test('admin page cache bounds total pages and each window prefix', () {
    final cache = AdminOrderPageCache(maxPages: 4, maxPagesPerWindow: 3);
    _save(cache, cache.open('account'), windows: [
      _window('sequence', pages: 8),
      _window('orders', pages: 4),
      _window('closed'),
    ]);
    final windows = cache.open('account').snapshot!.windows;
    expect(windows.map((w) => w.pages.length), [3, 1]);
    expect(windows.first.pages.last.nextCursor, '60');
  });

  test('admin page cache bounds the number of windows', () {
    final cache = AdminOrderPageCache(maxWindows: 2);
    _save(cache, cache.open('account'),
        windows: List.generate(10, (i) => _window('$i')));
    expect(cache.open('account').snapshot!.windows, hasLength(2));
  });

  test('admin page cache rejects mixed or noncontiguous server baselines', () {
    final cache = AdminOrderPageCache();
    final invalid = AdminOrderPageCacheWindow(
      const AdminProductionOrderPageRequest(view: 'sequence'),
      [
        _window('sequence').pages.first,
        const AdminProductionOrderPage(
            version: 'v2', epoch: 'server', revision: 2, offset: 20, total: 40),
      ],
    );
    _save(cache, cache.open('account'), windows: [invalid]);
    expect(cache.open('account').snapshot, isNull);
  });
}
