import '../../../../core/api/mobile_api.dart';
import '../../../shared/models/app_models.dart';
import '../../logic/admin_aparatchi_assignment.dart';
import 'admin_apparatus_scope_picker.dart';
import 'dart:async';

import 'package:flutter/material.dart';

class AdminAparatchiApparatusCard extends StatefulWidget {
  const AdminAparatchiApparatusCard({
    super.key,
    required this.customerRef,
    required this.onChanged,
    this.materialTaminotchi = false,
  });

  final String customerRef;
  final VoidCallback onChanged;
  final bool materialTaminotchi;

  @override
  State<AdminAparatchiApparatusCard> createState() =>
      _AdminAparatchiApparatusCardState();
}

class _AdminAparatchiApparatusCardState
    extends State<AdminAparatchiApparatusCard> {
  bool _loading = true;
  bool _saving = false;
  Object? _error;
  List<AdminApparatus> _apparatus = const [];
  AdminRoleAssignment? _assignment;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = <String>{};
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        MobileApi.instance.adminRoleAssignments(),
        MobileApi.instance.adminApparatus(limit: 200),
      ]);
      final assignments = results[0] as List<AdminRoleAssignment>;
      final apparatus = results[1] as List<AdminApparatus>;
      final assignment = widget.materialTaminotchi
          ? adminAssignmentForPrincipalRole(
              assignments,
              widget.customerRef,
              UserRole.materialTaminotchi,
            )
          : adminAssignmentForCustomerRef(
              assignments,
              widget.customerRef,
            );
      if (!mounted) {
        return;
      }
      setState(() {
        _assignment = assignment;
        _apparatus = apparatus;
        _selected = assignment?.assignedApparatus.toSet() ?? <String>{};
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    await _saveSelection(_selected);
  }

  Future<bool> _saveSelection(Set<String> selected) async {
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kamida bitta aparat tanlang')),
      );
      return false;
    }
    final assignment = _assignment;
    if (widget.materialTaminotchi && assignment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Material ta’minotchi role’i topilmadi')),
      );
      return false;
    }
    setState(() {
      _selected = Set<String>.of(selected);
      _saving = true;
    });
    try {
      await MobileApi.instance.adminUpsertRoleAssignment(
        widget.materialTaminotchi
            ? adminMaterialTaminotchiAssignmentUpsert(
                assignment: assignment!,
                assignedApparatus: _selected.toList(growable: false)..sort(),
              )
            : adminAparatchiAssignmentUpsert(
                principalRef: widget.customerRef,
                assignedApparatus: _selected.toList(growable: false)..sort(),
              ),
      );
      widget.onChanged();
      if (!mounted) {
        return true;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Aparatlar saqlandi')));
      await _load();
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Aparatlar saqlanmadi: $error')));
      return false;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openMaterialApparatusSheet() async {
    if (_saving || _assignment == null) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminMaterialApparatusSheet(
        apparatus: _apparatus,
        selected: _selected,
        onSave: _saveSelection,
      ),
    );
  }

  Widget _buildMaterialApparatusField() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (_loading) {
      return const _MaterialApparatusField(
        title: 'Material ta’minotchi aparatlari',
        subtitle: 'Yuklanmoqda...',
        trailing: Icon(Icons.hourglass_top_rounded),
      );
    }
    if (_error != null) {
      return _MaterialApparatusField(
        title: 'Material ta’minotchi aparatlari',
        subtitle: 'Yuklanmadi. Qayta urinib ko‘ring.',
        trailing: IconButton(
          key: const ValueKey('admin-material-apparatus-retry'),
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Qayta urinish',
        ),
      );
    }
    if (_assignment?.principalRole != UserRole.materialTaminotchi) {
      return const SizedBox.shrink();
    }
    final selectedCount = _selected.length;
    return _MaterialApparatusField(
      key: const ValueKey('admin-material-apparatus-field'),
      title: 'Material ta’minotchi aparatlari',
      subtitle: selectedCount == 0
          ? 'Aparat tanlanmagan'
          : '$selectedCount ta apparat tanlangan',
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: scheme.onSurfaceVariant,
      ),
      onTap: _openMaterialApparatusSheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.materialTaminotchi) {
      return _buildMaterialApparatusField();
    }
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Aparatlar yuklanmadi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _load,
                child: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      );
    }
    if (widget.materialTaminotchi
        ? _assignment?.principalRole != UserRole.materialTaminotchi
        : !adminIsAparatchiAssignment(_assignment)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final title = widget.materialTaminotchi
        ? 'Material ta’minotchi aparatlari'
        : 'Aparatchi aparatlari';
    final description = widget.materialTaminotchi
        ? 'Homashyo ulash filtrida faqat tanlangan aparatlar ko‘rinadi.'
        : 'Bu foydalanuvchi faqat tanlangan aparat ketma-ketligini ko‘radi.';
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            AdminApparatusScopePicker(
              apparatus: _apparatus,
              selected: _selected,
              onChanged: (apparatusName, checked) {
                setState(() {
                  if (checked) {
                    _selected.add(apparatusName);
                  } else {
                    _selected.remove(apparatusName);
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saqlanmoqda...' : 'Aparatlarni saqlash'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialApparatusField extends StatelessWidget {
  const _MaterialApparatusField({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.precision_manufacturing_outlined),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }
}

class _AdminMaterialApparatusSheet extends StatefulWidget {
  const _AdminMaterialApparatusSheet({
    required this.apparatus,
    required this.selected,
    required this.onSave,
  });

  final List<AdminApparatus> apparatus;
  final Set<String> selected;
  final Future<bool> Function(Set<String> selected) onSave;

  @override
  State<_AdminMaterialApparatusSheet> createState() =>
      _AdminMaterialApparatusSheetState();
}

class _AdminMaterialApparatusSheetState
    extends State<_AdminMaterialApparatusSheet> {
  late final Set<String> _selected = Set<String>.of(widget.selected);
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    final saved = await widget.onSave(Set<String>.of(_selected));
    if (!mounted) {
      return;
    }
    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Material(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Material ta’minotchi aparatlari',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(
                    'Homashyo ulash filtrida faqat tanlangan apparatlar ko‘rinadi.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AdminApparatusScopePicker(
                    apparatus: widget.apparatus,
                    selected: _selected,
                    onChanged: (apparatusName, checked) {
                      setState(() {
                        if (checked) {
                          _selected.add(apparatusName);
                        } else {
                          _selected.remove(apparatusName);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('admin-material-apparatus-save'),
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving ? 'Saqlanmoqda...' : 'Aparatlarni saqlash',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
