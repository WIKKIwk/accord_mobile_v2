import 'admin_raw_material_assignment_screen.dart';
import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback/app_dialog_action_row.dart';
import '../../../core/widgets/lists/lists.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_dock.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_navigation_drawer.dart';
import '../../shared/models/app_models.dart';
import '../logic/canonical_apparatus_display.dart';
import '../models/admin_item_group_tree_entry.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_surface_tab_bar.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';

part 'admin_raw_material_rules_screen__AdminRawMaterialSettingsScreenState_methods_01.dart';
part 'admin_raw_material_rules_screen_declarations_part_01.dart';
part 'admin_raw_material_rules_screen_widgets_part_02.dart';

const double _rawMaterialRulesPanelGap = 4;

class _AdminRawMaterialSettingsScreenState
    extends State<AdminRawMaterialSettingsScreen>
    with SingleTickerProviderStateMixin {
  final _groupsController = TextEditingController();
  late Future<_RawMaterialRulesData> _future;
  late TabController _tabController;
  late final bool _materialAssignmentMode;
  List<AdminApparatus> _apparatus = const [];
  List<AdminRawMaterialRule> _rules = const [];
  List<AdminRawMaterialRequirementGroup> _selectedRequirementGroups = const [];
  String _selectedApparatusId = '';
  AdminRawMaterialStartPolicy _selectedStartPolicy =
      AdminRawMaterialStartPolicy.stateAll;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _materialAssignmentMode = _isMaterialAssignmentMode;
    _tabController = TabController(
      length: _materialAssignmentMode ? 1 : 3,
      initialIndex: _materialAssignmentMode
          ? 0
          : _rawMaterialSettingsTabIndex(widget.initialTab),
      vsync: this,
    );
    _future = _materialAssignmentMode
        ? Future.value(const _RawMaterialRulesData.empty())
        : _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _groupsController.dispose();
    super.dispose();
  }

  bool get _isMaterialAssignmentMode {
    final profile = AppSession.instance.profile;
    return widget.initialTab == AdminRawMaterialSettingsTab.assignments &&
        profile?.role == UserRole.materialTaminotchi;
  }

  @override
  Widget build(BuildContext context) {
    if (_materialAssignmentMode) {
      final profile = AppSession.instance.profile;
      final hasMaterialGroupScope =
          (profile?.assignedItemGroups ?? const <String>[]).isNotEmpty;
      final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 128;
      return AppShell(
        drawer: MaterialTaminotchiNavigationDrawer(
          selectedRouteName: AppRoutes.adminRawMaterialAssignments,
          onNavigate: _openMaterialDrawerRoute,
        ),
        title: context.l10n.adminText('raw_material.assign_title'),
        subtitle: '',
        nativeTopBar: true,
        nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
        preferNativeTitle: true,
        bottom: const MaterialTaminotchiDock(),
        contentPadding: EdgeInsets.zero,
        child: AdminRawMaterialAssignmentPanel(
          bottomPadding: bottomPadding,
          groupScopeReady: hasMaterialGroupScope,
          initialBarcode: widget.initialBarcode,
        ),
      );
    }
    return AppShell(
      drawer: AdminNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.adminRawMaterialSettings,
        onNavigate: _openDrawerRoute,
      ),
      title: context.l10n.adminText('raw_material.settings_title'),
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
                tabs: [
                  Tab(
                    height: 38,
                    text: context.l10n.adminText('raw_material.link_tab'),
                  ),
                  Tab(
                    height: 38,
                    text: context.l10n.adminText('raw_material.rules_tab'),
                  ),
                  Tab(
                    height: 38,
                    text:
                        context.l10n.adminText('raw_material.requirement_tab'),
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    AdminRawMaterialAssignmentPanel(
                      bottomPadding: bottomPadding,
                      initialBarcode: widget.initialBarcode,
                    ),
                    ColoredBox(
                      color: AppTheme.shellStart(context),
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
                            selectedApparatusId: _selectedApparatusId,
                            rawMaterialGroups: data.rawMaterialGroups,
                            groupsController: _groupsController,
                            selectedStartPolicy: _selectedStartPolicy,
                            saving: _saving,
                            onApparatusChanged: (value) {
                              setState(() {
                                _selectedApparatusId = value;
                                _fillGroupsFor(value);
                              });
                            },
                            onPickGroups: () =>
                                _pickGroups(data.rawMaterialGroups),
                            onStartPolicyChanged: (value) {
                              setState(() => _selectedStartPolicy = value);
                            },
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
                                    apparatusName:
                                        canonicalApparatusDisplayLabel(
                                      _rules[index].apparatusId,
                                      data.apparatus,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedApparatusId =
                                            _rules[index].apparatusId;
                                        _fillGroupsFor(
                                          _rules[index].apparatusId,
                                        );
                                      });
                                      _tabController.animateTo(
                                        _rawMaterialSettingsTabIndex(
                                          AdminRawMaterialSettingsTab.rules,
                                        ),
                                      );
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
