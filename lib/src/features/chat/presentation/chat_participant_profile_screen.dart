import 'package:flutter/material.dart';

import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../models/chat_models.dart';
import 'widgets/chat_avatar.dart';

class ChatParticipantProfileScreen extends StatelessWidget {
  const ChatParticipantProfileScreen({
    super.key,
    required this.participant,
  });

  final ChatPrincipal participant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppShell(
      title: 'Profil',
      subtitle: '',
      nativeTopBar: true,
      showProfileAction: false,
      contentPadding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Center(
        child: Card(
          margin: EdgeInsets.zero,
          color: scheme.surfaceContainerLowest,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChatAvatar(
                  name: participant.displayName,
                  avatarUrl: participant.avatarUrl,
                  radius: 52,
                ),
                const SizedBox(height: 18),
                Text(
                  participant.displayName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  userRoleLabel(participant.role),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
