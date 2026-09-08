import 'package:flutter/material.dart';

import '../models/raw_material_split_models.dart';

class RawMaterialSplitResultView extends StatelessWidget {
  const RawMaterialSplitResultView({
    required this.result,
    required this.busy,
    required this.onReprint,
    required this.onReprintAll,
    super.key,
  });

  final RawSplitResult result;
  final bool busy;
  final ValueChanged<RawSplitRoll> onReprint;
  final VoidCallback onReprintAll;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(
          '${rawSplitDisplay(result.sourceKg)} → ${rawSplitDisplay(result.outputKg)} kg',
        ),
        subtitle: Text(
          '${result.outputs.length} rulon · ${rawSplitDisplay(result.wasteKg)} kg chiqindi',
        ),
        children: [
          SelectableText(result.source.barcode),
          Text('Ombor: ${result.source.warehouse}'),
          if (result.createdAt != null) Text(result.createdAt!),
          for (final output in result.outputs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${rawSplitDisplay(output.kg)} kg · ${rawSplitDisplay(output.widthMm)} mm · ${rawSplitDisplay(output.micron)} mkm',
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(output.labelName),
                  if (output.grossKg != null)
                    Text('Brutto: ${rawSplitDisplay(output.grossKg!)} kg · '
                        'Babina: ${rawSplitDisplay(output.bobinaKg!)} kg'),
                  SelectableText(output.barcode),
                ],
              ),
              trailing: IconButton(
                tooltip: 'Shu rulonni qayta chop etish',
                onPressed: busy ? null : () => onReprint(output),
                icon: const Icon(Icons.print_outlined),
              ),
            ),
          TextButton.icon(
            onPressed: busy ? null : onReprintAll,
            icon: const Icon(Icons.print_outlined),
            label: const Text('Barchasini qayta chop etish'),
          ),
        ],
      ),
    );
  }
}
