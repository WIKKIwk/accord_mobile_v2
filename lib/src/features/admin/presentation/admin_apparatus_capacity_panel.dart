import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/models/app_models.dart';
import '../../admin/models/production_map_models.dart';
import 'widgets/admin_top_notice.dart';

class AdminApparatusCapacityPanel extends StatefulWidget {
  const AdminApparatusCapacityPanel({
    super.key,
    required this.apparatus,
    required this.bottomPadding,
  });

  final List<AdminApparatus> apparatus;
  final double bottomPadding;

  @override
  State<AdminApparatusCapacityPanel> createState() =>
      _AdminApparatusCapacityPanelState();
}

class _AdminApparatusCapacityPanelState
    extends State<AdminApparatusCapacityPanel> {
  final TextEditingController _capacitySlots = TextEditingController(text: '1');
  final TextEditingController _setupMinutes = TextEditingController(text: '0');
  final TextEditingController _cleanupMinutes =
      TextEditingController(text: '0');
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
      if (profile.apparatusId == apparatus.id ||
          profile.apparatus.toLowerCase() == apparatus.name.toLowerCase()) {
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

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<Object>([
        MobileApi.instance.adminApparatusCapacitySnapshot(),
        MobileApi.instance.adminProductionMaps(),
      ]);
      if (!mounted) return;
      setState(() {
        _snapshot = results[0] as AdminApparatusCapacitySnapshot;
        _orders = results[1] as List<ProductionMapSaved>;
        _loading = false;
        _error = null;
      });
      _applySelectedProfile();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Aparat quvvati yuklanmadi';
      });
    }
  }

  void _applySelectedProfile() {
    final profile = _selectedProfile;
    final apparatus = _selectedApparatus;
    if (apparatus == null) return;
    _capacitySlots.text = '${profile?.capacitySlots ?? 1}';
    _setupMinutes.text = '${profile?.setupMinutes ?? 0}';
    _cleanupMinutes.text = '${profile?.cleanupMinutes ?? 0}';
    _efficiency.text = '${profile?.efficiencyPercent ?? 100}';
    _finiteCapacity = profile?.finiteCapacity ?? true;
    _workingWindows.text = _formatWorkingWindows(
      profile?.workingWindows ?? const [],
    );
    final masterCapabilities = apparatus.capabilityProfiles.isEmpty
        ? apparatus.capabilities
            .map((capability) => MapEntry<String, int>(capability, 1))
        : apparatus.capabilityProfiles.map(
            (profile) => MapEntry<String, int>(profile.code, profile.level),
          );
    final capabilities = profile?.capabilityLevels.entries.map((entry) {
          final level = entry.value <= 1 ? '' : ':${entry.value}';
          return '${entry.key}$level';
        }).toList() ??
        masterCapabilities.map((entry) {
          final level = entry.value <= 1 ? '' : ':${entry.value}';
          return '${entry.key}$level';
        }).toList(growable: false);
    _capabilities.text = capabilities.join(', ');
    _notes.text = profile?.notes ?? '';
  }

  List<MapEntry<String, int>> _parseCapabilities(String raw) {
    final result = <String, int>{};
    for (final token in raw.split(RegExp(r'[,;\n]'))) {
      final parts = token.trim().split(':');
      final code = parts.first.trim().toLowerCase();
      if (code.isEmpty) continue;
      final level = parts.length > 1 ? int.tryParse(parts[1].trim()) : null;
      result[code] = (level ?? 1).clamp(1, 100);
    }
    return result.entries.toList(growable: false);
  }

  bool _workingWindowsInputIsValid(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return true;
    final windowsByWeekday = <int, List<List<int>>>{};
    final pattern = RegExp(
      r'^\s*([1-7])\s*:\s*(\d{1,4})\s*-\s*(\d{1,4})\s*$',
    );
    for (final token in normalized.split(RegExp(r'[;\n]'))) {
      final match = pattern.firstMatch(token);
      if (match == null) return false;
      final weekday = int.parse(match.group(1)!);
      final startMinute = int.parse(match.group(2)!);
      final endMinute = int.parse(match.group(3)!);
      if (startMinute < 0 || endMinute > 1440 || startMinute >= endMinute) {
        return false;
      }
      windowsByWeekday
          .putIfAbsent(weekday, () => <List<int>>[])
          .add([startMinute, endMinute]);
    }
    for (final windows in windowsByWeekday.values) {
      windows.sort((left, right) => left.first.compareTo(right.first));
      for (var index = 1; index < windows.length; index++) {
        if (windows[index].first < windows[index - 1].last) {
          return false;
        }
      }
    }
    return true;
  }

  List<AdminApparatusWorkingWindow> _parseWorkingWindows(String raw) {
    if (raw.trim().isEmpty) return const [];
    final pattern = RegExp(
      r'^\s*([1-7])\s*:\s*(\d{1,4})\s*-\s*(\d{1,4})\s*$',
    );
    return [
      for (final token in raw.trim().split(RegExp(r'[;\n]')))
        if (pattern.firstMatch(token) case final match?)
          AdminApparatusWorkingWindow(
            weekday: int.parse(match.group(1)!),
            startMinute: int.parse(match.group(2)!),
            endMinute: int.parse(match.group(3)!),
          ),
    ];
  }

  String _formatWorkingWindows(List<AdminApparatusWorkingWindow> windows) {
    return windows
        .map(
          (window) =>
              '${window.weekday}:${window.startMinute}-${window.endMinute}',
        )
        .join('; ');
  }

  List<AdminApparatusCapabilityRequirement> _parseRequirements() {
    return [
      for (final entry in _parseCapabilities(_requirements.text))
        AdminApparatusCapabilityRequirement(
          code: entry.key,
          minLevel: entry.value,
        ),
    ];
  }

  Future<void> _saveProfile() async {
    final apparatus = _selectedApparatus;
    if (apparatus == null || _saving) return;
    final slots = int.tryParse(_capacitySlots.text.trim());
    final setup = int.tryParse(_setupMinutes.text.trim());
    final cleanup = int.tryParse(_cleanupMinutes.text.trim());
    final efficiency = int.tryParse(_efficiency.text.trim());
    if (slots == null ||
        setup == null ||
        cleanup == null ||
        efficiency == null) {
      showAdminTopNotice(context, 'Quvvat qiymatlarini to‘g‘ri kiriting');
      return;
    }
    if (!_workingWindowsInputIsValid(_workingWindows.text)) {
      showAdminTopNotice(
        context,
        'Ish vaqti 1:480-1020;2:480-1020 ko‘rinishida bo‘lsin',
      );
      return;
    }
    final capabilityEntries = _parseCapabilities(_capabilities.text);
    setState(() => _saving = true);
    try {
      await MobileApi.instance.adminSaveApparatusCapacityProfile(
        AdminApparatusCapacityProfile(
          apparatusId: apparatus.id,
          apparatus: apparatus.name,
          capacitySlots: slots,
          setupMinutes: setup,
          cleanupMinutes: cleanup,
          efficiencyPercent: efficiency,
          finiteCapacity: _finiteCapacity,
          workingWindows: _parseWorkingWindows(_workingWindows.text),
          capabilities: [for (final entry in capabilityEntries) entry.key],
          capabilityLevels: {
            for (final entry in capabilityEntries) entry.key: entry.value,
          },
          notes: _notes.text,
        ),
      );
      await _load(showLoading: false);
      if (mounted) showAdminTopNotice(context, 'Aparat quvvati saqlandi');
    } catch (error) {
      if (mounted) showAdminTopNotice(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _scheduleOrder() async {
    final apparatus = _selectedApparatus;
    final orderId = _orderId.text.trim();
    final duration = int.tryParse(_duration.text.trim());
    if (apparatus == null ||
        orderId.isEmpty ||
        duration == null ||
        duration <= 0) {
      showAdminTopNotice(context, 'Order va davomiylikni kiriting');
      return;
    }
    setState(() => _saving = true);
    try {
      await MobileApi.instance.adminScheduleApparatusOrder(
        orderId: orderId,
        apparatusId: apparatus.id,
        apparatus: apparatus.name,
        earliestStartUnix: _scheduleStart.millisecondsSinceEpoch ~/ 1000,
        durationMinutes: duration,
        source: 'admin_capacity_panel',
        reason: _scheduleReason.text,
        capabilityRequirements: _parseRequirements(),
        idempotencyKey:
            'admin:$orderId:${apparatus.id}:${_scheduleStart.millisecondsSinceEpoch}',
      );
      await _load(showLoading: false);
      if (mounted) showAdminTopNotice(context, 'Order jadvalga qo‘yildi');
    } catch (error) {
      if (mounted) showAdminTopNotice(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancelReservation(
    AdminApparatusScheduleReservation reservation,
  ) async {
    try {
      await MobileApi.instance.adminCancelApparatusScheduleReservation(
        reservationId: reservation.reservationId,
        reason: 'Admin jadvaldan bekor qildi',
      );
      await _load(showLoading: false);
    } catch (error) {
      if (mounted) showAdminTopNotice(context, _errorMessage(error));
    }
  }

  Future<void> _pickScheduleStart() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      initialDate: _scheduleStart,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduleStart),
    );
    if (time == null) return;
    setState(() {
      _scheduleStart = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _addDowntime() async {
    final apparatus = _selectedApparatus;
    final hours = double.tryParse(_downtimeHours.text.trim());
    final reason = _downtimeReason.text.trim();
    if (apparatus == null || hours == null || hours <= 0 || reason.isEmpty) {
      showAdminTopNotice(context, 'Nosozlik va sababni kiriting');
      return;
    }
    final start = DateTime.now();
    try {
      await MobileApi.instance.adminSaveApparatusDowntime(
        AdminApparatusDowntime(
          id: '',
          apparatusId: apparatus.id,
          apparatus: apparatus.name,
          startsAtUnix: start.millisecondsSinceEpoch ~/ 1000,
          endsAtUnix: start
                  .add(Duration(minutes: (hours * 60).round()))
                  .millisecondsSinceEpoch ~/
              1000,
          reason: reason,
        ),
      );
      _downtimeReason.clear();
      await _load(showLoading: false);
      if (mounted) showAdminTopNotice(context, 'Nosozlik vaqti saqlandi');
    } catch (error) {
      if (mounted) showAdminTopNotice(context, _errorMessage(error));
    }
  }

  String _errorMessage(Object error) {
    if (error is MobileApiException) return error.message;
    return 'Amal bajarilmadi';
  }

  String _formatUnix(int value) {
    if (value <= 0) return '—';
    final date = DateTime.fromMillisecondsSinceEpoch(value * 1000);
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}.${two(date.month)} ${two(date.hour)}:${two(date.minute)}';
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(labelText: label, isDense: true);
  }

  Widget _sectionCard({required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  'Quvvat va capability profili',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Finite capacity, setup/cleanup va Flexo kabi capability darajalari shu yerda boshqariladi.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selected?.id,
                  decoration: _decoration('Aparat'),
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _capacitySlots,
                        keyboardType: TextInputType.number,
                        decoration: _decoration('Parallel slot'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _efficiency,
                        keyboardType: TextInputType.number,
                        decoration: _decoration('Efficiency %'),
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
                        decoration: _decoration('Setup min'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _cleanupMinutes,
                        keyboardType: TextInputType.number,
                        decoration: _decoration('Cleanup min'),
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
                  title: const Text('Finite capacity'),
                  subtitle: const Text(
                    'O‘chirilsa, shu aparat parallel jadvalni cheklamaydi.',
                  ),
                ),
                TextField(
                  controller: _workingWindows,
                  maxLines: 2,
                  decoration: _decoration(
                    'Ish vaqti: 1:480-1020;2:480-1020',
                  ).copyWith(
                    helperText:
                        '1=Dushanba, 7=Yakshanba; bo‘sh qoldirilsa 24/7',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _capabilities,
                  maxLines: 2,
                  decoration: _decoration('Capability: flexo:3, print'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: _decoration('Izoh / standart'),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed:
                        selected == null || _saving ? null : _saveProfile,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Profilni saqlash'),
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
                  'Orderni rejalashtirish',
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
                  decoration: _decoration('Order'),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _duration,
                        keyboardType: TextInputType.number,
                        decoration: _decoration('Ish min'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickScheduleStart,
                        child: Text(
                            'Boshlanish\n${_formatUnix(_scheduleStart.millisecondsSinceEpoch ~/ 1000)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _requirements,
                  decoration: _decoration('Talab: flexo:2 (ixtiyoriy)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _scheduleReason,
                  decoration: _decoration('Sabab / priority izohi'),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed:
                        selected == null || _saving ? null : _scheduleOrder,
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Jadvalga qo‘yish'),
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
                  'Rejalashtirilgan bandlik',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                if (_snapshot.reservations.isEmpty)
                  Text(
                    'Hozircha reservation yo‘q',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  )
                else
                  for (final reservation in _snapshot.reservations)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        reservation.status == 'cancelled'
                            ? Icons.event_busy_outlined
                            : Icons.event_available_outlined,
                      ),
                      title: Text(
                          '${reservation.orderId} • ${reservation.apparatus}'),
                      subtitle: Text(
                        '${_formatUnix(reservation.startsAtUnix)} — ${_formatUnix(reservation.endsAtUnix)} • ${reservation.status}',
                      ),
                      trailing: reservation.status == 'planned'
                          ? IconButton(
                              tooltip: 'Bekor qilish',
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
                        'Downtime / nosozlik',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Saqlash',
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
                        decoration: _decoration('Soat'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _downtimeReason,
                        decoration: _decoration('Sabab'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final downtime in _snapshot.downtimes.take(8))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.build_circle_outlined),
                    title: Text('${downtime.apparatus} • ${downtime.reason}'),
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
