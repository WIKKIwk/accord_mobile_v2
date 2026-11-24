import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/urdu_aware_text.dart';
import '../../../core/session/session_read_scope.dart';

Future<bool> showScannedPreparationRollNotes(
  BuildContext context,
  String barcode, {
  bool Function()? isCurrent,
}) async {
  if (!context.mounted || isCurrent?.call() == false) return false;
  final scope = currentSessionReadScope();
  final PreparationRollNotes? notes;
  try {
    notes = await MobileApi.instance.preparationRollNotesForScan(barcode);
  } on Exception {
    return false;
  } on StateError {
    return false;
  }
  if (notes == null ||
      !context.mounted ||
      scope != currentSessionReadScope() ||
      ModalRoute.of(context)?.isCurrent == false ||
      isCurrent?.call() == false) {
    return false;
  }
  final batchText = notes.batch?.text ?? '';
  final rollText = notes.roll?.text ?? '';
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('scanned-preparation-roll-notes'),
      scrollable: true,
      title: const UrduAwareText('Eslatma'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (batchText.isNotEmpty) ...[
            const UrduAwareText('Batch eslatmasi'),
            Text(batchText),
          ],
          if (rollText.isNotEmpty) ...[
            if (batchText.isNotEmpty) const SizedBox(height: 12),
            const UrduAwareText('Rulon eslatmasi'),
            Text(rollText),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.productionText('worker.action.close')),
        ),
      ],
    ),
  );
  return true;
}
