import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../features/admin/state/admin_sequence_warm_store.dart';
import '../api/mobile_api.dart';
import '../session/session_read_scope.dart';
import '../session/state/app_session.dart';
import 'worker_queue_warm_store.dart';

/// Prepares the active queue before its route is opened. Each store hands its
/// socket to a visible queue page, so background warming never adds a poller.
class ProductionQueueWarmRuntime extends StatefulWidget {
  const ProductionQueueWarmRuntime({super.key, required this.child});

  final Widget child;

  @override
  State<ProductionQueueWarmRuntime> createState() =>
      _ProductionQueueWarmRuntimeState();
}

class _ProductionQueueWarmRuntimeState extends State<ProductionQueueWarmRuntime>
    with WidgetsBindingObserver {
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    AppSession.instance.revision.addListener(_synchronize);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _synchronize();
    });
  }

  void _synchronize() {
    final session = AppSession.instance;
    final profile = session.profile;
    final enabled = session.isLoggedIn && !session.isTestModeSession;
    final admin = enabled &&
        (session.can('admin.access') || session.can('production.map.manage'));
    AdminSequenceWarmStore.instance.configure(
      scope: admin ? currentAdminSequenceWarmScope() : null,
      profileRef: profile?.ref,
      foreground: _foreground,
    );
    if (enabled && !admin && session.can('apparatus.queue.read')) {
      if (_foreground) {
        unawaited(WorkerQueueWarmStore.instance.start(
          scope: currentSessionReadScope(),
          preferenceAccount: jsonEncode([
            MobileApi.baseUrl,
            profile?.role.name,
            profile?.ref,
          ]),
        ));
      } else {
        WorkerQueueWarmStore.instance.pause();
      }
    } else {
      WorkerQueueWarmStore.instance.reset();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // An inactive transition can be a system dialog. Hidden/paused are the
    // points at which sockets must be suspended; resume proves continuity.
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _synchronize();
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _synchronize();
    }
  }

  @override
  void dispose() {
    AppSession.instance.revision.removeListener(_synchronize);
    WidgetsBinding.instance.removeObserver(this);
    AdminSequenceWarmStore.instance.configure(
      scope: null,
      foreground: false,
    );
    WorkerQueueWarmStore.instance.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
