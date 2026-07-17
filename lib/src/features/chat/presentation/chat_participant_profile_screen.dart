import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/session/state/app_session.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/admin_customer_detail_screen.dart';
import '../../admin/presentation/admin_supplier_detail_screen.dart';
import '../../admin/presentation/admin_worker_detail_screen.dart';
import '../../admin/presentation/widgets/admin_profile_avatar.dart';
import '../../shared/presentation/widgets/profile_info_chip.dart';
import '../../shared/models/app_models.dart';
import '../models/chat_models.dart';
import 'widgets/chat_role_dock.dart';

/// Returns the existing admin detail surface when the current user can access
/// the admin directory. Other roles receive the safe read-only summary below
/// instead of a request that would be rejected by the admin API.
Widget _buildParticipantProfile(
    BuildContext context, ChatPrincipal participant) {
  final hasAdminAccess =
      AppSession.instance.profile?.accessRole == UserRole.admin;
  if (!hasAdminAccess) {
    return _ChatParticipantSummaryProfile(participant: participant);
  }

  final entry = _adminEntryFor(participant);
  return switch (participant.role) {
    UserRole.customer => AdminCustomerDetailScreen(
        customerRef: participant.ref,
        title: 'Haridor',
        profileSubtitle: 'Haridor profili',
        emptyName: 'Customer',
        namelessLabel: 'Nomsiz haridor',
        customerManagementEnabled: false,
        itemManagementEnabled: false,
        removeEnabled: false,
      ),
    UserRole.materialTaminotchi => AdminCustomerDetailScreen(
        customerRef: participant.ref,
        detailLoader: MobileApi.instance.adminMaterialTaminotchiDetail,
        title: 'Material taminotchisi',
        profileSubtitle: 'Material ta’minotchisi profili',
        emptyName: 'Material taminotchisi',
        namelessLabel: 'Nomsiz material ta’minotchisi',
        customerManagementEnabled: false,
        itemManagementEnabled: false,
        removeEnabled: false,
      ),
    UserRole.supplier => AdminSupplierDetailScreen(
        supplierRef: participant.ref,
        readOnly: true,
      ),
    UserRole.aparatchi ||
    UserRole.qolipchi ||
    UserRole.boyoqchi =>
      AdminWorkerDetailScreen(entry: entry, readOnly: true),
    UserRole.admin ||
    UserRole.werka =>
      _ChatParticipantSummaryProfile(participant: participant),
  };
}

AdminUserListEntry _adminEntryFor(ChatPrincipal participant) {
  final kind = switch (participant.role) {
    UserRole.qolipchi => AdminUserKind.qolipchi,
    UserRole.boyoqchi => AdminUserKind.boyoqchi,
    UserRole.aparatchi => AdminUserKind.worker,
    _ => AdminUserKind.worker,
  };
  return AdminUserListEntry(
    id: participant.ref,
    name: participant.displayName,
    phone: '',
    kind: kind,
    avatarUrl: participant.avatarUrl,
    principalRole: participant.role,
  );
}

class ChatParticipantProfileScreen extends StatelessWidget {
  const ChatParticipantProfileScreen({
    super.key,
    required this.participant,
  });

  final ChatPrincipal participant;

  @override
  Widget build(BuildContext context) {
    return _buildParticipantProfile(context, participant);
  }
}

class _ChatParticipantSummaryProfile extends StatelessWidget {
  const _ChatParticipantSummaryProfile({required this.participant});

  final ChatPrincipal participant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayName = participant.displayName.trim().isEmpty
        ? 'Nomsiz foydalanuvchi'
        : participant.displayName.trim();
    final profileSubtitle = '${userRoleLabel(participant.role)} profili';

    return AppShell(
      title: userRoleLabel(participant.role),
      subtitle: '',
      nativeTopBar: true,
      showProfileAction: false,
      contentPadding: EdgeInsets.zero,
      bottom: const ChatRoleDock(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 116),
        children: [
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 204,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        top: 112,
                        child: ColoredBox(color: scheme.surface),
                      ),
                      const Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: 112,
                        child: ColoredBox(color: Colors.black),
                      ),
                      const Positioned(
                        right: 14,
                        top: 14,
                        child: _ParticipantStatusChip(),
                      ),
                      Positioned(
                        left: 16,
                        top: 74,
                        child: AdminProfileAvatar(
                          avatarUrl: participant.avatarUrl,
                          fallbackText: _participantInitials(displayName),
                        ),
                      ),
                      Positioned(
                        left: 124,
                        right: 16,
                        top: 140,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.08,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              profileSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const ProfileInfoChip(
                        icon: Icons.phone_rounded,
                        label: 'Telefon kiritilmagan',
                      ),
                      ProfileInfoChip(
                        icon: Icons.badge_rounded,
                        label: userRoleLabel(participant.role),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantStatusChip extends StatelessWidget {
  const _ParticipantStatusChip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text('Tayyor'),
      ),
    );
  }
}

String _participantInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return 'A';
  final first = parts.first.characters.first.toUpperCase();
  if (parts.length == 1) return first;
  return '$first${parts.last.characters.first.toUpperCase()}';
}
