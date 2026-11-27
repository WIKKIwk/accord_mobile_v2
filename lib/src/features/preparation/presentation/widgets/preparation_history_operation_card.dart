import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/localization/urdu_aware_text.dart';
import '../../../../core/session/session_read_scope.dart';
import '../../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../../core/widgets/feedback/spring_bottom_sheet.dart';
import '../../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../admin/presentation/widgets/admin_summary_card.dart';
import '../../models/preparation_models.dart';
import 'preparation_input_dialog.dart';

class PreparationHistoryOperationCard extends StatelessWidget {
  const PreparationHistoryOperationCard({
    super.key,
    required this.operation,
    required this.date,
    required this.slot,
    required this.onReversed,
  });

  final Map<String, dynamic> operation;
  final String date;
  final M3SegmentVerticalSlot slot;
  final Future<void> Function() onReversed;

  Future<void> _showReceiptActions(BuildContext context) async {
    final scope = currentSessionReadScope();
    bool isCurrent() => context.mounted && scope == currentSessionReadScope();

    final canReverse = operation['can_reverse'] == true;
    final kg = preparationDisplay(operation['kg']?.toString() ?? '0');
    final action = await showSpringBottomSheet<String>(
      context: context,
      builder: (_) => AppActionSheet<String>(
        title: 'Kirim — ${operation['name'] ?? ''}',
        subtitle: '${operation['warehouse'] ?? ''} • $kg kg',
        actions: [
          AppActionSheetAction(
            title: 'Kirimni bekor qilish',
            icon: Icons.undo_rounded,
            value: 'reverse',
            subtitle: canReverse
                ? 'Ishlatilmagan va orderga ulanmagan kirim'
                : 'Bu kirimni bekor qilib bo‘lmaydi',
            enabled: canReverse,
            destructive: true,
          ),
          const AppActionSheetAction(
            title: 'Yopish',
            icon: Icons.close_rounded,
            value: 'close',
          ),
        ],
      ),
    );
    if (action != 'reverse' || !canReverse || !isCurrent()) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const PreparationInputDialog(
        title: 'Kirimni bekor qilish',
        label: 'Sabab',
        emptyError: 'Sabab kiriting',
        maxLength: 500,
      ),
    );
    if (reason == null || !isCurrent()) return;
    final confirmed = await showM3ConfirmDialog(
      context: context,
      title: 'Kirimni bekor qilish',
      message: '$kg kg kirim bekor qilinsinmi? Bu amal tarixda saqlanadi.',
      cancelLabel: 'Qaytish',
      confirmLabel: 'Bekor qilish',
      destructive: true,
    );
    if (confirmed != true || !isCurrent()) return;
    try {
      await MobileApi.instance.preparationReverseReceipt(
        receiptId: operation['id'] as String,
        reason: reason,
      );
    } catch (error) {
      if (isCurrent()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
      return;
    }
    if (!isCurrent()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: UrduAwareText('Kirim bekor qilindi')),
    );
    await onReversed();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isReceipt = operation['kind'] == 'receipt';
    final isReversal = operation['kind'] == 'receipt_reversal';
    final reversed = operation['reversed'] == true;
    final title = switch (operation['kind']) {
      'receipt' =>
        '${operation['name']} ${localizeUrduUiText('kirim qilindi')}',
      'receipt_reversal' =>
        '${operation['name']} ${localizeUrduUiText('kirimi bekor qilindi')}',
      _ =>
        '${localizeUrduUiText('Ishlatildi')} · ${operation['order_code']} ${operation['order_title']}',
    };
    final lines = (operation['lines'] as List? ?? const []).whereType<Map>();
    final details = [
      '${operation['warehouse']} • $date',
      if (reversed) 'Bekor qilingan',
      for (final line in lines)
        '${line['name']} · ${preparationDisplay(line['percent'].toString())}%'
            ' → ${preparationDisplay(line['kg'].toString())} kg',
      if (operation['reason'] case final String reason when isReversal) reason,
    ];
    final String value;
    if (isReceipt || isReversal) {
      final kg = preparationDisplay(operation['kg']?.toString() ?? '0');
      value = '${isReceipt ? '+' : '−'}$kg kg';
    } else {
      var total = BigInt.zero;
      for (final line in lines) {
        total += preparationDecimal(line['kg'].toString(), allowZero: true);
      }
      value = '−${preparationDisplay(preparationDecimalText(total))} kg';
    }

    return AdminSummaryCard(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      backgroundColor: scheme.surfaceContainerLowest,
      title: title,
      subtitle: details.join('\n'),
      value: value,
      leading: Icon(
        isReversal || reversed
            ? Icons.undo_rounded
            : isReceipt
                ? Icons.check_circle_outline_rounded
                : Icons.remove_circle_outline_rounded,
        color: isReversal
            ? scheme.error
            : reversed
                ? scheme.outline
                : isReceipt
                    ? Colors.green
                    : Colors.orange,
      ),
      onLongPress:
          isReceipt && !reversed ? () => _showReceiptActions(context) : null,
      showChevron: false,
      elevation: 1,
    );
  }
}
