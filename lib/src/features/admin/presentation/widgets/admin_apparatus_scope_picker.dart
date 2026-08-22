import '../../../shared/models/app_models.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

class AdminApparatusScopePicker extends StatelessWidget {
  const AdminApparatusScopePicker({
    super.key,
    required this.apparatus,
    required this.selected,
    required this.onChanged,
  });

  final List<AdminApparatus> apparatus;
  final Set<String> selected;
  final void Function(String apparatusId, bool checked) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (apparatus.isEmpty) {
      return Text(
        l10n.adminText('scope.empty'),
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.adminText('scope.allowed'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        for (final item in apparatus)
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: item.id.isNotEmpty && selected.contains(item.id),
              title: Text(item.name),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: item.id.isEmpty
                  ? null
                  : (value) => onChanged(item.id, value == true),
            ),
          ),
      ],
    );
  }
}
