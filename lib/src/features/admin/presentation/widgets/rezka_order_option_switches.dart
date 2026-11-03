import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

class RezkaOrderOptionSwitches extends StatelessWidget {
  const RezkaOrderOptionSwitches({
    super.key,
    required this.duplicateLabels,
    required this.includeBobina,
    required this.onDuplicateLabelsChanged,
    required this.onIncludeBobinaChanged,
  });

  final bool duplicateLabels;
  final bool includeBobina;
  final ValueChanged<bool>? onDuplicateLabelsChanged;
  final ValueChanged<bool>? onIncludeBobinaChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile.adaptive(
            key: const ValueKey('calculate-duplicate-rezka-labels'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.adminText('calculate.duplicate_rezka_labels')),
            subtitle:
                Text(l10n.adminText('calculate.duplicate_rezka_labels_hint')),
            value: duplicateLabels,
            onChanged: onDuplicateLabelsChanged,
          ),
          SwitchListTile.adaptive(
            key: const ValueKey('calculate-include-bobina-in-net'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.adminText('calculate.include_bobina_in_net')),
            subtitle:
                Text(l10n.adminText('calculate.include_bobina_in_net_hint')),
            value: includeBobina,
            onChanged: onIncludeBobinaChanged,
          ),
        ],
      ),
    );
  }
}
