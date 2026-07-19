import 'package:flutter/material.dart';

import 'chat_role_dock.dart';

class ChatMessageComposer extends StatelessWidget {
  const ChatMessageComposer({
    super.key,
    required this.controller,
    required this.sending,
    required this.errorText,
    required this.onSend,
    required this.onDraftChanged,
    this.onAttach,
    this.onVoiceAction,
    this.onCancelVoice,
    this.recordingVoice = false,
    this.voiceBusy = false,
    this.voiceDuration = Duration.zero,
    this.embeddedInDock = false,
  });

  final TextEditingController controller;
  final bool sending;
  final String errorText;
  final VoidCallback onSend;
  final VoidCallback onDraftChanged;
  final VoidCallback? onAttach;
  final VoidCallback? onVoiceAction;
  final VoidCallback? onCancelVoice;
  final bool recordingVoice;
  final bool voiceBusy;
  final Duration voiceDuration;
  final bool embeddedInDock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (embeddedInDock) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: OverflowBox(
          alignment: Alignment.bottomCenter,
          minHeight: 0,
          maxHeight: chatComposerMaxHeight,
          child: Transform.translate(
            offset: const Offset(0, -13),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _ComposerRow(
                controller: controller,
                sending: sending,
                errorText: errorText,
                onSend: onSend,
                onDraftChanged: onDraftChanged,
                onAttach: onAttach,
                onVoiceAction: onVoiceAction,
                onCancelVoice: onCancelVoice,
                recordingVoice: recordingVoice,
                voiceBusy: voiceBusy,
                voiceDuration: voiceDuration,
                compact: true,
              ),
            ),
          ),
        ),
      );
    }
    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (errorText.isNotEmpty) ...[
                _SendError(
                  message: errorText,
                  retrying: sending,
                  onRetry: onSend,
                ),
                const SizedBox(height: 8),
              ],
              _ComposerRow(
                controller: controller,
                sending: sending,
                errorText: errorText,
                onSend: onSend,
                onDraftChanged: onDraftChanged,
                onAttach: onAttach,
                onVoiceAction: onVoiceAction,
                onCancelVoice: onCancelVoice,
                recordingVoice: recordingVoice,
                voiceBusy: voiceBusy,
                voiceDuration: voiceDuration,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerRow extends StatelessWidget {
  const _ComposerRow({
    required this.controller,
    required this.sending,
    required this.errorText,
    required this.onSend,
    required this.onDraftChanged,
    this.onAttach,
    this.onVoiceAction,
    this.onCancelVoice,
    this.recordingVoice = false,
    this.voiceBusy = false,
    this.voiceDuration = Duration.zero,
    this.compact = false,
  });

  final TextEditingController controller;
  final bool sending;
  final String errorText;
  final VoidCallback onSend;
  final VoidCallback onDraftChanged;
  final VoidCallback? onAttach;
  final VoidCallback? onVoiceAction;
  final VoidCallback? onCancelVoice;
  final bool recordingVoice;
  final bool voiceBusy;
  final Duration voiceDuration;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        final voiceAvailable = onVoiceAction != null;
        final canSend = hasText && !sending && !recordingVoice;
        final inputPadding = EdgeInsets.symmetric(
          horizontal: compact ? 16 : 18,
          vertical: compact ? 10 : 13,
        );
        final buttonSize = compact ? 42.0 : 50.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: recordingVoice
                  ? _VoiceRecordingField(
                      duration: voiceDuration,
                      onCancel: voiceBusy ? null : onCancelVoice,
                      compact: compact,
                    )
                  : TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: compact ? 5 : 6,
                      maxLength: 4000,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      textCapitalization: TextCapitalization.sentences,
                      autocorrect: true,
                      enableSuggestions: true,
                      buildCounter: (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) =>
                          null,
                      decoration: InputDecoration(
                        hintText: 'Xabar yozing',
                        prefixIcon: onAttach == null
                            ? null
                            : IconButton(
                                tooltip: 'Media biriktirish',
                                onPressed: voiceBusy ? null : onAttach,
                                icon: const Icon(Icons.attach_file_rounded),
                              ),
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        isDense: compact,
                        contentPadding: inputPadding,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide(
                            color: scheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (_) => onDraftChanged(),
                    ),
            ),
            const SizedBox(width: 8),
            if (compact && errorText.isNotEmpty) ...[
              Tooltip(
                message: errorText,
                child: Icon(
                  Icons.error_outline_rounded,
                  color: scheme.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
            ],
            SizedBox.square(
              dimension: buttonSize,
              child: IconButton.filled(
                tooltip: recordingVoice
                    ? 'Ovozli xabarni yuborish'
                    : hasText || !voiceAvailable
                        ? 'Yuborish'
                        : 'Ovozli xabar yozish',
                onPressed: voiceBusy
                    ? null
                    : recordingVoice
                        ? onVoiceAction
                        : canSend
                            ? onSend
                            : onVoiceAction,
                icon: sending || voiceBusy
                    ? SizedBox.square(
                        dimension: compact ? 18 : 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: scheme.onPrimary,
                        ),
                      )
                    : Icon(
                        recordingVoice
                            ? Icons.stop_rounded
                            : hasText || !voiceAvailable
                                ? Icons.send_rounded
                                : Icons.mic_rounded,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VoiceRecordingField extends StatelessWidget {
  const _VoiceRecordingField({
    required this.duration,
    required this.onCancel,
    required this.compact,
  });

  final Duration duration;
  final VoidCallback? onCancel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 42 : 50),
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Icon(Icons.fiber_manual_record, color: scheme.error, size: 14),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Ovoz yozilmoqda  ${_voiceDuration(duration)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Yozuvni bekor qilish',
            visualDensity: VisualDensity.compact,
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

String _voiceDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class _SendError extends StatelessWidget {
  const _SendError({
    required this.message,
    required this.retrying,
    required this.onRetry,
  });

  final String message;
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
              ),
            ),
            TextButton(
              onPressed: retrying ? null : onRetry,
              child: const Text('Qayta yuborish'),
            ),
          ],
        ),
      ),
    );
  }
}
