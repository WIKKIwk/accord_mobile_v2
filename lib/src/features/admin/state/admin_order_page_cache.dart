import '../../../core/api/mobile_api.dart';
import '../../shared/models/app_models.dart';

class AdminOrderPageCacheWindow {
  AdminOrderPageCacheWindow(
      this.request, Iterable<AdminProductionOrderPage> pages)
      : pages = List.unmodifiable(pages);

  final AdminProductionOrderPageRequest request;
  final List<AdminProductionOrderPage> pages;
}

class AdminOrderPageCacheSnapshot {
  AdminOrderPageCacheSnapshot({
    required Iterable<AdminApparatus> apparatus,
    required this.selectedApparatusId,
    required Iterable<AdminOrderPageCacheWindow> windows,
  })  : apparatus = List.unmodifiable(apparatus),
        windows = List.unmodifiable(windows);

  final List<AdminApparatus> apparatus;
  final String? selectedApparatusId;
  final List<AdminOrderPageCacheWindow> windows;
}

class AdminOrderPageCacheVisit {
  AdminOrderPageCacheVisit._(this._owner, this._serial, this.snapshot);
  final AdminOrderPageCache _owner;
  final int _serial;
  final AdminOrderPageCacheSnapshot? snapshot;
}

/// Only immutable server pages survive navigation; sockets, pending writes,
/// widget state and in-flight futures always belong to the current screen.
class AdminOrderPageCache {
  AdminOrderPageCache({
    this.maxAge = const Duration(minutes: 5),
    this.maxWindows = 12,
    this.maxPages = 20,
    this.maxPagesPerWindow = 5,
    DateTime Function()? now,
  })  : assert(maxWindows > 0 && maxPages > 0 && maxPagesPerWindow > 0),
        _now = now ?? DateTime.now;

  static final instance = AdminOrderPageCache();
  final Duration maxAge;
  final int maxWindows;
  final int maxPages;
  final int maxPagesPerWindow;
  final DateTime Function() _now;
  String? _scope;
  DateTime? _savedAt;
  AdminOrderPageCacheSnapshot? _snapshot;
  int _serial = 0;

  AdminOrderPageCacheVisit open(String scope) {
    final age = _savedAt == null ? null : _now().difference(_savedAt!);
    if (_scope != scope || (age != null && (age.isNegative || age >= maxAge))) {
      clear();
    }
    _scope = scope;
    // A disposed older route cannot overwrite a newer visit or a logout.
    return AdminOrderPageCacheVisit._(this, ++_serial, _snapshot);
  }

  void save({
    required AdminOrderPageCacheVisit visit,
    required Iterable<AdminApparatus> apparatus,
    required String? selectedApparatusId,
    required Iterable<AdminOrderPageCacheWindow> windows,
    bool refreshAge = true,
  }) {
    if (!identical(visit._owner, this) || visit._serial != _serial) return;
    var remaining = maxPages;
    final bounded = <AdminOrderPageCacheWindow>[];
    for (final window in windows) {
      if (bounded.length == maxWindows || remaining == 0) break;
      if (window.pages.isEmpty) continue;
      final pages =
          window.pages.take(maxPagesPerWindow).take(remaining).toList();
      final first = pages.first;
      var offset = 0;
      if (first.version.isEmpty ||
          first.epoch.isEmpty ||
          first.revision == null ||
          pages.any((page) {
            final valid = page.offset == offset &&
                page.version == first.version &&
                page.epoch == first.epoch &&
                page.revision == first.revision;
            offset += page.length;
            return !valid;
          })) {
        continue;
      }
      bounded.add(AdminOrderPageCacheWindow(window.request, pages));
      remaining -= pages.length;
    }
    _snapshot = bounded.isEmpty
        ? null
        : AdminOrderPageCacheSnapshot(
            apparatus: apparatus.take(200),
            selectedApparatusId: selectedApparatusId,
            windows: bounded,
          );
    // Reopening an unconfirmed baseline must not renew its lifetime.
    if (refreshAge || _savedAt == null) _savedAt = _now();
  }

  void clear() {
    _scope = null;
    _savedAt = null;
    _snapshot = null;
    _serial++;
  }

  void invalidate(AdminOrderPageCacheVisit? visit) {
    if (visit != null &&
        identical(visit._owner, this) &&
        visit._serial == _serial) {
      clear();
    }
  }
}
