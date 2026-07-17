import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../models/chat_models.dart';
import '../models/chat_media_models.dart';
import '../state/chat_store.dart';
import '../state/chat_failure.dart';
import 'chat_media_preview_screen.dart';
import 'widgets/chat_avatar.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/chat_message_composer.dart';
import 'widgets/chat_pending_media_bubble.dart';
import 'widgets/chat_role_dock.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with WidgetsBindingObserver {
  final store = ChatStore.instance;
  final controller = TextEditingController();
  final scrollController = ScrollController();
  final composerHeight = ValueNotifier<double>(
    ChatRoleDock.messageComposerHeight,
  );
  int previousMessageCount = 0;
  bool _keepPinnedToBottom = true;
  bool _bottomCorrectionScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_updateComposerHeight);
    store.setActiveConversation(widget.conversation.conversationId);
    unawaited(store.loadMessages(widget.conversation.conversationId));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateComposerHeight();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.setActiveConversation('');
    controller.removeListener(_updateComposerHeight);
    composerHeight.dispose();
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = controller.text.trim();
    if (body.isEmpty || store.sending) return;
    try {
      await store.sendMessage(widget.conversation.conversationId, body);
      controller.clear();
      store.clearSendError();
      _scrollToBottom();
    } catch (exception) {
      if (!mounted) return;
      final message = store.sendError.isNotEmpty
          ? store.sendError
          : chatFailureMessage(exception);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _draftChanged() {
    store.clearSendError();
  }

  void _updateComposerHeight() {
    final next = ChatRoleDock.composerHeight(context, controller.text);
    if ((composerHeight.value - next).abs() < 0.5) return;
    composerHeight.value = next;
  }

  void _scrollToBottom() {
    _keepPinnedToBottom = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void didChangeMetrics() {
    if (_keepPinnedToBottom) {
      _scheduleBottomCorrection();
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    final userUpdate = notification is ScrollUpdateNotification &&
        notification.dragDetails != null;
    if (userUpdate || notification is ScrollEndNotification) {
      _keepPinnedToBottom = notification.metrics.extentAfter <= 48;
    }
    return false;
  }

  bool _handleScrollMetricsNotification(
    ScrollMetricsNotification notification,
  ) {
    if (_keepPinnedToBottom) {
      _scheduleBottomCorrection();
    }
    return false;
  }

  void _scheduleBottomCorrection() {
    if (_bottomCorrectionScheduled) return;
    _bottomCorrectionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bottomCorrectionScheduled = false;
      if (!mounted || !_keepPinnedToBottom || !scrollController.hasClients) {
        return;
      }
      final position = scrollController.position;
      if ((position.maxScrollExtent - position.pixels).abs() > 0.5) {
        scrollController.jumpTo(position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: composerHeight,
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final messages = store.messagesFor(
            widget.conversation.conversationId,
          );
          final pending = store.pendingMediaFor(
            widget.conversation.conversationId,
          );
          final visibleCount = messages.length + pending.length;
          if (visibleCount > previousMessageCount) {
            previousMessageCount = visibleCount;
            _scrollToBottom();
          }
          return _messages(messages, pending);
        },
      ),
      builder: (context, dockHeight, messageList) {
        return ChatKeyboardInsetLayout(
          builder: (context, keyboardInset) => AppShell(
            title: widget.conversation.displayTitle,
            subtitle: '',
            titleWidget: AnimatedBuilder(
              animation: store,
              builder: (context, _) => _ConversationTitle(
                conversation: widget.conversation,
                connected: store.connected,
              ),
            ),
            nativeTopBar: true,
            showProfileAction: false,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _ChatParticipantProfileAction(
                  participant: widget.conversation.peer,
                  onTap: _openParticipantProfile,
                ),
              ),
            ],
            contentPadding: EdgeInsets.zero,
            bottomDockHeight: dockHeight + keyboardInset,
            bottomPadding: EdgeInsets.only(bottom: keyboardInset),
            bottom: AnimatedBuilder(
              animation: store,
              builder: (context, _) => ChatRoleDock(
                composerController: controller,
                messageComposer: ChatMessageComposer(
                  controller: controller,
                  sending: store.sending,
                  errorText: store.sendError,
                  onSend: _send,
                  onDraftChanged: _draftChanged,
                  onAttach: _attachMedia,
                  embeddedInDock: true,
                ),
              ),
            ),
            child: messageList!,
          ),
        );
      },
    );
  }

  Widget _messages(
    List<ChatMessage> messages,
    List<ChatPendingMedia> pendingMedia,
  ) {
    if (messages.isEmpty &&
        pendingMedia.isEmpty &&
        store.loadingMessagesFor(widget.conversation.conversationId)) {
      return const Center(child: AppLoadingIndicator());
    }
    if (messages.isEmpty && pendingMedia.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Birinchi xabaringizni yozing.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }
    final profile = AppSession.instance.profile;
    final children = <Widget>[];
    if (store.hasMoreMessages(widget.conversation.conversationId)) {
      children.add(
        Center(
          child: TextButton.icon(
            onPressed: () => store.loadOlderMessages(
              widget.conversation.conversationId,
            ),
            icon: const Icon(Icons.expand_less_rounded),
            label: const Text('Oldingi xabarlar'),
          ),
        ),
      );
    }
    for (var index = 0; index < messages.length; index++) {
      final message = messages[index];
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        message.createdAtUnix * 1000,
      ).toLocal();
      final previous = index == 0 ? null : messages[index - 1];
      final next = index + 1 < messages.length ? messages[index + 1] : null;
      final previousCreatedAt = previous == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              previous.createdAtUnix * 1000,
            ).toLocal();
      final nextCreatedAt = next == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              next.createdAtUnix * 1000,
            ).toLocal();
      final groupedWithPrevious = _sameMessageGroup(
        previous,
        previousCreatedAt,
        message,
        createdAt,
      );
      final groupedWithNext = _sameMessageGroup(
        message,
        createdAt,
        next,
        nextCreatedAt,
      );
      final newDay = previousCreatedAt == null ||
          createdAt.year != previousCreatedAt.year ||
          createdAt.month != previousCreatedAt.month ||
          createdAt.day != previousCreatedAt.day;
      if (newDay) {
        children.add(ChatDateDivider(date: createdAt));
      }
      children.add(
        ChatMessageBubble(
          message: message,
          mine: profile != null && message.isMine(profile),
          compactTop: groupedWithPrevious,
          isLastInGroup: !groupedWithNext,
        ),
      );
    }
    for (final pending in pendingMedia) {
      children.add(
        ChatPendingMediaBubble(
          key: ValueKey(pending.localId),
          pending: pending,
          onRetry: () => store.retryMedia(pending.localId),
          onCancel: () => store.cancelMedia(pending.localId),
        ),
      );
    }
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: _handleScrollMetricsNotification,
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: children,
          ),
        ),
      ),
    );
  }

  bool _sameMessageGroup(
    ChatMessage? first,
    DateTime? firstCreatedAt,
    ChatMessage? second,
    DateTime? secondCreatedAt,
  ) {
    if (first == null ||
        firstCreatedAt == null ||
        second == null ||
        secondCreatedAt == null) {
      return false;
    }
    final sameDay = firstCreatedAt.year == secondCreatedAt.year &&
        firstCreatedAt.month == secondCreatedAt.month &&
        firstCreatedAt.day == secondCreatedAt.day;
    return sameDay &&
        first.senderPrincipalId == second.senderPrincipalId &&
        second.createdAtUnix - first.createdAtUnix <= 300;
  }

  Future<void> _attachMedia() async {
    final selection = await showModalBottomSheet<_MediaPickerSelection>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _ChatMediaPickerSheet(),
    );
    if (selection == null || !mounted) return;
    try {
      final picker = ImagePicker();
      final XFile? source = switch ((selection.kind, selection.source)) {
        (ChatMediaKind.image, ImageSource.gallery) => await picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 95,
          ),
        (ChatMediaKind.image, ImageSource.camera) => await picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 95,
            preferredCameraDevice: CameraDevice.rear,
          ),
        (ChatMediaKind.video, ImageSource.gallery) => await picker.pickVideo(
            source: ImageSource.gallery,
          ),
        (ChatMediaKind.video, ImageSource.camera) => await picker.pickVideo(
            source: ImageSource.camera,
            preferredCameraDevice: CameraDevice.rear,
            maxDuration: chatMediaVideoMaxDuration,
          ),
      };
      if (source == null || !mounted) return;
      final size = await source.length();
      final maximum = selection.kind == ChatMediaKind.image
          ? chatMediaImageMaxBytes
          : chatMediaVideoMaxBytes;
      if (size <= 0 || size > maximum) {
        throw MobileApiException(
          code: 'chat_media_too_large',
          message: selection.kind == ChatMediaKind.image
              ? 'Rasm 15 MiB dan oshmasligi kerak.'
              : 'Video 2 GiB va 10 daqiqadan oshmasligi kerak.',
          statusCode: 413,
        );
      }
      if (!mounted) return;
      final draft = await Navigator.of(context).push<ChatMediaDraft>(
        MaterialPageRoute(
          builder: (_) => ChatMediaPreviewScreen(
            source: source,
            kind: selection.kind,
          ),
        ),
      );
      if (draft == null || !mounted) return;
      await store.queueMedia(
        conversationId: widget.conversation.conversationId,
        source: draft.source,
        kind: draft.kind,
        caption: draft.caption,
        durationMs: draft.durationMs,
      );
      _scrollToBottom();
    } on PlatformException catch (error) {
      _showMediaError(
        error.code == 'camera_access_denied'
            ? 'Kameraga ruxsat berilmagan.'
            : 'Media tanlab bo‘lmadi. Ruxsatlarni tekshiring.',
      );
    } catch (error) {
      _showMediaError(chatMediaFailureMessage(error));
    }
  }

  void _showMediaError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openParticipantProfile() {
    final participant = widget.conversation.peer;
    if (participant == null) {
      return;
    }
    Navigator.of(context).pushNamed(
      AppRoutes.chatParticipantProfile,
      arguments: participant,
    );
  }
}

class _MediaPickerSelection {
  const _MediaPickerSelection(this.kind, this.source);

  final ChatMediaKind kind;
  final ImageSource source;
}

class _ChatMediaPickerSheet extends StatelessWidget {
  const _ChatMediaPickerSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MediaPickerTile(
              icon: Icons.photo_library_outlined,
              label: 'Galereyadan rasm',
              onTap: () => _pop(
                context,
                ChatMediaKind.image,
                ImageSource.gallery,
              ),
            ),
            _MediaPickerTile(
              icon: Icons.camera_alt_outlined,
              label: 'Rasmga olish',
              onTap: () =>
                  _pop(context, ChatMediaKind.image, ImageSource.camera),
            ),
            _MediaPickerTile(
              icon: Icons.video_library_outlined,
              label: 'Galereyadan video',
              onTap: () => _pop(
                context,
                ChatMediaKind.video,
                ImageSource.gallery,
              ),
            ),
            _MediaPickerTile(
              icon: Icons.videocam_outlined,
              label: 'Video yozish',
              onTap: () =>
                  _pop(context, ChatMediaKind.video, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  void _pop(
    BuildContext context,
    ChatMediaKind kind,
    ImageSource source,
  ) {
    Navigator.of(context).pop(_MediaPickerSelection(kind, source));
  }
}

class _MediaPickerTile extends StatelessWidget {
  const _MediaPickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}

class _ConversationTitle extends StatelessWidget {
  const _ConversationTitle({
    required this.conversation,
    required this.connected,
  });

  final ChatConversation conversation;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          conversation.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        Text(
          connected ? 'Onlayn' : 'Ulanmoqda…',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _ChatParticipantProfileAction extends StatelessWidget {
  const _ChatParticipantProfileAction({
    required this.participant,
    required this.onTap,
  });

  final ChatPrincipal? participant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = participant?.displayName.trim().isNotEmpty == true
        ? participant!.displayName
        : 'Suhbat';
    return Semantics(
      button: true,
      label: '$name profili',
      child: AppShellIconAction(
        size: 44,
        iconWidget: ChatAvatar(
          name: name,
          avatarUrl: participant?.avatarUrl ?? '',
          radius: 17,
        ),
        onTap: participant == null ? () {} : onTap,
      ),
    );
  }
}
