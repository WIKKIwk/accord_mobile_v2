import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/lists/m3_animated_list_entry.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../state/admin_users_role_store.dart';
import 'widgets/admin_catalog_search_field.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_expandable_filter_chip.dart';
import 'widgets/admin_supplier_list_module.dart';

part 'admin_suppliers_screen__AdminSuppliersScreenState_methods_01.dart';
part 'admin_suppliers_screen__AdminSuppliersScreenState_methods_02.dart';
part 'admin_suppliers_screen_widgets_part_01.dart';

const List<AdminUserKind> _adminUserTabKinds = [
  AdminUserKind.werka,
  AdminUserKind.customer,
  AdminUserKind.supplier,
  AdminUserKind.materialTaminotchi,
  AdminUserKind.worker,
  AdminUserKind.qolipchi,
  AdminUserKind.boyoqchi,
];

class _AdminSuppliersScreenState extends State<AdminSuppliersScreen> {
  static const int _pageSize = 50;
  static const double _prefetchExtentAfterFactor = 2.5;
  static _AdminSuppliersCache? _cache;
  static final ValueNotifier<int> _usersChanged = ValueNotifier<int>(0);

  static void invalidateCache() {
    _cache = null;
    _usersChanged.value++;
  }

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _usersScrollController = ScrollController();
  final List<AdminUserListEntry> _items = [];
  final List<AdminUserListEntry> _authoritativeItems = [];
  final Map<String, AdminUserListEntry> _exitingItems = {};
  final Set<String> _enteringItemKeys = {};
  final List<AdminWorker> _workers = [];
  final List<AdminRoleAssignment> _assignments = [];
  Timer? _searchDebounce;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String _searchQuery = '';
  AdminUserKind? _selectedKind;
  bool _roleMenuOpen = false;
  Object? _loadError;
  int _requestGeneration = 0;
  int _listAnimationGeneration = 0;
  bool _animateNextListUpdate = false;

  bool _userManuallySelectedRole = false;

  @override
  void initState() {
    super.initState();
    _selectedKind = AdminUsersRoleStore.instance.cachedRole;
    _usersChanged.addListener(_handleUsersChanged);
    _bootstrap();
    unawaited(_restoreSavedRolePreference());
  }

  @override
  void dispose() {
    _usersChanged.removeListener(_handleUsersChanged);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _usersScrollController.dispose();
    super.dispose();
  }

  String _authoritativeQuery = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppShell(
      animateOnEnter: false,
      drawer: AdminNavigationDrawer(
        selectedIndex: 1,
        selectedRouteName: AppRoutes.adminSuppliers,
        onNavigate: _openDrawerRoute,
      ),
      title: '',
      subtitle: '',
      nativeTopBar: true,
      automaticallyImplyNativeLeading: false,
      profileActionListenable: _searchFocusNode,
      showProfileActionResolver: () => !_searchFocusNode.hasFocus,
      titleWidget: AdminCatalogSearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: l10n.adminText('users.search'),
        onChanged: _onSearchChanged,
        onClear: () {
          _searchController.clear();
          _onSearchChanged('');
        },
      ),
      contentPadding: EdgeInsets.zero,
      bottom: const AdminDock(activeTab: AdminDockTab.user),
      child: Column(
        children: [
          _AdminUserRolePicker(
            selectedKind: _selectedKind,
            expanded: _roleMenuOpen,
            onToggle: () => setState(() => _roleMenuOpen = !_roleMenuOpen),
            onSelect: _selectKind,
          ),
          Expanded(child: _buildUserList(_selectedKind)),
        ],
      ),
    );
  }
}
