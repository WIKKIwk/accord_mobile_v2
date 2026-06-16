import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../models/admin_item_group_tree_entry.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';

class AdminRawMaterialRulesScreen extends StatefulWidget {
  const AdminRawMaterialRulesScreen({super.key});

  @override
  State<AdminRawMaterialRulesScreen> createState() =>
      _AdminRawMaterialRulesScreenState();
}

class _AdminRawMaterialRulesScreenState
    extends State<AdminRawMaterialRulesScreen> {
  final _groupsController = TextEditingController();
  late Future<_RawMaterialRulesData> _future;
  List<AdminRawMaterialRule> _rules = const [];
  String _selectedApparatus = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
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
    Navigator.of(context).pushNamedAndRemoveUntil(routeName, (route) => false);
  }

  void _fillGroupsFor(String apparatus) {
    final normalized = apparatus.trim();
    for (final rule in _rules) {
      if (rule.apparatus.trim() == normalized) {
        _groupsController.text = rule.itemGroups.join(', ');
        return;
      }
    }
    _groupsController.clear();
  }

  List<String> _groupsFromInput() {
    return _groupsController.text
        .split(RegExp(r'[,;\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  Future<void> _pickGroups(List<String> options) async {
    if (options.isEmpty || _saving) {
      showAdminTopNotice(context, 'Homashyo guruhlari topilmadi');
      return;
    }
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return _RawMaterialGroupPickerDialog(
          options: options,
          initialSelected: _groupsFromInput(),
        );
      },
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _groupsController.text = selected.join(', ');
    });
  }

  Future<void> _save() async {
    final apparatus = _selectedApparatus.trim();
    final groups = _groupsFromInput();
    if (apparatus.isEmpty || groups.isEmpty || _saving) {
      showAdminTopNotice(context, 'Aparat va homashyo guruhini kiriting');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await MobileApi.instance.adminSaveRawMaterialRule(
        apparatus: apparatus,
        itemGroups: groups,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _rules = [
          for (final rule in _rules)
            if (rule.apparatus.trim() != saved.apparatus.trim()) rule,
          saved,
        ];
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

  @override
  Widget build(BuildContext context) {
    return AppShell(
      drawer: AdminNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.adminRawMaterialRules,
        onNavigate: _openDrawerRoute,
      ),
      title: 'Homashyo qoidalari',
      subtitle: '',
      nativeTopBar: true,
      bottom: const AdminDock(activeTab: AdminDockTab.settings),
      contentPadding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
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
          return ListView(
            padding: EdgeInsets.fromLTRB(0, 6, 0, bottomPadding),
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
                onPickGroups: () => _pickGroups(data.rawMaterialGroups),
                onSave: _save,
              ),
              const SizedBox(height: 12),
              for (final rule in _rules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RuleTile(
                    rule: rule,
                    onTap: () {
                      setState(() {
                        _selectedApparatus = rule.apparatus;
                        _fillGroupsFor(rule.apparatus);
                      });
                    },
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
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey(selectedApparatus),
              initialValue:
                  selectedApparatus.isEmpty ? null : selectedApparatus,
              decoration: const InputDecoration(
                labelText: 'Aparat',
                border: OutlineInputBorder(),
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
              decoration: const InputDecoration(
                labelText: 'Homashyo guruhlari',
                hintText: 'Tanlang',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.arrow_drop_down_rounded),
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
    required this.initialSelected,
  });

  final List<String> options;
  final List<String> initialSelected;

  @override
  State<_RawMaterialGroupPickerDialog> createState() =>
      _RawMaterialGroupPickerDialogState();
}

class _RawMaterialGroupPickerDialogState
    extends State<_RawMaterialGroupPickerDialog> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected.map((item) => item.trim()).toSet();
  }

  void _toggle(String option, bool value) {
    setState(() {
      if (value) {
        _selected.add(option);
      } else {
        _selected.remove(option);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Homashyo guruhlari'),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: 420,
        height: 360,
        child: ListView.builder(
          itemCount: widget.options.length,
          itemBuilder: (context, index) {
            final option = widget.options[index];
            final selected = _selected.contains(option);
            return CheckboxListTile(
              value: selected,
              onChanged: (value) => _toggle(option, value ?? false),
              title: Text(option),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: scheme.primary,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Bekor'),
        ),
        FilledButton(
          onPressed: () {
            final values = _selected.toList(growable: false);
            values.sort(
              (left, right) => left.toLowerCase().compareTo(
                    right.toLowerCase(),
                  ),
            );
            Navigator.of(context).pop(values);
          },
          child: const Text('Tanlash'),
        ),
      ],
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule, required this.onTap});

  final AdminRawMaterialRule rule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.precision_manufacturing_rounded),
        title: Text(rule.apparatus),
        subtitle: Text(rule.itemGroups.join(', ')),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
