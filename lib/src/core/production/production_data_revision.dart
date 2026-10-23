import 'package:flutter/foundation.dart';

import '../session/session_read_scope.dart';

/// Accepted production WebSocket revisions, including revisions with no row patch.
/// Detail reads subscribe here instead of periodically requesting unchanged data.
abstract final class ProductionDataRevision {
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static String? _scope;
  static String _epoch = '';
  static int? _serverRevision;

  static bool get isCurrentScope => _scope == currentSessionReadScope();

  static void notify({required String epoch, required int revision}) {
    final scope = currentSessionReadScope();
    if (_scope == scope &&
        _epoch == epoch &&
        _serverRevision != null &&
        revision <= _serverRevision!) {
      return;
    }
    _scope = scope;
    _epoch = epoch;
    _serverRevision = revision;
    ProductionDataRevision.revision.value++;
  }
}
