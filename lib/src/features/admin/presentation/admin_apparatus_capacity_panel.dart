import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/models/app_models.dart';
import '../logic/canonical_apparatus_display.dart';
import '../../admin/models/production_map_models.dart';
import 'widgets/admin_top_notice.dart';

part 'admin_apparatus_capacity_panel__AdminApparatusCapacityPanelState_methods_01.dart';
part 'admin_apparatus_capacity_panel_widgets_part_01.dart';

class _AdminApparatusCapacityPanelState
    extends State<AdminApparatusCapacityPanel> {
  final TextEditingController _capacitySlots = TextEditingController(text: '1');
  final TextEditingController _setupMinutes = TextEditingController(text: '0');
  final TextEditingController _cleanupMinutes = TextEditingController(
    text: '0',
  );
  final TextEditingController _efficiency = TextEditingController(text: '100');
  final TextEditingController _workingWindows = TextEditingController();
  final TextEditingController _capabilities = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _orderId = TextEditingController();
  final TextEditingController _duration = TextEditingController(text: '60');
  final TextEditingController _requirements = TextEditingController();
  final TextEditingController _scheduleReason = TextEditingController();
  final TextEditingController _downtimeHours = TextEditingController(text: '1');
  final TextEditingController _downtimeReason = TextEditingController();

  AdminApparatusCapacitySnapshot _snapshot =
      const AdminApparatusCapacitySnapshot();
  List<ProductionMapSaved> _orders = const [];
  String? _selectedApparatusId;
  DateTime _scheduleStart = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  bool _finiteCapacity = true;
  bool _scheduleWithAlternatives = true;
  String? _error;

  AdminApparatus? get _selectedApparatus {
    for (final item in widget.apparatus) {
      if (item.id == _selectedApparatusId) return item;
    }
    return widget.apparatus.isEmpty ? null : widget.apparatus.first;
  }

  AdminApparatusCapacityProfile? get _selectedProfile {
    final apparatus = _selectedApparatus;
    if (apparatus == null) return null;
    for (final profile in _snapshot.profiles) {
      if (profile.apparatusId == apparatus.id) {
        return profile;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.apparatus.isNotEmpty) {
      _selectedApparatusId = widget.apparatus.first.id;
    }
    _load();
  }

  @override
  void dispose() {
    _capacitySlots.dispose();
    _setupMinutes.dispose();
    _cleanupMinutes.dispose();
    _efficiency.dispose();
    _workingWindows.dispose();
    _capabilities.dispose();
    _notes.dispose();
    _orderId.dispose();
    _duration.dispose();
    _requirements.dispose();
    _scheduleReason.dispose();
    _downtimeHours.dispose();
    _downtimeReason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: FilledButton.tonalIcon(
          onPressed: () => _load(),
          icon: const Icon(Icons.refresh),
          label: Text(_error!),
        ),
      );
    }
    final selected = _selectedApparatus;
    final reservations = _snapshot.reservations
        .where(
          (reservation) =>
              selected == null || reservation.apparatusId == selected.id,
        )
        .toList(growable: false);
    final downtimes = _snapshot.downtimes
        .where(
          (downtime) => selected == null || downtime.apparatusId == selected.id,
        )
        .toList(growable: false);
    return ColoredBox(
      color: AppTheme.shellStart(context),
      child: ListView(
        padding: EdgeInsets.fromLTRB(8, 8, 8, widget.bottomPadding),
        children: [
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.adminText('capacity.profile_title'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.adminText('capacity.profile_description'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                if (widget.showApparatusSelector) ...[
                  DropdownButtonFormField<String>(
                    initialValue: selected?.id,
                    decoration: _decoration(
                      l10n.adminText('capacity.apparatus'),
                    ),
                    items: [
                      for (final item in widget.apparatus)
                        DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedApparatusId = value);
                      _applySelectedProfile();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _capacitySlots,
                        keyboardType: TextInputType.number,
                        decoration: _decoration(
                          l10n.adminText('capacity.parallel_slots'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _efficiency,
                        keyboardType: TextInputType.number,
                        decoration: _decoration(
                          l10n.adminText('capacity.efficiency'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _setupMinutes,
                        keyboardType: TextInputType.number,
                        decoration: _decoration(
                          l10n.adminText('capacity.setup_minutes'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _cleanupMinutes,
                        keyboardType: TextInputType.number,
                        decoration: _decoration(
                          l10n.adminText('capacity.cleanup_minutes'),
                        ),
                      ),
                    ),
                  ],
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _finiteCapacity,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _finiteCapacity = value),
                  title: Text(l10n.adminText('capacity.finite_title')),
                  subtitle: Text(l10n.adminText('capacity.finite_description')),
                ),
                TextField(
                  controller: _workingWindows,
                  maxLines: 2,
                  decoration: _decoration(
                    l10n.adminText('capacity.working_windows'),
                  ).copyWith(
                    helperText: l10n.adminText(
                      'capacity.working_windows_help',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _capabilities,
                  maxLines: 2,
                  readOnly: true,
                  decoration: _decoration(
                    l10n.adminText('capacity.capabilities'),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  readOnly: true,
                  decoration: _decoration(l10n.adminText('capacity.notes')),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed:
                        selected == null || _saving ? null : _saveProfile,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(l10n.adminText('capacity.save_profile')),
                  ),
                ),
              ],
            ),
          ),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.adminText('capacity.schedule_title'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue:
                      _orders.any((item) => item.map.id == _orderId.text)
                          ? _orderId.text
                          : null,
                  decoration: _decoration(l10n.adminText('capacity.order')),
                  items: [
                    for (final item in _orders)
                      DropdownMenuItem(
                        value: item.map.id,
                        child: Text(
                          '${item.map.orderNumber.trim().isEmpty ? item.map.id : item.map.orderNumber} • ${item.map.title}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _orderId.text = value ?? ''),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _scheduleWithAlternatives,
                  onChanged: _saving
                      ? null
                      : (value) =>
                          setState(() => _scheduleWithAlternatives = value),
                  title: Text(l10n.adminText('capacity.alternatives_title')),
                  subtitle: Text(
                    _scheduleCandidates().isEmpty
                        ? l10n.adminText('capacity.alternatives_none')
                        : l10n.adminText('capacity.alternatives_hint'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _duration,
                        keyboardType: TextInputType.number,
                        decoration: _decoration(
                          l10n.adminText('capacity.duration'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickScheduleStart,
                        child: Text(
                          '${l10n.adminText('capacity.start')}\n${_formatUnix(_scheduleStart.millisecondsSinceEpoch ~/ 1000)}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _requirements,
                  decoration: _decoration(
                    l10n.adminText('capacity.requirements'),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _scheduleReason,
                  decoration: _decoration(
                    l10n.adminText('capacity.reason_priority'),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed:
                        selected == null || _saving ? null : _scheduleOrder,
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(l10n.adminText('capacity.add_schedule')),
                  ),
                ),
              ],
            ),
          ),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.adminText('capacity.reservations_title'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                if (reservations.isEmpty)
                  Text(
                    l10n.adminText('capacity.reservations_empty'),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  )
                else
                  for (final reservation in reservations)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        reservation.status == 'cancelled'
                            ? Icons.event_busy_outlined
                            : Icons.event_available_outlined,
                      ),
                      title: Text(
                        '${reservation.orderId} • '
                        '${canonicalApparatusDisplayLabel(
                          reservation.apparatusId,
                          widget.apparatus,
                        )}',
                      ),
                      subtitle: Text(
                        '${_formatUnix(reservation.startsAtUnix)} — ${_formatUnix(reservation.endsAtUnix)} • ${reservation.status}',
                      ),
                      trailing: reservation.status == 'planned'
                          ? IconButton(
                              tooltip: l10n.adminText('capacity.cancel'),
                              onPressed: () => _cancelReservation(reservation),
                              icon: const Icon(Icons.cancel_outlined),
                            )
                          : null,
                    ),
              ],
            ),
          ),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.adminText('capacity.downtime_title'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.adminText('action.save'),
                      onPressed: _addDowntime,
                      icon: const Icon(Icons.add_task_outlined),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _downtimeHours,
                        keyboardType: TextInputType.number,
                        decoration: _decoration(
                          l10n.adminText('capacity.hours'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _downtimeReason,
                        decoration: _decoration(
                          l10n.adminText('capacity.reason'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final downtime in downtimes.take(8))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.build_circle_outlined),
                    title: Text(
                      '${canonicalApparatusDisplayLabel(
                        downtime.apparatusId,
                        widget.apparatus,
                      )} • ${downtime.reason}',
                    ),
                    subtitle: Text(
                      '${_formatUnix(downtime.startsAtUnix)} — ${_formatUnix(downtime.endsAtUnix)}',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
