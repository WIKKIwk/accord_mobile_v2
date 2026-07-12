import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../models/chat_models.dart';
import '../state/chat_store.dart';
import 'widgets/chat_avatar.dart';

class ChatDirectoryScreen extends StatefulWidget {
  const ChatDirectoryScreen({super.key});

  @override
  State<ChatDirectoryScreen> createState() => _ChatDirectoryScreenState();
}

class _ChatDirectoryScreenState extends State<ChatDirectoryScreen> {
  final store = ChatStore.instance;
  final searchController = TextEditingController();
  Timer? debounce;
  String openingRef = '';

  @override
  void initState() {
    super.initState();
    unawaited(
        store.startForCurrentSession().then((_) => store.searchDirectory('')));
  }

  @override
  void dispose() {
    debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    debounce?.cancel();
    debounce = Timer(
      const Duration(milliseconds: 300),
      () => store.searchDirectory(value),
    );
  }

  Future<void> _open(ChatDirectoryEntry target) async {
    if (openingRef.isNotEmpty) return;
    setState(() => openingRef = target.ref);
    try {
      final conversation = await store.openConversation(target);
      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed(
        AppRoutes.chatDetail,
        arguments: conversation,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Suhbatni ochib bo‘lmadi')),
      );
    } finally {
      if (mounted) setState(() => openingRef = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return AppShell(
          title: 'Yangi suhbat',
          subtitle: 'Foydalanuvchini tanlang',
          nativeTopBar: true,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: SearchBar(
                  controller: searchController,
                  hintText: 'Ism bo‘yicha qidirish',
                  leading: const Icon(Icons.search_rounded),
                  onChanged: _search,
                ),
              ),
              Expanded(child: _directoryList()),
            ],
          ),
        );
      },
    );
  }

  Widget _directoryList() {
    if (store.loadingDirectory && store.directory.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }
    if (store.directory.isEmpty) {
      return const Center(child: Text('Foydalanuvchi topilmadi'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      itemCount: store.directory.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final entry = store.directory[index];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          onTap: () => _open(entry),
          leading: ChatAvatar(
            name: entry.displayName,
            avatarUrl: entry.avatarUrl,
          ),
          title: Text(
            entry.displayName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(userRoleLabel(entry.role)),
          trailing: openingRef == entry.ref
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chat_bubble_outline_rounded),
        );
      },
    );
  }
}
