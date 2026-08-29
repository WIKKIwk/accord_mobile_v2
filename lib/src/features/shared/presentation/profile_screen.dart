import '../../../core/api/mobile_api.dart';
import '../../../core/security/state/security_controller.dart';
import '../../../app/app_router.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/navigation/app_root_navigation.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/update/app_update_runtime.dart';
import '../../../core/widgets/feedback/logout_prompt.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/lists/lists.dart';
import '../../../core/widgets/display/motion_widgets.dart';
import '../../../core/widgets/display/image_fade.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../data/profile_avatar_cache.dart';
import '../models/app_models.dart';
import 'pin_setup_purpose.dart';
import 'widgets/profile_info_chip.dart';
import 'widgets/profile_avatar_preview.dart';
import '../../admin/presentation/widgets/admin_dock.dart';
import '../../supplier/presentation/widgets/supplier_dock.dart';
import '../../supplier/presentation/widgets/supplier_navigation_drawer.dart';
import '../../customer/presentation/widgets/customer_dock.dart';
import '../../customer/presentation/widgets/customer_navigation_drawer.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_dock.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_navigation_drawer.dart';
import '../../aparatchi/presentation/widgets/aparatchi_dock.dart';
import '../../aparatchi/presentation/widgets/aparatchi_navigation_drawer.dart';
import '../../qolip/presentation/widgets/qolip_dock.dart';
import '../../qolip/presentation/widgets/qolip_navigation_drawer.dart';
import '../../boyoqchi/presentation/widgets/boyoqchi_dock.dart';
import '../../boyoqchi/presentation/widgets/boyoqchi_navigation_drawer.dart';
import '../../werka/presentation/widgets/werka_dock.dart';
import '../../werka/presentation/widgets/werka_navigation_drawer.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

part 'profile_screen__ProfileScreenState_methods_01.dart';
part 'profile_screen__ProfileScreenState_methods_02.dart';
part 'profile_screen_widgets_part_01.dart';
part 'profile_screen_widgets_part_02.dart';
part 'profile_screen_widgets_part_03.dart';
part 'profile_screen_declarations_part_04.dart';

const double _profilePanelGap = 4;
const String _profileDefaultCoverAsset =
    'assets/images/profile_default_cover.webp';

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  final TextEditingController nicknameController = TextEditingController();
  bool savingNickname = false;
  bool savingAvatar = false;
  bool savingPin = false;
  bool savingSwitchPin = false;
  bool savingBiometric = false;
  String? errorMessage;
  final ImagePicker _avatarPicker = ImagePicker();
  Uint8List? cachedAvatarBytes;
  Uint8List? pendingAvatarBytes;
  String? pendingAvatarName;

  SessionProfile get profile => AppSession.instance.profile!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    nicknameController.text = _normalizedDisplayName(profile);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_loadCachedAvatar());
    });
  }

  bool get _hasNicknameChanges =>
      nicknameController.text.trim() != _normalizedDisplayName(profile).trim();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    nicknameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LocaleController.instance,
      builder: (context, _) {
        final l10n = context.l10n;
        final current = profile;
        final shellKind = _profileShellKindForHomeRoute(
          AppSession.instance.homeRoute,
        );
        final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
        final bottomPadding = bottomInset + 136.0;
        final subtitle = current.isCapabilityOnlyProfile
            ? l10n.capabilityBasedAccount
            : current.accessRole == UserRole.supplier
                ? l10n.supplierAccount
                : current.accessRole == UserRole.werka
                    ? l10n.werkaAccount
                    : current.accessRole == UserRole.customer
                        ? l10n.customerAccount
                        : current.accessRole == UserRole.materialTaminotchi
                            ? 'Material ta’minotchisi profili'
                            : current.accessRole == UserRole.boyoqchi
                                ? 'Bo‘yoqchi profili'
                                : l10n.adminAccount;
        final bool savingProfileChanges = savingNickname || savingAvatar;
        final displayName = _normalizedDisplayName(current);
        final legalName = _normalizedLegalName(current);
        final effectiveLegalName =
            (legalName.isEmpty ? displayName : legalName).trim();

        return AppShell(
          title: l10n.profileTitle,
          subtitle: '',
          nativeTopBar: true,
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: AppShellIconAction(
                icon: Icons.tune_rounded,
                size: 38,
                onTap: _openProfileSettings,
              ),
            ),
          ],
          animateOnEnter: false,
          drawer: switch (shellKind) {
            _ProfileShellKind.werka => WerkaNavigationDrawer(
                selectedIndex: 3,
                onNavigate: _openWerkaDrawerRoute,
              ),
            _ProfileShellKind.supplier => SupplierNavigationDrawer(
                selectedIndex: 3,
                onNavigate: _openSupplierDrawerRoute,
              ),
            _ProfileShellKind.customer => CustomerNavigationDrawer(
                selectedIndex: 2,
                onNavigate: _openCustomerDrawerRoute,
              ),
            _ProfileShellKind.materialTaminotchi =>
              MaterialTaminotchiNavigationDrawer(
                selectedRouteName: AppRoutes.profile,
                onNavigate: _openMaterialTaminotchiDrawerRoute,
              ),
            _ProfileShellKind.aparatchi => AparatchiNavigationDrawer(
                selectedIndex: 0,
                selectedRouteName: AppRoutes.profile,
                onNavigate: _openAparatchiDrawerRoute,
              ),
            _ProfileShellKind.qolip => QolipNavigationDrawer(
                selectedIndex: 0,
                selectedRouteName: AppRoutes.profile,
                onNavigate: _openQolipDrawerRoute,
              ),
            _ProfileShellKind.boyoqchi => BoyoqchiNavigationDrawer(
                selectedRouteName: AppRoutes.profile,
                onNavigate: _openBoyoqchiDrawerRoute,
              ),
            _ProfileShellKind.admin || _ProfileShellKind.none => null,
          },
          bottom: switch (shellKind) {
            _ProfileShellKind.supplier => const SupplierDock(
                activeTab: null,
                showPrimaryFab: false,
              ),
            _ProfileShellKind.werka => const WerkaDock(
                activeTab: null,
                showPrimaryFab: false,
              ),
            _ProfileShellKind.customer => const CustomerDock(activeTab: null),
            _ProfileShellKind.materialTaminotchi =>
              const MaterialTaminotchiDock(
                activeTab: MaterialTaminotchiDockTab.profile,
              ),
            _ProfileShellKind.aparatchi => const AparatchiDock(
                activeTab: AparatchiDockTab.profile,
                showPrimaryFab: false,
              ),
            _ProfileShellKind.qolip => const QolipDock(
                activeTab: QolipDockTab.profile,
              ),
            _ProfileShellKind.boyoqchi => const BoyoqchiDock(
                activeTab: BoyoqchiDockTab.profile,
              ),
            _ProfileShellKind.admin => const AdminDock(
                activeTab: AdminDockTab.user,
                showPrimaryFab: false,
              ),
            _ProfileShellKind.none => null,
          },
          contentPadding: EdgeInsets.zero,
          child: ColoredBox(
            color: AppTheme.shellStart(context),
            child: AppRefreshIndicator(
              onRefresh: _refreshProfile,
              child: ListView(
                physics: const TopRefreshScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  _profilePanelGap,
                  _profilePanelGap,
                  _profilePanelGap,
                  bottomPadding,
                ),
                children: [
                  SmoothAppear(
                    duration: AppMotion.fast,
                    child: AppSegmentSurfaceCard(
                      padding: EdgeInsets.zero,
                      child: _ProfileHeroCard(
                        displayName: displayName,
                        subtitle: subtitle,
                        phone: current.phone,
                        legalName: effectiveLegalName,
                        cachedAvatarBytes: cachedAvatarBytes,
                        pendingAvatarBytes: pendingAvatarBytes,
                        savingAvatar: savingAvatar,
                        savingProfileChanges: savingProfileChanges,
                        hasPendingAvatar: pendingAvatarBytes != null,
                        onPickAvatar: _pickAvatar,
                        onEditProfile: _openProfileEditor,
                        onSaveProfileChanges: _saveProfileChanges,
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    _ProfilePanel(child: Text(errorMessage!)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
