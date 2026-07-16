import 'package:flutter/material.dart';

class ChatMessageComposer extends StatelessWidget {
  const ChatMessageComposer({
    super.key,
    required this.controller,
    required this.sending,
    required this.errorText,
    required this.onSend,
    required this.onDraftChanged,
    this.embeddedInDock = false,
  });

  final TextEditingController controller;
  final bool sending;
  final String errorText;
  final VoidCallback onSend;
  final VoidCallback onDraftChanged;
  final bool embeddedInDock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (embeddedInDock) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _ComposerRow(
            controller: controller,
            sending: sending,
            errorText: errorText,
            onSend: onSend,
            onDraftChanged: onDraftChanged,
            compact: true,
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
    this.compact = false,
  });

  final TextEditingController controller;
  final bool sending;
  final String errorText;
  final VoidCallback onSend;
  final VoidCallback onDraftChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final canSend = value.text.trim().isNotEmpty && !sending;
        final inputPadding = EdgeInsets.symmetric(
          horizontal: compact ? 16 : 18,
          vertical: compact ? 8 : 13,
        );
        final buttonSize = compact ? 42.0 : 50.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: compact ? 1 : 6,
                maxLength: 4000,
                keyboardType: TextInputType.multiline,
                textInputAction:
                    compact ? TextInputAction.send : TextInputAction.newline,
                onSubmitted: compact && canSend ? (_) => onSend() : null,
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
                tooltip: 'Yuborish',
                onPressed: canSend ? onSend : null,
                icon: sending
                    ? SizedBox.square(
                        dimension: compact ? 18 : 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: scheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ],
        );
      },
    );
  }
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
