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
  });

  final String customerRef;
  final VoidCallback onChanged;

  @override
  State<AdminAparatchiApparatusCard> createState() =>
      _AdminAparatchiApparatusCardState();
}

class _AdminAparatchiApparatusCardState extends State<AdminAparatchiApparatusCard> {
  bool _loading = true;
  bool _saving = false;
  Object? _error;
  List<AdminWarehouse> _apparatus = const [];
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
        MobileApi.instance.adminWarehouses(parent: 'aparat - A', limit: 200),
      ]);
      final assignments = results[0] as List<AdminRoleAssignment>;
      final apparatus = results[1] as List<AdminWarehouse>;
      final assignment =
          adminAssignmentForCustomerRef(assignments, widget.customerRef);
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
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kamida bitta aparat tanlang')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await MobileApi.instance.adminUpsertRoleAssignment(
        adminAparatchiAssignmentUpsert(
          principalRef: widget.customerRef,
          assignedApparatus: _selected.toList(growable: false)..sort(),
        ),
      );
      widget.onChanged();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aparatlar saqlandi')),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aparatlar saqlanmadi: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              OutlinedButton(onPressed: _load, child: const Text('Qayta urinish')),
            ],
          ),
        ),
      );
    }
    if (!adminIsAparatchiAssignment(_assignment)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Aparatchi aparatlari',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Bu foydalanuvchi faqat tanlangan aparat ketma-ketligini ko‘radi.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            AdminApparatusScopePicker(
              apparatus: _apparatus,
              selected: _selected,
              onChanged: (warehouse, checked) {
                setState(() {
                  if (checked) {
                    _selected.add(warehouse);
                  } else {
                    _selected.remove(warehouse);
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
