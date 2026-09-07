import 'package:flutter/foundation.dart';

import '../../../core/api/mobile_api.dart';
import '../../shared/models/app_models.dart';
import 'factory_map_mapping.dart';

typedef FactoryMapPlacementWriter = Future<AdminApparatus> Function(
  AdminApparatus apparatus,
  String objectId,
);

/// Owns mapping snapshots and revision-checked placement mutations. Both map
/// and apparatus settings use this path; production/queue fields are untouched.
class FactoryMapBindings extends ChangeNotifier {
  FactoryMapBindings({
    Future<List<AdminApparatus>> Function()? load,
    Future<AdminApparatus> Function(String id)? read,
    FactoryMapPlacementWriter? write,
  })  : _load = load ?? (() => MobileApi.instance.adminApparatus(limit: 500)),
        _read = read ?? MobileApi.instance.adminCanonicalApparatus,
        _write = write ??
            ((apparatus, objectId) =>
                MobileApi.instance.adminPatchCanonicalApparatus(
                  apparatus: apparatus,
                  patch: {
                    'placement': objectId.isEmpty
                        ? null
                        : {'factory_map_object_id': objectId}
                  },
                ));

  final Future<List<AdminApparatus>> Function() _load;
  final Future<AdminApparatus> Function(String id) _read;
  final FactoryMapPlacementWriter _write;
  List<AdminApparatus> apparatus = const [];
  bool loading = false;
  bool saving = false;
  bool ready = false;
  Object? error;
  int _generation = 0;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  Future<void> refresh() async {
    if (saving || _disposed) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    _notify();
    try {
      final rows = await _load();
      if (_disposed || generation != _generation) return;
      apparatus = List.unmodifiable(rows);
      ready = true;
    } catch (failure) {
      if (_disposed || generation != _generation) return;
      error = failure;
      ready = false;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  void _replace(AdminApparatus saved) {
    apparatus = List.unmodifiable([
      for (final item in apparatus)
        if (item.id != saved.id) item,
      saved,
    ]);
  }

  Future<AdminApparatus> _fresh(String id) async {
    try {
      final rows = await _load();
      final current = await _read(id);
      if (current.id != id) throw const FactoryMapBindingFailure('save_failed');
      apparatus = List.unmodifiable(rows);
      _replace(current);
      ready = true;
      error = null;
      return current;
    } catch (failure) {
      ready = false;
      error = failure;
      rethrow;
    }
  }

  /// Never overwrite a placement changed since the user opened the card.
  /// Only unrelated revision conflicts may be retried, once. After an uncertain
  /// write we read back the authoritative state, never blindly repeat the write.
  Future<AdminApparatus> save(AdminApparatus observed, String objectId) async {
    if (saving || _disposed) throw const FactoryMapBindingFailure('busy');
    saving = true;
    loading = false;
    ++_generation; // In-flight GETs must not overwrite the committed snapshot.
    _notify();
    final target = canonicalFactoryMapObjectId(objectId);
    final previous = canonicalFactoryMapObjectId(observed.factoryMapObjectId);
    try {
      var current = await _fresh(observed.id);
      for (var attempt = 0; attempt < 2; attempt++) {
        final placement =
            canonicalFactoryMapObjectId(current.factoryMapObjectId);
        if (target.isNotEmpty && !current.isActive) {
          throw const FactoryMapBindingFailure('retired');
        }
        if (placement == target) return current;
        if (placement != previous) {
          throw const FactoryMapBindingFailure('changed');
        }
        if (target.isNotEmpty &&
            apparatus.any((item) =>
                item.id != current.id &&
                canonicalFactoryMapObjectId(item.factoryMapObjectId) ==
                    target)) {
          throw const FactoryMapBindingFailure('duplicate');
        }
        try {
          final saved = await _write(current, target);
          if (saved.id != current.id ||
              canonicalFactoryMapObjectId(saved.factoryMapObjectId) != target) {
            throw const FactoryMapBindingFailure('not_applied');
          }
          _replace(saved);
          return saved;
        } catch (failure) {
          try {
            current = await _fresh(observed.id);
          } catch (readFailure) {
            ready = false;
            error = readFailure;
            throw const FactoryMapBindingFailure('uncertain');
          }
          if (canonicalFactoryMapObjectId(current.factoryMapObjectId) ==
              target) {
            return current;
          }
          if (failure is MobileApiException &&
              failure.code == 'apparatus_revision_conflict' &&
              attempt == 0) {
            continue;
          }
          if (target.isNotEmpty &&
              apparatus.any((item) =>
                  item.id != current.id &&
                  canonicalFactoryMapObjectId(item.factoryMapObjectId) ==
                      target)) {
            throw const FactoryMapBindingFailure('duplicate');
          }
          rethrow;
        }
      }
      throw const FactoryMapBindingFailure('changed');
    } finally {
      saving = false;
      _notify();
    }
  }
}

class FactoryMapBindingFailure implements Exception {
  const FactoryMapBindingFailure(this.reason);
  final String reason;
}
