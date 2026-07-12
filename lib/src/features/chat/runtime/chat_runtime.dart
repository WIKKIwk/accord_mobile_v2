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
    unawaited(ChatStore.instance.startForCurrentSession());
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
    }
  }

  void _sessionChanged() {
    unawaited(ChatStore.instance.startForCurrentSession());
    unawaited(ChatStore.instance.refreshConversations());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
