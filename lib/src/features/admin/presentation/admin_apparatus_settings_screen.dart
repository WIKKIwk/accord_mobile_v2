import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../logic/canonical_apparatus_groups.dart';
import '../logic/factory_map_mapping.dart';
import 'admin_apparatus_capacity_panel.dart';
import 'admin_factory_map_viewer.dart';
import 'admin_queue_policy_screen.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_surface_tab_bar.dart';
import 'widgets/admin_top_notice.dart';

part 'admin_apparatus_settings_screen__AdminApparatusSettingsScreenState_methods_01.dart';
part 'admin_apparatus_settings_screen__AdminApparatusSettingsScreenState_methods_02.dart';
part 'admin_apparatus_settings_screen__AdminApparatusSettingsScreenState_methods_03.dart';
part 'admin_apparatus_settings_screen_declarations_part_01.dart';

class _AdminApparatusSettingsScreenState
    extends State<AdminApparatusSettingsScreen>
    with SingleTickerProviderStateMixin {
  static _AdminApparatusSettingsCache? _cache;

  late final TabController _tabController;
  List<AdminApparatus> _apparatus = const [];
  List<AdminApparatusCollection> _collections = const [];
  late AdminApparatusMasterOptions _options;
  bool _loading = true;
  bool _saving = false;
  bool _focusedEditorOpened = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      initialIndex: _apparatusSettingsTabIndex(widget.initialTab),
      vsync: this,
    );
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
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 112;
    return AppShell(
      title: context.l10n.adminText('apparatus.title'),
      subtitle: '',
      drawer: AdminNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.adminApparatusSettings,
        onNavigate: (routeName) =>
            AdminDrawerNavigation.openRoute(context, routeName),
      ),
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: const AdminDock(activeTab: AdminDockTab.home),
      contentPadding: EdgeInsets.zero,
      child: _loading
          ? const Center(child: AppLoadingIndicator())
          : _loadError != null
              ? AppRetryState(onRetry: _load)
              : Column(
                  children: [
                    AdminSurfaceTabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        Tab(
                          height: 38,
                          text: context.l10n.adminText('apparatus.add'),
                        ),
                        Tab(
                          height: 38,
                          text: context.l10n.adminText('apparatus.groups'),
                        ),
                        Tab(
                          height: 38,
                          text: context.l10n.adminText('apparatus.tabs_queue'),
                        ),
                        Tab(
                          height: 38,
                          text:
                              context.l10n.adminText('apparatus.tabs_capacity'),
                        ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCatalog(bottomPadding),
                          _buildGroups(bottomPadding),
                          AdminQueuePolicyPanel(bottomPadding: bottomPadding),
                          AdminApparatusCapacityPanel(
                            apparatus: _apparatus,
                            bottomPadding: bottomPadding,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
