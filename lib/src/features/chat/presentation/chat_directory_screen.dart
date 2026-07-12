import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../shared/models/app_models.dart';
import '../models/chat_models.dart';
import '../state/chat_failure.dart';
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
  final searchFocusNode = FocusNode();
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
    searchFocusNode.dispose();
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(chatFailureMessage(error)),
        ),
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
          title: '',
          subtitle: '',
          nativeTopBar: true,
          automaticallyImplyNativeLeading: false,
          nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
          profileActionListenable: searchFocusNode,
          showProfileActionResolver: () => !searchFocusNode.hasFocus,
          titleWidget: AdminCatalogSearchField(
            controller: searchController,
            focusNode: searchFocusNode,
            hintText: 'Foydalanuvchi qidirish',
            onChanged: _search,
            onClear: () {
              searchController.clear();
              _search('');
            },
          ),
          contentPadding: EdgeInsets.zero,
          child: _directoryList(),
        );
      },
    );
  }

  Widget _directoryList() {
    if (store.loadingDirectory && store.directory.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }
    if (store.error.isNotEmpty && store.directory.isEmpty) {
      return Center(
        child: FilledButton.tonalIcon(
          onPressed: () => store.searchDirectory(searchController.text),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Qayta qidirish'),
        ),
      );
    }
    if (store.directory.isEmpty) {
      return const Center(child: Text('Foydalanuvchi topilmadi'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      itemCount: store.directory.length,
      itemBuilder: (context, index) {
        final entry = store.directory[index];
        return ListTile(
          minTileHeight: 76,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          onTap: () => _open(entry),
          leading: ChatAvatar(
            name: entry.displayName,
            avatarUrl: entry.avatarUrl,
            radius: 25,
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
