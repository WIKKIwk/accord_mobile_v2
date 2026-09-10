import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/app_segment_surface_card.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'admin_apparatus_capacity_panel.dart';
import 'admin_factory_map_viewer.dart';
import 'admin_queue_policy_screen.dart';
import 'widgets/admin_dock.dart';
import 'widgets/factory_map_unlink_dialog.dart';

/// Aparatlar ro'yxatidan tap qilinganda ochiladigan alohida detail page.
///
/// Ilgari kichik dialog ([_CanonicalApparatusSettingsCard] o'rnida) ichidagi
/// 4 ta tab — Navbat, Quvvat/jadval, 3D xarita, Training — endi bitta
/// scroll'lanadigan page'da ketma-ket section bo'lib chiqadi.
class AdminApparatusDetailScreen extends StatefulWidget {
  const AdminApparatusDetailScreen({
    super.key,
    required this.apparatus,
    required this.currentApparatus,
    required this.onPlacementChanged,
    required this.onTrainingChanged,
    required this.onEdit,
  });

  final AdminApparatus apparatus;
  final AdminApparatus Function() currentApparatus;
  final Future<AdminApparatus?> Function(
    AdminApparatus apparatus,
    String objectId,
  )
  onPlacementChanged;
  final Future<AdminApparatus?> Function(AdminApparatus apparatus, bool enabled)
  onTrainingChanged;
  final Future<void> Function(AdminApparatus apparatus) onEdit;

  @override
  State<AdminApparatusDetailScreen> createState() =>
      _AdminApparatusDetailScreenState();
}

class _AdminApparatusDetailScreenState
    extends State<AdminApparatusDetailScreen> {
  late AdminApparatus _apparatus;
  bool _savingPlacement = false;
  bool _savingTraining = false;

  @override
  void initState() {
    super.initState();
    _apparatus = widget.currentApparatus();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _apparatus = widget.currentApparatus());
  }

  Future<void> _choosePlacement() async {
    if (_savingPlacement) return;
    setState(() => _savingPlacement = true);
    try {
      final selection = await showAdminFactoryMapObjectPicker(
        context,
        initialObjectId: _apparatus.factoryMapObjectId,
      );
      if (selection == null || !mounted) return;
      final saved = await widget.onPlacementChanged(
        _apparatus,
        selection.objectId,
      );
      if (mounted) setState(() => _apparatus = saved ?? widget.currentApparatus());
    } finally {
      if (mounted) setState(() => _savingPlacement = false);
    }
  }

  Future<void> _clearPlacement() async {
    if (_savingPlacement || _apparatus.factoryMapObjectId.isEmpty) return;
    setState(() => _savingPlacement = true);
    try {
      if (!await confirmFactoryMapUnlink(context, _apparatus.name) ||
          !mounted) {
        return;
      }
      final saved = await widget.onPlacementChanged(_apparatus, '');
      if (mounted) setState(() => _apparatus = saved ?? widget.currentApparatus());
    } finally {
      if (mounted) setState(() => _savingPlacement = false);
    }
  }

  Future<void> _toggleTraining(bool enabled) async {
    if (_savingTraining) return;
    setState(() => _savingTraining = true);
    try {
      final saved = await widget.onTrainingChanged(_apparatus, enabled);
      if (saved != null && mounted) setState(() => _apparatus = saved);
    } finally {
      if (mounted) setState(() => _savingTraining = false);
    }
  }

  Future<void> _edit() async {
    await widget.onEdit(_apparatus);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 112;
    return AppShell(
      title: _apparatus.name,
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      contentPadding: EdgeInsets.zero,
      bottom: const AdminDock(activeTab: AdminDockTab.home),
      child: ColoredBox(
        color: AppTheme.shellStart(context),
        child: ListView(
          key: ValueKey('admin-apparatus-detail-${_apparatus.id}'),
          padding: EdgeInsets.fromLTRB(4, 4, 4, bottomPadding),
          children: [
            _headerCard(context, scheme),
            const SizedBox(height: 12),
            _sectionLabel(
              context,
              scheme,
              context.l10n.adminText('apparatus.tabs_queue'),
            ),
            const SizedBox(height: 8),
            AdminQueuePolicyPanel(
              key: ValueKey('detail-queue-${_apparatus.id}'),
              bottomPadding: 0,
              apparatusId: _apparatus.id,
              padding: EdgeInsets.zero,
              shrinkWrap: true,
            ),
            const SizedBox(height: 12),
            _sectionLabel(
              context,
              scheme,
              context.l10n.adminText('apparatus.tabs_capacity'),
            ),
            const SizedBox(height: 8),
            AdminApparatusCapacityPanel(
              key: ValueKey('detail-capacity-${_apparatus.id}'),
              apparatus: [_apparatus],
              bottomPadding: 0,
              showApparatusSelector: false,
              padding: EdgeInsets.zero,
              shrinkWrap: true,
            ),
            const SizedBox(height: 12),
            _sectionLabel(
              context,
              scheme,
              context.l10n.adminText('apparatus.tabs_map'),
            ),
            const SizedBox(height: 8),
            _mapCard(context, scheme),
            const SizedBox(height: 12),
            _sectionLabel(
              context,
              scheme,
              context.l10n.adminText('apparatus.tabs_training'),
            ),
            const SizedBox(height: 8),
            _trainingCard(context, scheme),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, ColorScheme scheme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _headerCard(BuildContext context, ColorScheme scheme) {
    final l10n = context.l10n;
    final subtitleLine = _apparatus.family == 'other'
        ? _apparatus.id
        : '${_apparatus.family} · ${_apparatus.id}';
    return AppSegmentSurfaceCard(
      backgroundColor: scheme.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 36,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    _detailApparatusIcon(_apparatus),
                    size: 18,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _apparatus.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.adminText('action.edit'),
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          if (_apparatus.capabilities.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _apparatus.capabilities.join(' • '),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mapCard(BuildContext context, ColorScheme scheme) {
    final l10n = context.l10n;
    final objectId = _apparatus.factoryMapObjectId.trim();
    return AppSegmentSurfaceCard(
      backgroundColor: scheme.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (objectId.isNotEmpty) ...[
            SelectableText(objectId),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            onPressed: _savingPlacement ? null : _choosePlacement,
            icon: const Icon(Icons.map_outlined),
            label: Text(l10n.adminText('apparatus.choose_map_object')),
          ),
          if (objectId.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _savingPlacement ? null : _clearPlacement,
              icon: const Icon(Icons.link_off_rounded),
              label: Text(l10n.adminText('apparatus.remove_link')),
            ),
          ],
          if (_savingPlacement) ...[
            const SizedBox(height: 8),
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ],
      ),
    );
  }

  Widget _trainingCard(BuildContext context, ColorScheme scheme) {
    final l10n = context.l10n;
    return AppSegmentSurfaceCard(
      backgroundColor: scheme.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        value: _apparatus.trainingEnabled,
        onChanged: _savingTraining ? null : _toggleTraining,
        title: Text(l10n.adminText('apparatus.training_switch')),
        subtitle: Text(
          l10n.adminText(
            _apparatus.trainingEnabled
                ? 'apparatus.training_on_description'
                : 'apparatus.training_off_description',
          ),
        ),
        secondary: _savingTraining
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.school_outlined),
      ),
    );
  }
}

IconData _detailApparatusIcon(AdminApparatus apparatus) {
  return switch (apparatus.operation) {
    'print' => Icons.print_outlined,
    'laminate' => Icons.layers_outlined,
    'cut' => Icons.content_cut_rounded,
    'package' => Icons.inventory_2_outlined,
    'glue' => Icons.water_drop_outlined,
    _ => Icons.precision_manufacturing_outlined,
  };
}
