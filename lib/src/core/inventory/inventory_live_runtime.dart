import 'package:flutter/widgets.dart';

import '../session/state/app_session.dart';
import 'inventory_view_store.dart';

/// Keeps visited inventory windows current while their route is closed.
/// Backgrounding suspends streams; resuming verifies each cached version.
class InventoryLiveRuntime extends StatefulWidget {
  const InventoryLiveRuntime({super.key, required this.child});

  final Widget child;

  @override
  State<InventoryLiveRuntime> createState() => _InventoryLiveRuntimeState();
}

class _InventoryLiveRuntimeState extends State<InventoryLiveRuntime>
    with WidgetsBindingObserver {
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    AppSession.instance.revision.addListener(_synchronize);
    _synchronize();
  }

  void _synchronize() {
    final session = AppSession.instance;
    if (session.isLoggedIn && session.can('inventory.movement.manage')) {
      InventoryViewStore.instance.configure(foreground: _foreground);
    } else {
      InventoryViewStore.instance.reset();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
    InventoryViewStore.instance.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
