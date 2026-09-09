import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../logic/canonical_apparatus_groups.dart';
import '../logic/factory_map_mapping.dart';
import '../logic/factory_map_bindings.dart';
import 'admin_apparatus_capacity_panel.dart';
import 'admin_factory_map_viewer.dart';
import 'admin_queue_policy_screen.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_summary_card.dart';
import 'widgets/admin_top_notice.dart';
import 'widgets/factory_map_unlink_dialog.dart';

part 'admin_apparatus_settings_screen__AdminApparatusSettingsScreenState_methods_01.dart';
part 'admin_apparatus_settings_screen__AdminApparatusSettingsScreenState_methods_02.dart';
part 'admin_apparatus_settings_screen__AdminApparatusSettingsScreenState_methods_03.dart';
part 'admin_apparatus_settings_screen_declarations_part_01.dart';

const double _adminApparatusPanelGap = 4;

class _AdminApparatusSettingsScreenState
    extends State<AdminApparatusSettingsScreen> {
  static _AdminApparatusSettingsCache? _cache;

  late AdminApparatusModule _selectedModule;
  List<AdminApparatus> _apparatus = const [];
  List<AdminApparatusCollection> _collections = const [];
  late AdminApparatusMasterOptions _options;
  bool _loading = true;
  bool _saving = false;
  bool _focusedEditorOpened = false;
  Object? _loadError;
  final _bindings = FactoryMapBindings();
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _selectedModule = widget.focusApparatusName
        ? AdminApparatusModule.catalog
        : _moduleFromSettingsTab(widget.initialTab);
    final cached = _cache;
    if (cached != null) {
      _apparatus = cached.apparatus;
      _collections = cached.collections;
      _options = cached.options;
      _loading = false;
      unawaited(_load(showLoading: false));
      _maybeOpenFocusedEditor();
    } else {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _bindings.dispose();
    super.dispose();
  }

  String _currentTitle(AppLocalizations l10n) {
    return switch (_selectedModule) {
      AdminApparatusModule.hub => l10n.adminText('apparatus.title'),
      AdminApparatusModule.catalog => 'Aparatlar ro‘yxati',
      AdminApparatusModule.groups => l10n.adminText('apparatus.groups'),
      AdminApparatusModule.queue => l10n.adminText('apparatus.tabs_queue'),
      AdminApparatusModule.capacity =>
        l10n.adminText('apparatus.tabs_capacity'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 112;
    final isHub = _selectedModule == AdminApparatusModule.hub;
    return PopScope(
      canPop: isHub,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() => _selectedModule = AdminApparatusModule.hub);
      },
      child: AppShell(
        title: _currentTitle(context.l10n),
        subtitle: '',
        drawer: isHub
            ? AdminNavigationDrawer(
                selectedIndex: 0,
                selectedRouteName: AppRoutes.adminApparatusSettings,
                onNavigate: (routeName) =>
                    AdminDrawerNavigation.openRoute(context, routeName),
              )
            : null,
        leading: isHub
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () =>
                    setState(() => _selectedModule = AdminApparatusModule.hub),
              ),
        nativeTopBar: true,
        nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
        bottom: const AdminDock(activeTab: AdminDockTab.home),
        contentPadding: EdgeInsets.zero,
        child: _loading
            ? const Center(child: AppLoadingIndicator())
            : _loadError != null
                ? AppRetryState(onRetry: _load)
                : _buildCurrentModule(bottomPadding),
      ),
    );
  }

  Widget _buildCurrentModule(double bottomPadding) {
    return switch (_selectedModule) {
      AdminApparatusModule.hub => _buildHub(bottomPadding),
      AdminApparatusModule.catalog => _buildCatalog(bottomPadding),
      AdminApparatusModule.groups => _buildGroups(bottomPadding),
      AdminApparatusModule.queue =>
        AdminQueuePolicyPanel(bottomPadding: bottomPadding),
      AdminApparatusModule.capacity => AdminApparatusCapacityPanel(
          apparatus: _apparatus,
          bottomPadding: bottomPadding,
        ),
    };
  }

  Widget _buildHub(double bottomPadding) {
    final l10n = context.l10n;

    return ColoredBox(
      color: AppTheme.shellStart(context),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          _adminApparatusPanelGap,
          8,
          _adminApparatusPanelGap,
          bottomPadding,
        ),
        children: [
          M3SegmentSpacedColumn(
            children: [
              _buildHubCard(
                slot: M3SegmentVerticalSlot.top,
                icon: Icons.precision_manufacturing_outlined,
                title: 'Aparatlar ro‘yxati',
                subtitle: '${_apparatus.length} ta apparat faol',
                onTap: () => setState(
                  () => _selectedModule = AdminApparatusModule.catalog,
                ),
              ),
              _buildHubCard(
                slot: M3SegmentVerticalSlot.middle,
                icon: Icons.folder_copy_outlined,
                title: l10n.adminText('apparatus.groups'),
                subtitle: '${_collections.length} ta maxsus guruh',
                onTap: () => setState(
                  () => _selectedModule = AdminApparatusModule.groups,
                ),
              ),
              _buildHubCard(
                slot: M3SegmentVerticalSlot.middle,
                icon: Icons.low_priority_rounded,
                title: l10n.adminText('apparatus.tabs_queue'),
                subtitle: 'FIFO va navbat qoidalari',
                onTap: () => setState(
                  () => _selectedModule = AdminApparatusModule.queue,
                ),
              ),
              _buildHubCard(
                slot: M3SegmentVerticalSlot.bottom,
                icon: Icons.speed_rounded,
                title: l10n.adminText('apparatus.tabs_capacity'),
                subtitle: 'Ish vaqti, smena va parallel slotlar',
                onTap: () => setState(
                  () => _selectedModule = AdminApparatusModule.capacity,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHubCard({
    required M3SegmentVerticalSlot slot,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return AdminSummaryCard(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      onTap: onTap,
      backgroundColor: scheme.surfaceContainerLowest,
      fixedHeight: 65,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      value: '',
      showChevron: true,
      leading: SizedBox.square(
        dimension: 34,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 18,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
      title: title,
      subtitle: subtitle,
      titleMaxLines: 1,
      subtitleMaxLines: 1,
      titleStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
      subtitleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.1,
          ),
    );
  }
}
