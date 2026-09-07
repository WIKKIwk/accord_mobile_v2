import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';

Future<bool> confirmFactoryMapUnlink(BuildContext context, String name) async {
  final l10n = context.l10n;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.adminText('apparatus.remove_link')),
          content: Text(l10n.adminText('factory_map.unlink_confirmation',
              values: {'name': name})),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.adminText('action.cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.adminText('apparatus.remove_link'))),
          ],
        ),
      ) ??
      false;
}
