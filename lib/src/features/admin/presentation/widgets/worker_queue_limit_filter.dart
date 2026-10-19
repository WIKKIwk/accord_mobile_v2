import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/production/worker_queue_limit_store.dart';
import 'admin_expandable_filter_chip.dart';

class WorkerQueueLimitFilter extends StatefulWidget {
  const WorkerQueueLimitFilter({
    super.key,
    required this.limit,
    required this.onChanged,
  });

  final int limit;
  final ValueChanged<int> onChanged;

  @override
  State<WorkerQueueLimitFilter> createState() => _WorkerQueueLimitFilterState();
}

class _WorkerQueueLimitFilterState extends State<WorkerQueueLimitFilter> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final label = switch (language) {
      'ru' => 'Показывать',
      'en' => 'Show',
      _ => 'Ko‘rsatish',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: AdminExpandableFilterChip<int>(
        chipKey: const ValueKey('worker-queue-limit'),
        optionKeyPrefix: 'worker-queue-limit',
        label: label,
        emptyLabel: '',
        icon: Icons.format_list_numbered_rounded,
        selectedValue: widget.limit,
        options: [
          for (final count in WorkerQueueLimitStore.choices)
            AdminFilterChipOption(
              value: count,
              label: count == WorkerQueueLimitStore.allLimit
                  ? switch (language) {
                      'ru' => 'Все',
                      'en' => 'All',
                      _ => 'Barchasi',
                    }
                  : context.l10n
                      .qolipText('tasks.count', values: {'count': count}),
            ),
        ],
        expanded: _expanded,
        onToggle: () => setState(() => _expanded = !_expanded),
        onSelect: (value) {
          setState(() => _expanded = false);
          widget.onChanged(value);
        },
        padding: EdgeInsets.zero,
      ),
    );
  }
}
