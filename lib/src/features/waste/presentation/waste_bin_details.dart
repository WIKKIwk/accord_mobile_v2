import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/display/app_info_row.dart';
import '../../../core/widgets/lists/app_segment_surface_card.dart';

String wasteKgLabel(double kg) =>
    '${kg.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '')} kg';

double? wasteKgInput(String value) {
  final kg = double.tryParse(value.trim().replaceAll(',', '.'));
  return kg != null && kg.isFinite && kg >= 0 && kg < 1e12 ? kg : null;
}

String wasteStatusLabel(WasteBinStatus status) => switch (status) {
      WasteBinStatus.empty => 'Bo‘sh',
      WasteBinStatus.open => 'Yig‘ilmoqda',
      WasteBinStatus.sealed => 'Qabulni kutmoqda',
      WasteBinStatus.received => 'Qabul qilingan',
      WasteBinStatus.reset => 'Bo‘shatilgan',
    };

String wasteErrorText(Object error) {
  if (error is MobileApiException) {
    return switch (error.code) {
      'waste_bin_not_found' => 'Quti topilmadi. QR kodini tekshiring.',
      'waste_bin_conflict' => 'Quti holati o‘zgargan. Qayta yuklang.',
      _ => error.message,
    };
  }
  if (error is FormatException) return error.message;
  return 'Amalni bajarib bo‘lmadi. Qayta urinib ko‘ring.';
}

String wasteWhen(BuildContext context, DateTime? date) {
  if (date == null) return '';
  final formats = MaterialLocalizations.of(context);
  return '${formats.formatShortDate(date)} '
      '${formats.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
}

class WasteCycleDetails extends StatelessWidget {
  const WasteCycleDetails({super.key, required this.cycle});

  final WasteCycle cycle;

  @override
  Widget build(BuildContext context) {
    final receipt = cycle.receipt;
    final declaredByWorker = <(String, String), double>{};
    for (final entry in cycle.entries) {
      final key = (entry.actorRef, entry.actorName);
      declaredByWorker.update(key, (total) => total + entry.kg,
          ifAbsent: () => entry.kg);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.factory_outlined),
          title: Text(cycle.apparatusName.isEmpty
              ? cycle.apparatusId
              : cycle.apparatusName),
          subtitle: Text(wasteStatusLabel(cycle.status)),
          trailing: Text(wasteKgLabel(cycle.expectedKg)),
        ),
        if (cycle.openedAt != null)
          _movement(context, 'Biriktirildi', cycle.openedBy, cycle.openedAt),
        if (cycle.sealedAt != null)
          _movement(context, 'Topshirildi', cycle.sealedBy, cycle.sealedAt),
        if (receipt != null) ...[
          WasteWeightComparison(
            expected: receipt.expectedKg,
            gross: receipt.grossKg,
            tare: receipt.tareKg,
            net: receipt.netKg,
            difference: receipt.differenceKg,
            outsideTolerance: receipt.outsideTolerance,
          ),
          _movement(
              context, 'Qabul qilindi', receipt.receivedBy, receipt.receivedAt),
          AppInfoRow(
            label: 'Qabul ombori',
            value: receipt.warehouse ?? 'Belgilanmagan',
            icon: Icons.warehouse_outlined,
          ),
          if (receipt.outsideTolerance)
            const ListTile(
              leading: Icon(Icons.warning_amber_rounded),
              title: Text(
                  'Qabul qilingan vazn ruxsat etilgan chegaradan farq qiladi'),
            ),
          ListTile(
              subtitle: Text([
            receipt.measurementSource == 'gscale'
                ? 'GScale'
                : 'Qo‘lda kiritilgan',
            if (receipt.note.isNotEmpty) receipt.note,
          ].join(' · '))),
        ],
        if (cycle.resetAt != null)
          _movement(context, 'Bo‘shatildi', cycle.resetBy, cycle.resetAt),
        if (declaredByWorker.length > 1) ...[
          const Divider(),
          const ListTile(title: Text('Ishchilar bo‘yicha jami')),
          for (final total in declaredByWorker.entries)
            ListTile(
              dense: true,
              title: Text(total.key.$2.isEmpty ? 'Ishchi' : total.key.$2),
              trailing: Text(wasteKgLabel(total.value)),
            ),
          const Divider(),
        ],
        if (cycle.entries.isEmpty)
          const ListTile(title: Text('Chiqindi qaydlari yo‘q')),
        for (final entry in cycle.entries)
          ListTile(
            title: Text(entry.actorName.isEmpty ? 'Ishchi' : entry.actorName),
            subtitle: Text([
              if (entry.reason.isNotEmpty) entry.reason,
              if (entry.orderId.isNotEmpty) 'Buyurtma: ${entry.orderId}',
              if (entry.createdAt != null) wasteWhen(context, entry.createdAt),
            ].join(' · ')),
            trailing: Text(wasteKgLabel(entry.kg)),
          ),
      ],
    );
  }

  Widget _movement(
      BuildContext context, String title, String actor, DateTime? at) {
    return ListTile(
      dense: true,
      title: Text(title),
      subtitle: Text([actor, wasteWhen(context, at)]
          .where((value) => value.isNotEmpty)
          .join(' · ')),
    );
  }
}

class WasteWeightComparison extends StatelessWidget {
  const WasteWeightComparison({
    super.key,
    required this.expected,
    required this.gross,
    required this.tare,
    required this.net,
    required this.difference,
    required this.outsideTolerance,
  });

  final double expected, gross, tare, net, difference;
  final bool outsideTolerance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <(String, double)>[
      ('Qayd etilgan vazn', expected),
      ('Quti bilan vazn', gross),
      ('Bo‘sh quti vazni', tare),
      ('Haqiqiy sof vazn', net),
      ('Tafovut', difference),
    ];
    return AppSegmentSurfaceCard(
      elevation: 0,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, kg) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  Text(
                    '${label == 'Tafovut' && kg > 0 ? '+' : ''}${wasteKgLabel(kg)}',
                    style: label == 'Tafovut' && outsideTolerance
                        ? TextStyle(color: theme.colorScheme.error)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
