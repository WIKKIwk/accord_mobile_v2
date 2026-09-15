import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../models/telegram_models.dart';

class TelegramInviteQrDialog extends StatelessWidget {
  const TelegramInviteQrDialog({
    super.key,
    required this.invite,
  });

  final TelegramInvite invite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final role = invite.role.label(
      adminLabel: context.l10n.adminTelegramAdminRoleTitle,
      salesManagerLabel: context.l10n.adminTelegramSalesManagerRoleTitle,
    );

    return AlertDialog(
      title: Text(context.l10n.adminTelegramQrTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              role,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.adminTelegramQrScanInstruction,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: QrImageView(
                  data: invite.inviteUrl,
                  size: 230,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.adminTelegramQrCancel),
        ),
      ],
    );
  }
}
