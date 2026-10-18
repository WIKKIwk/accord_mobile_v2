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
import '../state/chat_audio_playback_controller.dart';
import '../state/chat_draft_controller.dart';
import '../state/chat_failure.dart';
import '../state/chat_store.dart';
import '../data/chat_media_file_store.dart';
import 'chat_media_preview_screen.dart';
import 'chat_voice_recorder.dart';
import 'widgets/chat_avatar.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/chat_message_composer.dart';
import 'widgets/chat_pending_media_bubble.dart';
import 'widgets/chat_role_dock.dart';
import 'widgets/chat_voice_mini_player.dart';
import '../../../core/localization/urdu_aware_text.dart';

part 'chat_detail_screen__ChatDetailScreenState_methods_01.dart';
part 'chat_detail_screen_widgets_part_01.dart';

const Duration _voiceAutoStopMargin = Duration(seconds: 1);

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with WidgetsBindingObserver {
  final store = ChatStore.instance;
  final controller = TextEditingController();
  final scrollController = ScrollController();
  final composerHeight = ValueNotifier<double>(
    ChatRoleDock.messageComposerHeight,
  );
  final audioPlayback = ChatAudioPlaybackController();
  final voiceRecorder = ChatVoiceRecorder();
  late final ChatDraftController draftController;
  late final String _accountIdentity;
  final latestButton = ValueNotifier<({bool visible, int unread})>(
    (visible: false, unread: 0),
  );
  Timer? _voiceTimer;
  bool _recordingVoice = false;
  bool _voiceBusy = false;
  Duration _voiceDuration = Duration.zero;
  int? _lastMessageSequence;
  int _previousPendingCount = 0;
  int _newMessages = 0;
  String? _timelineAnchorId;
  bool _scrollControlsScheduled = false;
  bool _historyLoadScheduled = false;
  bool _keepPinnedToBottom = true;
  bool _bottomCorrectionScheduled = false;

  String get _currentAccountIdentity {
    final profile = AppSession.instance.profile;
    return '${MobileApi.baseUrl}\n${profile?.role.name}\n${profile?.ref}';
  }

  bool get _isCurrentAccount =>
      AppSession.instance.isLoggedIn &&
      _accountIdentity == _currentAccountIdentity;

  void _sessionChanged() {
    if (!mounted || _isCurrentAccount) return;
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(audioPlayback.stop());
    unawaited(_cancelVoiceRecording(showMessage: false));
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _accountIdentity = _currentAccountIdentity;
    AppSession.instance.revision.addListener(_sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_updateComposerHeight);
    final profile = AppSession.instance.profile;
    draftController = ChatDraftController(
      textController: controller,
      endpoint: MobileApi.baseUrl,
      accountId: '${profile?.role.name}:${profile?.ref}',
      conversationId: widget.conversation.conversationId,
    );
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
    AppSession.instance.revision.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    store.setActiveConversation('');
    controller.removeListener(_updateComposerHeight);
    composerHeight.dispose();
    draftController.dispose();
    latestButton.dispose();
    controller.dispose();
    scrollController.dispose();
    _voiceTimer?.cancel();
    audioPlayback.dispose();
    unawaited(voiceRecorder.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_recordingVoice && state != AppLifecycleState.resumed && !_voiceBusy) {
      unawaited(_cancelVoiceRecording(showMessage: false));
    }
  }

  @override
  void didChangeMetrics() {
    if (_keepPinnedToBottom) {
      _scheduleBottomCorrection();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCurrentAccount) {
      return AppShell(
        title: 'Chat',
        subtitle: '',
        nativeTopBar: true,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const UrduAwareText('Hisob o‘zgardi. Chatni qayta oching.'),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const UrduAwareText('Orqaga'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ValueListenableBuilder<double>(
      valueListenable: composerHeight,
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final messages = store.messagesFor(
            widget.conversation.conversationId,
          );
          audioPlayback.setKnownMessages(messages);
          final pending = store.pendingMediaFor(
            widget.conversation.conversationId,
          );
          _observeTimeline(messages, pending);
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
                padding: const EdgeInsetsDirectional.only(end: 10),
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
                  onVoiceAction: _recordingVoice
                      ? _finishVoiceRecording
                      : _startVoiceRecording,
                  onCancelVoice: _cancelVoiceRecording,
                  recordingVoice: _recordingVoice,
                  voiceBusy: _voiceBusy,
                  voiceDuration: _voiceDuration,
                  embeddedInDock: true,
                ),
              ),
            ),
            child: Column(
              children: [
                ChatVoiceMiniPlayer(playback: audioPlayback),
                Expanded(child: messageList!),
              ],
            ),
          ),
        );
      },
    );
  }
}
