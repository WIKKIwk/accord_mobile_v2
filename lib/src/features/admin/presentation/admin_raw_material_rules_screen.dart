import 'admin_raw_material_assignment_screen.dart';
import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/lists/lists.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../models/admin_item_group_tree_entry.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_surface_tab_bar.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';

const double _rawMaterialRulesPanelGap = 4;

enum AdminRawMaterialSettingsTab { rules, requiredMaterial, assignments }

int _rawMaterialSettingsTabIndex(AdminRawMaterialSettingsTab tab) {
  return switch (tab) {
    AdminRawMaterialSettingsTab.rules => 0,
    AdminRawMaterialSettingsTab.requiredMaterial => 1,
    AdminRawMaterialSettingsTab.assignments => 2,
  };
}

class AdminRawMaterialSettingsScreen extends StatefulWidget {
  const AdminRawMaterialSettingsScreen({
    super.key,
    this.initialTab = AdminRawMaterialSettingsTab.rules,
  });

  final AdminRawMaterialSettingsTab initialTab;

  @override
  State<AdminRawMaterialSettingsScreen> createState() =>
      _AdminRawMaterialSettingsScreenState();
}

typedef AdminRawMaterialRulesScreen = AdminRawMaterialSettingsScreen;

class _AdminRawMaterialSettingsScreenState
    extends State<AdminRawMaterialSettingsScreen>
    with SingleTickerProviderStateMixin {
  final _groupsController = TextEditingController();
  late Future<_RawMaterialRulesData> _future;
  late TabController _tabController;
  List<AdminRawMaterialRule> _rules = const [];
  List<AdminRawMaterialRequirementGroup> _selectedRequirementGroups = const [];
  String _selectedApparatus = '';
  bool _selectedRequiresMaterial = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      initialIndex: _rawMaterialSettingsTabIndex(widget.initialTab),
      vsync: this,
    );
    _future = _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _groupsController.dispose();
    super.dispose();
  }

  Future<_RawMaterialRulesData> _load() async {
    final results = await Future.wait<Object>([
      MobileApi.instance.adminWarehouses(parent: 'aparat - A', limit: 300),
      MobileApi.instance.adminRawMaterialRules(),
      MobileApi.instance.adminItemGroupTree(),
    ]);
    final apparatus = results[0] as List<AdminWarehouse>;
    final rules = results[1] as List<AdminRawMaterialRule>;
    final itemGroups = results[2] as List<AdminItemGroupTreeEntry>;
    final rawMaterialGroups = _rawMaterialGroupsFrom(itemGroups);
    _rules = rules;
    if (_selectedApparatus.isEmpty && apparatus.isNotEmpty) {
      _selectedApparatus = apparatus.first.warehouse.trim();
      _fillGroupsFor(_selectedApparatus);
    }
    return _RawMaterialRulesData(
      apparatus: apparatus,
      rules: rules,
      rawMaterialGroups: rawMaterialGroups,
    );
  }

  void _openDrawerRoute(String routeName) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) {
      return;
    }
    AdminDrawerNavigation.openRoute(context, routeName);
  }

  void _fillGroupsFor(String apparatus) {
    final normalized = apparatus.trim();
    final rule = _ruleFor(normalized);
    if (rule != null) {
      _selectedRequirementGroups = _effectiveRequirementGroupsFor(rule);
      _groupsController.text = _requirementGroupsSummary(
        _selectedRequirementGroups,
      );
      _selectedRequiresMaterial = rule.requiresMaterial;
      return;
    }
    _groupsController.clear();
    _selectedRequirementGroups = const [];
    _selectedRequiresMaterial = false;
  }

  AdminRawMaterialRule? _ruleFor(String apparatus) {
    final normalized = apparatus.trim();
    for (final rule in _rules) {
      if (rule.apparatus.trim() == normalized) {
        return rule;
      }
    }
    return null;
  }

  void _replaceRule(AdminRawMaterialRule saved) {
    _rules = [
      for (final rule in _rules)
        if (rule.apparatus.trim() != saved.apparatus.trim()) rule,
      saved,
    ];
  }

  Future<void> _pickGroups(List<String> options) async {
    if (options.isEmpty || _saving) {
      showAdminTopNotice(context, 'Homashyo guruhlari topilmadi');
      return;
    }
    final selected = await showDialog<List<AdminRawMaterialRequirementGroup>>(
      context: context,
      builder: (context) {
        return _RawMaterialGroupPickerDialog(
          options: options,
          initialRequirementGroups: _selectedRequirementGroups,
        );
      },
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _selectedRequirementGroups = selected;
      _groupsController.text = _requirementGroupsSummary(selected);
    });
  }

  Future<void> _save() async {
    final apparatus = _selectedApparatus.trim();
    final requirementGroups = _selectedRequirementGroups;
    final groups = _itemGroupsFromRequirementGroups(requirementGroups);
    if (apparatus.isEmpty || groups.isEmpty || _saving) {
      showAdminTopNotice(context, 'Aparat va homashyo guruhini kiriting');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await MobileApi.instance.adminSaveRawMaterialRule(
        apparatus: apparatus,
        requiresMaterial: _selectedRequiresMaterial,
        itemGroups: groups,
        requirementGroups: requirementGroups,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _replaceRule(saved);
        _selectedRequirementGroups = _effectiveRequirementGroupsFor(saved);
        _groupsController.text = _requirementGroupsSummary(
          _selectedRequirementGroups,
        );
        _selectedRequiresMaterial = saved.requiresMaterial;
      });
      showAdminTopNotice(context, 'Homashyo qoidasi saqlandi');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        error is MobileApiException
            ? error.message
            : 'Homashyo qoidasi saqlanmadi',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _setRequiresMaterial(
    AdminWarehouse apparatus,
    bool requiresMaterial,
  ) async {
    final apparatusName = apparatus.warehouse.trim();
    final rule = _ruleFor(apparatusName);
    if (rule == null || rule.itemGroups.isEmpty || _saving) {
      showAdminTopNotice(context, 'Avval homashyo qoidasi saqlang');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await MobileApi.instance.adminSaveRawMaterialRule(
        apparatus: apparatusName,
        requiresMaterial: requiresMaterial,
        itemGroups: rule.itemGroups,
        requirementGroups: rule.requirementGroups,
      );
      if (!mounted) {
        return;
      }
      if (saved.requiresMaterial != requiresMaterial) {
        showAdminTopNotice(
          context,
          'Backend majburiylikni saqlamadi',
          icon: Icons.error_rounded,
        );
        return;
      }
      setState(() {
        _replaceRule(saved);
        if (_selectedApparatus.trim() == saved.apparatus.trim()) {
          _selectedRequiresMaterial = saved.requiresMaterial;
        }
      });
      showAdminTopNotice(context, 'Majburiylik saqlandi');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        error is MobileApiException ? error.message : 'Majburiylik saqlanmadi',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      drawer: AdminNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.adminRawMaterialSettings,
        onNavigate: _openDrawerRoute,
      ),
      title: 'Homashyo sozlamalari',
      subtitle: '',
      nativeTopBar: true,
      bottom: const AdminDock(activeTab: AdminDockTab.settings),
      contentPadding: EdgeInsets.zero,
      child: FutureBuilder<_RawMaterialRulesData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: AppLoadingIndicator());
          }
          if (snapshot.hasError) {
            return AppRetryState(
              onRetry: () async {
                setState(() => _future = _load());
              },
            );
          }
          final data = snapshot.data!;
          final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 128;
          return Column(
            children: [
              AdminSurfaceTabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(height: 38, text: 'Qoidalar'),
                  Tab(height: 38, text: 'Majburiylik'),
                  Tab(height: 38, text: 'Homashyoni ulash'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    ColoredBox(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          _rawMaterialRulesPanelGap,
                          10,
                          _rawMaterialRulesPanelGap,
                          bottomPadding,
                        ),
                        children: [
                          _RuleEditor(
                            apparatus: data.apparatus,
                            selectedApparatus: _selectedApparatus,
                            rawMaterialGroups: data.rawMaterialGroups,
                            groupsController: _groupsController,
                            saving: _saving,
                            onApparatusChanged: (value) {
                              setState(() {
                                _selectedApparatus = value;
                                _fillGroupsFor(value);
                              });
                            },
                            onPickGroups: () =>
                                _pickGroups(data.rawMaterialGroups),
                            onSave: _save,
                          ),
                          if (_rules.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            M3SegmentSpacedColumn(
                              padding: EdgeInsets.zero,
                              children: [
                                for (var index = 0;
                                    index < _rules.length;
                                    index++)
                                  _RuleTile(
                                    slot: M3SegmentedListGeometry
                                        .standaloneListSlotForIndex(
                                      index,
                                      _rules.length,
                                    ),
                                    rule: _rules[index],
                                    onTap: () {
                                      setState(() {
                                        _selectedApparatus =
                                            _rules[index].apparatus;
                                        _fillGroupsFor(_rules[index].apparatus);
                                      });
                                      _tabController.animateTo(0);
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    _RequiredMaterialsTab(
                      apparatus: data.apparatus,
                      rules: _rules,
                      saving: _saving,
                      bottomPadding: bottomPadding,
                      onChanged: _setRequiresMaterial,
                    ),
                    AdminRawMaterialAssignmentPanel(
                      bottomPadding: bottomPadding,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RawMaterialRulesData {
  const _RawMaterialRulesData({
    required this.apparatus,
    required this.rules,
    required this.rawMaterialGroups,
  });

  final List<AdminWarehouse> apparatus;
  final List<AdminRawMaterialRule> rules;
  final List<String> rawMaterialGroups;
}

List<String> _rawMaterialGroupsFrom(List<AdminItemGroupTreeEntry> entries) {
  final groups = <String>{};
  for (final entry in entries) {
    if (entry.parentItemGroup.trim().toLowerCase() != 'homashyo') {
      continue;
    }
    final name = entry.itemGroupName.trim().isNotEmpty
        ? entry.itemGroupName.trim()
        : entry.name.trim();
    if (name.isNotEmpty) {
      groups.add(name);
    }
  }
  final sorted = groups.toList(growable: false);
  sorted
      .sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
  return sorted;
}

List<AdminRawMaterialRequirementGroup> _effectiveRequirementGroupsFor(
  AdminRawMaterialRule rule,
) {
  if (rule.requirementGroups.isNotEmpty) {
    return [
      for (final group in rule.requirementGroups)
        if (group.name.trim().isNotEmpty)
          AdminRawMaterialRequirementGroup(
            name: group.name.trim(),
            itemGroups: _normalizedUnique([
              group.name,
              ...group.itemGroups,
            ]),
            minRequiredCount: group.minRequiredCount,
          ),
    ];
  }
  return [
    for (final group in rule.itemGroups)
      if (group.trim().isNotEmpty)
        AdminRawMaterialRequirementGroup(
          name: group.trim(),
          itemGroups: [group.trim()],
        ),
  ];
}

List<String> _normalizedUnique(Iterable<String> values) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final value in values) {
    final item = value.trim();
    final key = item.toLowerCase();
    if (item.isEmpty || seen.contains(key)) {
      continue;
    }
    seen.add(key);
    normalized.add(item);
  }
  return normalized;
}

List<String> _itemGroupsFromRequirementGroups(
  List<AdminRawMaterialRequirementGroup> groups,
) {
  return _normalizedUnique([
    for (final group in groups) ...[
      group.name,
      ...group.itemGroups,
    ],
  ]);
}

String _requirementGroupsSummary(
  List<AdminRawMaterialRequirementGroup> groups,
) {
  return groups.map(_requirementGroupSummary).join(', ');
}

String _requirementGroupSummary(AdminRawMaterialRequirementGroup group) {
  final options = _normalizedUnique([group.name, ...group.itemGroups]);
  if (options.length <= 1) {
    return group.name.trim();
  }
  return '${group.name.trim()} (${options.join(' yoki ')})';
}

class _RuleEditor extends StatelessWidget {
  const _RuleEditor({
    required this.apparatus,
    required this.selectedApparatus,
    required this.rawMaterialGroups,
    required this.groupsController,
    required this.saving,
    required this.onApparatusChanged,
    required this.onPickGroups,
    required this.onSave,
  });

  final List<AdminWarehouse> apparatus;
  final String selectedApparatus;
  final List<String> rawMaterialGroups;
  final TextEditingController groupsController;
  final bool saving;
  final ValueChanged<String> onApparatusChanged;
  final VoidCallback onPickGroups;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(M3SegmentedListGeometry.cornerLarge),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey(selectedApparatus),
              initialValue:
                  selectedApparatus.isEmpty ? null : selectedApparatus,
              decoration: appSurfaceInputDecoration(
                context,
                labelText: 'Aparat',
              ),
              items: [
                for (final item in apparatus)
                  DropdownMenuItem(
                    value: item.warehouse.trim(),
                    child: Text(item.warehouse.trim()),
                  ),
              ],
              onChanged: saving || apparatus.isEmpty
                  ? null
                  : (value) {
                      if (value != null) {
                        onApparatusChanged(value);
                      }
                    },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: groupsController,
              readOnly: true,
              onTap: saving ? null : onPickGroups,
              minLines: 1,
              maxLines: 3,
              decoration: appSurfaceInputDecoration(
                context,
                labelText: 'Homashyo guruhlari',
                hintText: 'Tanlang',
                suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RawMaterialGroupPickerDialog extends StatefulWidget {
  const _RawMaterialGroupPickerDialog({
    required this.options,
    required this.initialRequirementGroups,
  });

  final List<String> options;
  final List<AdminRawMaterialRequirementGroup> initialRequirementGroups;

  @override
  State<_RawMaterialGroupPickerDialog> createState() =>
      _RawMaterialGroupPickerDialogState();
}

class _RawMaterialGroupPickerDialogState
    extends State<_RawMaterialGroupPickerDialog> {
  late final Map<String, Set<String>> _selectedOptionsByGroup;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    final optionKeys = {
      for (final option in widget.options) option.trim().toLowerCase(): option,
    };
    _selectedOptionsByGroup = {};
    for (final group in widget.initialRequirementGroups) {
      final name = group.name.trim();
      final option = optionKeys[name.toLowerCase()];
      if (option == null) {
        continue;
      }
      _selectedOptionsByGroup[option] = {
        option,
        for (final item in group.itemGroups)
          if (optionKeys[item.trim().toLowerCase()] != null)
            optionKeys[item.trim().toLowerCase()]!,
      };
    }
  }

  void _toggle(String option, bool value) {
    setState(() {
      if (value) {
        _selectedOptionsByGroup[option] = {option};
      } else {
        _selectedOptionsByGroup.remove(option);
        _expanded.remove(option);
      }
    });
  }

  void _toggleExpanded(String option) {
    setState(() {
      if (_expanded.contains(option)) {
        _expanded.remove(option);
      } else {
        _expanded.add(option);
      }
    });
  }

  void _toggleAlternative(String group, String option, bool value) {
    setState(() {
      final selected =
          _selectedOptionsByGroup.putIfAbsent(group, () => {group});
      if (value) {
        selected.add(option);
      } else {
        selected.remove(option);
      }
    });
  }

  List<AdminRawMaterialRequirementGroup> _selectedGroups() {
    return [
      for (final option in widget.options)
        if (_selectedOptionsByGroup.containsKey(option))
          AdminRawMaterialRequirementGroup(
            name: option,
            itemGroups: [
              option,
              for (final alternative in widget.options)
                if (alternative != option &&
                    (_selectedOptionsByGroup[option]?.contains(alternative) ??
                        false))
                  alternative,
            ],
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      title: const Text('Homashyo guruhlari'),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: 520,
        height: 360,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            M3SegmentSpacedColumn(
              padding: EdgeInsets.zero,
              children: [
                for (var index = 0; index < widget.options.length; index++)
                  _RawMaterialGroupOptionCard(
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index,
                      widget.options.length,
                    ),
                    option: widget.options[index],
                    alternatives: [
                      for (final alternative in widget.options)
                        if (alternative != widget.options[index]) alternative,
                    ],
                    selected: _selectedOptionsByGroup
                        .containsKey(widget.options[index]),
                    expanded: _expanded.contains(widget.options[index]),
                    selectedAlternatives:
                        _selectedOptionsByGroup[widget.options[index]] ??
                            const <String>{},
                    onSelectedChanged: (value) =>
                        _toggle(widget.options[index], value),
                    onExpandedChanged: () =>
                        _toggleExpanded(widget.options[index]),
                    onAlternativeChanged: (alternative, value) =>
                        _toggleAlternative(
                      widget.options[index],
                      alternative,
                      value,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Bekor'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(_selectedGroups());
          },
          child: const Text('Tanlash'),
        ),
      ],
    );
  }
}

class _RawMaterialGroupOptionCard extends StatelessWidget {
  const _RawMaterialGroupOptionCard({
    required this.slot,
    required this.option,
    required this.alternatives,
    required this.selected,
    required this.expanded,
    required this.selectedAlternatives,
    required this.onSelectedChanged,
    required this.onExpandedChanged,
    required this.onAlternativeChanged,
  });

  final M3SegmentVerticalSlot slot;
  final String option;
  final List<String> alternatives;
  final bool selected;
  final bool expanded;
  final Set<String> selectedAlternatives;
  final ValueChanged<bool> onSelectedChanged;
  final VoidCallback onExpandedChanged;
  final void Function(String alternative, bool value) onAlternativeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppSegmentSurfaceCard(
      slot: slot,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                key: Key('raw-material-group-checkbox-$option'),
                value: selected,
                activeColor: scheme.primary,
                onChanged: (value) => onSelectedChanged(value ?? false),
              ),
              Expanded(
                child: Text(
                  option,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                key: Key('raw-material-group-expand-$option'),
                onPressed: onExpandedChanged,
                icon: AnimatedRotation(
                  duration: const Duration(milliseconds: 160),
                  turns: expanded ? 0.5 : 0,
                  child: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Alternativlar',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (alternatives.isEmpty)
                          Text(
                            'Boshqa homashyo guruhi yo‘q',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        else
                          for (final alternative in alternatives)
                            CheckboxListTile(
                              key: Key(
                                'raw-material-alternative-checkbox-$option-$alternative',
                              ),
                              value: selectedAlternatives.contains(alternative),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: scheme.primary,
                              title: Text(alternative),
                              onChanged: (value) => onAlternativeChanged(
                                alternative,
                                value ?? false,
                              ),
                            ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.slot,
    required this.rule,
    required this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final AdminRawMaterialRule rule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppSegmentSurfaceCard(
      slot: slot,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      onTap: onTap,
      child: Row(
        children: [
          SizedBox.square(
            dimension: 30,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.precision_manufacturing_rounded,
                size: 16,
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.apparatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rule.itemGroups.join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rule.requiresMaterial
                      ? 'Homashyo majburiy'
                      : 'Homashyo ixtiyoriy',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _RequiredMaterialsTab extends StatelessWidget {
  const _RequiredMaterialsTab({
    required this.apparatus,
    required this.rules,
    required this.saving,
    required this.bottomPadding,
    required this.onChanged,
  });

  final List<AdminWarehouse> apparatus;
  final List<AdminRawMaterialRule> rules;
  final bool saving;
  final double bottomPadding;
  final void Function(AdminWarehouse apparatus, bool requiresMaterial)
      onChanged;

  AdminRawMaterialRule? _ruleFor(AdminWarehouse apparatus) {
    final normalized = apparatus.warehouse.trim();
    for (final rule in rules) {
      if (rule.apparatus.trim() == normalized) {
        return rule;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(12, 10, 12, bottomPadding),
      itemCount: apparatus.length,
      itemBuilder: (context, index) {
        final item = apparatus[index];
        final rule = _ruleFor(item);
        final hasRule = rule != null && rule.itemGroups.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _RequiredMaterialTile(
            apparatus: item,
            rule: rule,
            enabled: hasRule && !saving,
            onChanged: onChanged,
          ),
        );
      },
    );
  }
}

class _RequiredMaterialTile extends StatelessWidget {
  const _RequiredMaterialTile({
    required this.apparatus,
    required this.rule,
    required this.enabled,
    required this.onChanged,
  });

  final AdminWarehouse apparatus;
  final AdminRawMaterialRule? rule;
  final bool enabled;
  final void Function(AdminWarehouse apparatus, bool requiresMaterial)
      onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = rule?.itemGroups.join(', ') ?? '';
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        value: rule?.requiresMaterial ?? false,
        onChanged: enabled ? (value) => onChanged(apparatus, value) : null,
        secondary: const Icon(Icons.fact_check_rounded),
        title: Text(apparatus.warehouse.trim()),
        subtitle: Text(
          groups.isEmpty ? 'Avval homashyo guruhi tanlang' : groups,
        ),
      ),
    );
  }
}
