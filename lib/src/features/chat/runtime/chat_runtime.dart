import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/session/session.dart';
import '../state/chat_store.dart';

class ChatRuntime extends StatefulWidget {
  const ChatRuntime({super.key, required this.child});

  final Widget child;

  @override
  State<ChatRuntime> createState() => _ChatRuntimeState();
}

class _ChatRuntimeState extends State<ChatRuntime> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppSession.instance.revision.addListener(_sessionChanged);
    // ChatStore notifies its listeners while it restores the session. Starting
    // it synchronously here can rebuild the Scaffold bottom dock during the
    // first layout pass and trigger Flutter's RenderLayoutBuilder mutation
    // assertion. Let the initial frame finish before wiring chat state in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ChatStore.instance.startForCurrentSession());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppSession.instance.revision.removeListener(_sessionChanged);
    ChatStore.instance.pauseRealtime();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ChatStore.instance.startForCurrentSession());
      unawaited(ChatStore.instance.refreshConversations());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ChatStore.instance.pauseRealtime();
    }
  }

  void _sessionChanged() {
    unawaited(ChatStore.instance.startForCurrentSession());
    unawaited(ChatStore.instance.refreshConversations());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
