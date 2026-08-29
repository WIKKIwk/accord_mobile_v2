import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/lists/lists.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../logic/canonical_apparatus_display.dart';
import 'widgets/admin_apparatus_scope_picker.dart';
import 'widgets/admin_create_hub_sheet.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_surface_tab_bar.dart';
import 'widgets/admin_top_notice.dart';

part 'admin_worker_settings_screen__AdminWorkerSettingsScreenState_methods_01.dart';
part 'admin_worker_settings_screen__AdminWorkerSettingsScreenState_methods_02.dart';
part 'admin_worker_settings_screen_helpers_part_01.dart';
part 'admin_worker_settings_screen_widgets_part_02.dart';
part 'admin_worker_settings_screen_models_part_03.dart';
part 'admin_worker_settings_screen_widgets_part_04.dart';
part 'admin_worker_settings_screen_widgets_part_05.dart';
part 'admin_worker_settings_screen_widgets_part_06.dart';

const List<String> adminWorkerLevels = [
  'Brigader',
  'Master',
  '1 - darajali',
  '2 - darajali',
  '3 - darajali',
];

const Map<String, String> adminWorkerStartDayLabels = {
  'monday': 'Dushanba',
  'tuesday': 'Seshanba',
  'wednesday': 'Chorshanba',
  'thursday': 'Payshanba',
  'friday': 'Juma',
  'saturday': 'Shanba',
  'sunday': 'Yakshanba',
};

const double _workerSettingsPanelGap = 4;

class _AdminWorkerSettingsScreenState extends State<AdminWorkerSettingsScreen>
    with SingleTickerProviderStateMixin {
  late Future<_WorkerSettingsData> _future;
  late TabController _tabController;
  int _workersVersion = 0;
  int _groupsVersion = 0;
  String? _selectedWorkerId;
  String? _deactivatingWorkerId;
  final Set<String> _savingApparatusWorkerIds = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _future = _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      drawer: AdminNavigationDrawer(
        selectedIndex: 1,
        selectedRouteName: AppRoutes.adminWorkerSettings,
        onNavigate: _openDrawerRoute,
      ),
      title: context.l10n.adminText('worker.title'),
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: AdminDock(
        activeTab: null,
        primaryFabActions: [
          AdminFabMenuAction(
            title: context.l10n.adminText('worker.add'),
            icon: Icons.person_add_alt_1_rounded,
            onTap: _openWorkerCreateDialog,
          ),
          AdminFabMenuAction(
            title: context.l10n.adminText('worker.group_add'),
            icon: Icons.groups_2_outlined,
            onTap: _openWorkerGroupCreateDialog,
          ),
        ],
      ),
      contentPadding: EdgeInsets.zero,
      child: Column(
        children: [
          AdminSurfaceTabBar(
            controller: _tabController,
            tabs: [
              Tab(
                height: 38,
                text: context.l10n.adminText('worker.tabs_workers'),
              ),
              Tab(
                height: 38,
                text: context.l10n.adminText('worker.tabs_groups'),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWorkersTab(),
                _WorkerGroupsTab(
                  workersVersion: _workersVersion,
                  groupsVersion: _groupsVersion,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
