import 'package:flutter/material.dart';
import '../api/mobile_api.dart';
import '../formatters/quantity_formatters.dart';
import '../localization/app_localizations.dart';

/// Server-authoritative product weights, excluding the pallet itself.
class PaddonWeightTotals extends StatelessWidget {
  const PaddonWeightTotals({super.key, required this.paddon});
  final AdminPaddon paddon;

  @override
  Widget build(BuildContext context) {
    String weight(double? kg) => kg == null || !kg.isFinite || kg < 0
        ? '—'
        : '${formatQuantity(kg, decimalPlaces: 6, trimTrailingZeros: true)} kg';
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columnWidth = width < 320 ? width : (width - 16) / 2;
      return Wrap(spacing: 16, runSpacing: 8, children: [
        for (final entry in [
          (
            'worker.paddon.total_gross',
            paddon.totalGrossKg,
            'paddon-total-gross'
          ),
          ('worker.paddon.total_net', paddon.totalNetKg, 'paddon-total-net'),
        ])
          SizedBox(
              width: columnWidth,
              child: Text(
                '${context.l10n.productionText(entry.$1)}: ${weight(entry.$2)}',
                key: ValueKey(entry.$3),
                softWrap: true,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              )),
      ]);
    });
  }
}
