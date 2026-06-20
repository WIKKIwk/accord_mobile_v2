import '../../../shared/models/app_models.dart';
import 'package:flutter/material.dart';

class AdminApparatusScopePicker extends StatelessWidget {
  const AdminApparatusScopePicker({
    super.key,
    required this.apparatus,
    required this.selected,
    required this.onChanged,
  });

  final List<AdminWarehouse> apparatus;
  final Set<String> selected;
  final void Function(String warehouse, bool checked) onChanged;

  @override
  Widget build(BuildContext context) {
    if (apparatus.isEmpty) {
      return Text(
        'Aparat topilmadi',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ruxsat berilgan apparatlar',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        for (final item in apparatus)
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: selected.contains(item.warehouse),
              title: Text(item.warehouse),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) => onChanged(item.warehouse, value == true),
            ),
          ),
      ],
    );
  }
}
