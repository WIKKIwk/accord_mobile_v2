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

const double _profilePanelGap = 4;
const String _profileDefaultCoverAsset =
    'assets/images/profile_default_cover.webp';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  final TextEditingController nicknameController = TextEditingController();
  bool savingNickname = false;
  bool savingAvatar = false;
  bool savingPin = false;
  bool savingBiometric = false;
  String? errorMessage;
  final ImagePicker _avatarPicker = ImagePicker();
  Uint8List? cachedAvatarBytes;
  Uint8List? pendingAvatarBytes;
  String? pendingAvatarName;

  SessionProfile get profile => AppSession.instance.profile!;

  String _normalizeWerkaLabel(String value, UserRole role) {
    final trimmed = value.trim();
    if (role == UserRole.werka && trimmed.toLowerCase() == 'werka') {
      return 'Wmanager';
    }
    return value;
  }

  String _normalizedDisplayName(SessionProfile profile) =>
      _normalizeWerkaLabel(profile.displayName, profile.role);

  String _normalizedLegalName(SessionProfile profile) =>
      _normalizeWerkaLabel(profile.legalName, profile.role);

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

  Future<void> _loadCachedAvatar() async {
    final bytes = await ProfileAvatarCache.ensureCached(profile);
    if (!mounted) {
      return;
    }
    setState(() {
      cachedAvatarBytes = bytes;
    });
  }

  Future<void> _refreshProfile() async {
    final updated = await MobileApi.instance.profile();
    final bytes = await ProfileAvatarCache.refreshFromUrl(updated) ??
        await ProfileAvatarCache.getCached(updated);
    if (!mounted) {
      return;
    }
    setState(() {
      nicknameController.text = _normalizedDisplayName(updated);
      cachedAvatarBytes = bytes;
      errorMessage = null;
    });
  }

  Future<void> _saveNickname() async {
    final nickname = nicknameController.text.trim();
    setState(() {
      savingNickname = true;
      errorMessage = null;
    });
    try {
      final updated = await MobileApi.instance.updateNickname(nickname);
      nicknameController.text = _normalizedDisplayName(updated);
      if (!mounted) {
        return;
      }
      setState(() {});
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        errorMessage = context.l10n.nicknameSaveFailed;
      });
    } finally {
      if (mounted) {
        setState(() {
          savingNickname = false;
        });
      }
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await _avatarPicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 82,
      );
      if (picked == null) {
        return;
      }
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('empty avatar');
      }
      if (!mounted) {
        return;
      }
      setState(() {
        errorMessage = null;
        pendingAvatarBytes = bytes;
        pendingAvatarName = picked.name;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        errorMessage = context.l10n.imagePickFailed;
      });
    }
  }

  Future<void> _saveAvatar() async {
    final bytes = pendingAvatarBytes;
    final filename = pendingAvatarName;
    if (bytes == null ||
        bytes.isEmpty ||
        filename == null ||
        filename.isEmpty) {
      return;
    }

    setState(() {
      savingAvatar = true;
      errorMessage = null;
    });
    try {
      final updated = await MobileApi.instance.uploadAvatar(
        bytes: bytes,
        filename: filename,
      );
      var cachedBytes = await ProfileAvatarCache.refreshFromUrl(updated);
      cachedBytes ??= await ProfileAvatarCache.cacheFromBytes(
        updated,
        bytes,
        filename,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        cachedAvatarBytes = cachedBytes ?? Uint8List.fromList(bytes);
        pendingAvatarBytes = null;
        pendingAvatarName = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        errorMessage = context.l10n.imageSaveFailed;
      });
    } finally {
      if (mounted) {
        setState(() {
          savingAvatar = false;
        });
      }
    }
  }

  bool get _hasNicknameChanges =>
      nicknameController.text.trim() != _normalizedDisplayName(profile).trim();

  Future<void> _saveProfileChanges() async {
    if (_hasNicknameChanges) {
      await _saveNickname();
    }
    if (pendingAvatarBytes != null) {
      await _saveAvatar();
    }
  }

  Future<void> _openProfileEditor() async {
    final editController = TextEditingController(
      text: nicknameController.text.trim(),
    );
    final previousPendingAvatarBytes = pendingAvatarBytes;
    final previousPendingAvatarName = pendingAvatarName;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AppMotion.sheetEaseOut,
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);
        return Padding(
          padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
          child: _ProfileSelectionSheet(
            title: context.l10n.profileEditTitle,
            subtitle: context.l10n.profileEditBody,
            bottomPadding: mediaQuery.padding.bottom + 24,
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: editController,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      decoration: appSurfaceInputDecoration(
                        sheetContext,
                        labelText: context.l10n.nicknameLabel,
                        hintText: context.l10n.nicknameHint,
                      ),
                      onSubmitted: (_) =>
                          Navigator.of(sheetContext).pop(editController.text),
                    ),
                    const SizedBox(height: 16),
                    _ProfileEditImageRow(
                      title: context.l10n.profilePhotoTitle,
                      actionLabel: pendingAvatarBytes == null
                          ? context.l10n.chooseImage
                          : context.l10n.changeImage,
                      imageBytes: pendingAvatarBytes ?? cachedAvatarBytes,
                      fallbackIcon: Icons.person_rounded,
                      onTap: () async {
                        await _pickAvatar();
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(editController.text),
                      child: Text(context.l10n.save),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
    editController.dispose();
    final next = result?.trim();
    if (next == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        pendingAvatarBytes = previousPendingAvatarBytes;
        pendingAvatarName = previousPendingAvatarName;
      });
      return;
    }
    if (next.isNotEmpty) {
      nicknameController.text = next;
    }
    await _saveProfileChanges();
  }

  Future<void> _showPinFlow() async {
    final result = await Navigator.of(
      context,
    ).pushNamed(AppRoutes.pinSetupEntry);
    if (result != true || !mounted) {
      return;
    }

    setState(() {
      savingPin = true;
      errorMessage = null;
    });
    try {
      final canUseBiometrics =
          await SecurityController.instance.canUseBiometrics();
      if (!mounted ||
          !canUseBiometrics ||
          SecurityController.instance.biometricEnabledForCurrentUser) {
        return;
      }
      final enable = await showM3ConfirmDialog(
        context: context,
        title: context.l10n.biometricQuickUnlockTitle,
        message: context.l10n.biometricQuickUnlockPrompt,
        cancelLabel: context.l10n.no,
        confirmLabel: context.l10n.yes,
      );
      if (enable == true) {
        await _toggleBiometric(true);
      } else {
        setState(() {});
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        errorMessage = context.l10n.pinSaveFailed;
      });
    } finally {
      if (mounted) {
        setState(() {
          savingPin = false;
        });
      }
    }
  }

  Future<void> _removePin() async {
    setState(() {
      savingPin = true;
      errorMessage = null;
    });
    try {
      await SecurityController.instance.clearPinForCurrentUser();
      if (!mounted) {
        return;
      }
      setState(() {});
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        errorMessage = context.l10n.pinRemoveFailed;
      });
    } finally {
      if (mounted) {
        setState(() {
          savingPin = false;
        });
      }
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    setState(() {
      savingBiometric = true;
      errorMessage = null;
    });
    try {
      final ok = await SecurityController.instance
          .setBiometricEnabledForCurrentUser(enabled);
      if (!ok && mounted) {
        setState(() {
          errorMessage = enabled
              ? context.l10n.biometricEnableFailed
              : context.l10n.biometricDisableFailed;
        });
      } else if (mounted) {
        setState(() {});
      }
    } finally {
      if (mounted) {
        setState(() {
          savingBiometric = false;
        });
      }
    }
  }

  Future<void> _openProfileSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AppMotion.sheetEaseOut,
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(sheetContext).maybePop(),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: AnimatedBuilder(
                animation: SecurityController.instance,
                builder: (context, _) {
                  return AnimatedBuilder(
                    animation: ThemeController.instance,
                    builder: (context, _) {
                      return _ProfileSettingsSheet(
                        maxHeight: mediaQuery.size.height * 0.78,
                        bottomPadding: mediaQuery.padding.bottom + 24,
                        currentLocale: LocaleController.instance.locale,
                        themeVariant: ThemeController.instance.variant,
                        isDarkMode: ThemeController.instance.isDark,
                        hasPin:
                            SecurityController.instance.hasPinForCurrentUser,
                        savingPin: savingPin,
                        biometricEnabled: SecurityController
                            .instance.biometricEnabledForCurrentUser,
                        savingBiometric: savingBiometric,
                        onShowPinFlow: _showPinFlow,
                        onRemovePin: _removePin,
                        onToggleBiometric: _toggleBiometric,
                        onCheckForUpdate: () async {
                          await AppUpdateCoordinator.instance.checkAndPrompt(
                            context,
                            manual: true,
                          );
                        },
                        onLogout: () async {
                          Navigator.of(sheetContext).pop();
                          await showLogoutPrompt(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

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

  void _openWerkaDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  void _openSupplierDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  void _openCustomerDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  void _openMaterialTaminotchiDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  void _openAparatchiDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) {
      return;
    }
    AppRootNavigation.replaceRootRoute(context, route);
  }

  void _openQolipDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) {
      return;
    }
    AppRootNavigation.replaceRootRoute(context, route);
  }

  void _openBoyoqchiDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) {
      return;
    }
    AppRootNavigation.replaceRootRoute(context, route);
  }
}

enum _ProfileShellKind {
  supplier,
  werka,
  customer,
  materialTaminotchi,
  aparatchi,
  qolip,
  boyoqchi,
  admin,
  none,
}

_ProfileShellKind _profileShellKindForHomeRoute(String homeRoute) {
  return switch (homeRoute) {
    AppRoutes.supplierHome => _ProfileShellKind.supplier,
    AppRoutes.werkaHome => _ProfileShellKind.werka,
    AppRoutes.customerHome => _ProfileShellKind.customer,
    AppRoutes.materialHome => _ProfileShellKind.materialTaminotchi,
    AppRoutes.apparatusQueue => _ProfileShellKind.aparatchi,
    AppRoutes.qolipHome => _ProfileShellKind.qolip,
    AppRoutes.boyoqchiHome => _ProfileShellKind.boyoqchi,
    AppRoutes.adminHome => _ProfileShellKind.admin,
    _ => _ProfileShellKind.none,
  };
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSegmentSurfaceCard(child: child);
  }
}

class _ProfileEditImageRow extends StatelessWidget {
  const _ProfileEditImageRow({
    required this.title,
    required this.actionLabel,
    required this.imageBytes,
    required this.fallbackIcon,
    required this.onTap,
  });

  final String title;
  final String actionLabel;
  final Uint8List? imageBytes;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 54,
                width: 54,
                child: imageBytes == null || imageBytes!.isEmpty
                    ? ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: Icon(
                          fallbackIcon,
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    : Image.memory(
                        imageBytes!,
                        fit: BoxFit.cover,
                        cacheWidth: 120,
                        filterQuality: FilterQuality.low,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    actionLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.displayName,
    required this.subtitle,
    required this.phone,
    required this.legalName,
    required this.cachedAvatarBytes,
    required this.pendingAvatarBytes,
    required this.savingAvatar,
    required this.savingProfileChanges,
    required this.hasPendingAvatar,
    required this.onPickAvatar,
    required this.onEditProfile,
    required this.onSaveProfileChanges,
  });

  final String displayName;
  final String subtitle;
  final String phone;
  final String legalName;
  final Uint8List? cachedAvatarBytes;
  final Uint8List? pendingAvatarBytes;
  final bool savingAvatar;
  final bool savingProfileChanges;
  final bool hasPendingAvatar;
  final VoidCallback onPickAvatar;
  final VoidCallback onEditProfile;
  final VoidCallback onSaveProfileChanges;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final phoneText = phone.trim();
    final legalNameText = legalName.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 204,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                top: 112,
                child: ColoredBox(color: scheme.surface),
              ),
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 112,
                child: _ProfileCoverPreview(),
              ),
              Positioned(
                right: 14,
                top: 14,
                child: _ProfileCoverActionButton(
                  icon: Icons.edit_rounded,
                  onTap: onEditProfile,
                ),
              ),
              Positioned(
                left: 16,
                top: 74,
                child: _ProfileAvatarWithCamera(
                  displayName: displayName,
                  cachedAvatarBytes: cachedAvatarBytes,
                  pendingAvatarBytes: pendingAvatarBytes,
                  savingAvatar: savingAvatar,
                  onPickAvatar: onPickAvatar,
                ),
              ),
              Positioned(
                left: 128,
                right: 16,
                top: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (phoneText.isNotEmpty || legalNameText.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (phoneText.isNotEmpty)
                      ProfileInfoChip(
                        icon: Icons.phone_rounded,
                        label: phoneText,
                      ),
                    if (legalNameText.isNotEmpty)
                      ProfileInfoChip(
                        icon: Icons.badge_rounded,
                        label: legalNameText,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (hasPendingAvatar) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: savingProfileChanges ? null : onSaveProfileChanges,
                  icon: savingProfileChanges
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(l10n.save),
                ),
              ],
              if (hasPendingAvatar) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.selectedImageNotice,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileCoverPreview extends StatelessWidget {
  const _ProfileCoverPreview();

  @override
  Widget build(BuildContext context) {
    return const ImageFade(
      image: AssetImage(_profileDefaultCoverAsset),
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      cacheWidth: 360,
      placeholder: ColoredBox(color: Colors.black),
      errorBuilder: _profileCoverErrorBuilder,
    );
  }
}

Widget _profileCoverErrorBuilder(BuildContext context, Object error) {
  return const ColoredBox(color: Colors.black);
}

class _ProfileCoverActionButton extends StatelessWidget {
  const _ProfileCoverActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.78),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 38,
          width: 38,
          child: Icon(icon, size: 20, color: scheme.onSurface),
        ),
      ),
    );
  }
}

class _ProfileAvatarWithCamera extends StatelessWidget {
  const _ProfileAvatarWithCamera({
    required this.displayName,
    required this.cachedAvatarBytes,
    required this.pendingAvatarBytes,
    required this.savingAvatar,
    required this.onPickAvatar,
  });

  final String displayName;
  final Uint8List? cachedAvatarBytes;
  final Uint8List? pendingAvatarBytes;
  final bool savingAvatar;
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: _AvatarPreview(
              displayName: displayName,
              cachedAvatarBytes: cachedAvatarBytes,
              pendingAvatarBytes: pendingAvatarBytes,
            ),
          ),
        ),
        Positioned(
          right: 2,
          bottom: 2,
          child: GestureDetector(
            onTap: savingAvatar ? null : onPickAvatar,
            child: Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileSettingsSheet extends StatelessWidget {
  const _ProfileSettingsSheet({
    required this.maxHeight,
    required this.bottomPadding,
    required this.currentLocale,
    required this.themeVariant,
    required this.isDarkMode,
    required this.hasPin,
    required this.savingPin,
    required this.biometricEnabled,
    required this.savingBiometric,
    required this.onShowPinFlow,
    required this.onRemovePin,
    required this.onToggleBiometric,
    required this.onCheckForUpdate,
    required this.onLogout,
  });

  final double maxHeight;
  final double bottomPadding;
  final Locale currentLocale;
  final AppThemeVariant themeVariant;
  final bool isDarkMode;
  final bool hasPin;
  final bool savingPin;
  final bool biometricEnabled;
  final bool savingBiometric;
  final VoidCallback onShowPinFlow;
  final VoidCallback onRemovePin;
  final ValueChanged<bool> onToggleBiometric;
  final VoidCallback onCheckForUpdate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _ProfileSelectionSheet(
      title: l10n.profileSettingsTitle,
      subtitle: l10n.profileSettingsBody,
      maxHeight: maxHeight,
      bottomPadding: bottomPadding,
      child: AppSegmentSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProfileSettingsRowPadding(
              child: _LanguagePreferenceRow(currentLocale: currentLocale),
            ),
            const SizedBox(height: 16),
            _ProfileSettingsRowPadding(
              child: _ThemeModePreferenceRow(isDark: isDarkMode),
            ),
            const SizedBox(height: 16),
            _ProfileSettingsRowPadding(
              child: _ThemePreferenceRow(variant: themeVariant),
            ),
            const SizedBox(height: 16),
            _ProfileSettingsRowPadding(
              child: _AppUpdatePreferenceRow(onTap: onCheckForUpdate),
            ),
            const SizedBox(height: 22),
            Divider(
              height: 1,
              thickness: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 22),
            Text(l10n.securityTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 14),
            _ProfileActionButton(
              primary: true,
              onPressed: savingPin ? null : onShowPinFlow,
              label: savingPin
                  ? l10n.pinSaving
                  : hasPin
                      ? l10n.pinChange
                      : l10n.pinSet,
            ),
            if (hasPin) ...[
              const SizedBox(height: 10),
              _ProfileActionButton(
                primary: false,
                onPressed: savingPin ? null : onRemovePin,
                label: l10n.pinRemove,
              ),
            ],
            const SizedBox(height: 16),
            _ProfileSettingsRowPadding(
              child: _BiometricPreferenceRow(
                enabled: biometricEnabled,
                interactive: hasPin && !savingBiometric,
                onChanged: onToggleBiometric,
              ),
            ),
            const SizedBox(height: 22),
            Divider(
              height: 1,
              thickness: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 14),
            _LogoutSettingsRow(onTap: onLogout),
          ],
        ),
      ),
    );
  }
}

class _AppUpdatePreferenceRow extends StatelessWidget {
  const _AppUpdatePreferenceRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.system_update_rounded, color: scheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.appUpdateSettingsTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.appUpdateSettingsBody,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ProfileSettingsRowPadding extends StatelessWidget {
  const _ProfileSettingsRowPadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: child,
    );
  }
}

class _LogoutSettingsRow extends StatelessWidget {
  const _LogoutSettingsRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.logout_rounded, color: scheme.error),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.logoutTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.logoutBody,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguagePreferenceRow extends StatelessWidget {
  const _LanguagePreferenceRow({required this.currentLocale});

  final Locale currentLocale;

  Future<void> _openLanguagePicker(BuildContext context) async {
    final l10n = context.l10n;
    final picked = await showModalBottomSheet<Locale>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AppMotion.sheetEaseOut,
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).maybePop(),
          child: SafeArea(
            top: false,
            bottom: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () {},
                child: _ProfileSelectionSheet(
                  title: l10n.languageTitle,
                  subtitle: l10n.languageBody,
                  child: M3SegmentSpacedColumn(
                    children: [
                      _ProfileSelectionOption(
                        index: 0,
                        itemCount: 3,
                        title: l10n.uzbek,
                        subtitle: 'Uzbek',
                        active: currentLocale.languageCode == 'uz',
                        onTap: () =>
                            Navigator.of(context).pop(const Locale('uz')),
                      ),
                      _ProfileSelectionOption(
                        index: 1,
                        itemCount: 3,
                        title: l10n.english,
                        subtitle: 'English',
                        active: currentLocale.languageCode == 'en',
                        onTap: () =>
                            Navigator.of(context).pop(const Locale('en')),
                      ),
                      _ProfileSelectionOption(
                        index: 2,
                        itemCount: 3,
                        title: l10n.russian,
                        subtitle: 'Russian',
                        active: currentLocale.languageCode == 'ru',
                        onTap: () =>
                            Navigator.of(context).pop(const Locale('ru')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (picked == null) {
      return;
    }
    await LocaleController.instance.setLocale(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openLanguagePicker(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.languageTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.languageBody,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              currentLocale.languageCode == 'uz'
                  ? l10n.uzbek
                  : currentLocale.languageCode == 'ru'
                      ? l10n.russian
                      : l10n.english,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModePreferenceRow extends StatelessWidget {
  const _ThemeModePreferenceRow({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.themeModeTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                l10n.themeModeBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _ThemeIconToggle(isDark: isDark),
      ],
    );
  }
}

class _ThemePreferenceRow extends StatelessWidget {
  const _ThemePreferenceRow({required this.variant});

  final AppThemeVariant variant;

  String _themeLabel(AppLocalizations l10n) {
    return switch (variant) {
      AppThemeVariant.classic => l10n.themeClassicLabel,
      AppThemeVariant.kalmar => l10n.themeKalmarLabel,
      AppThemeVariant.moss => l10n.themeMossLabel,
      AppThemeVariant.lavender => l10n.themeLavenderLabel,
      AppThemeVariant.bliss => l10n.themeBlissLabel,
      AppThemeVariant.white => l10n.themeWhiteLabel,
    };
  }

  Future<void> _openThemePicker(BuildContext context) async {
    final l10n = context.l10n;
    final picked = await showModalBottomSheet<AppThemeVariant>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AppMotion.sheetEaseOut,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).maybePop(),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: _ProfileSelectionSheet(
                title: l10n.themeTitle,
                subtitle: l10n.themeBody,
                maxHeight: mediaQuery.size.height * 0.72,
                bottomPadding: mediaQuery.padding.bottom + 24,
                child: M3SegmentSpacedColumn(
                  children: [
                    _ThemeSelectionOption(
                      index: 0,
                      itemCount: 6,
                      title: l10n.themeKalmarLabel,
                      active: variant == AppThemeVariant.kalmar,
                      swatches: const [
                        Color(0xFF7A4A2E),
                        Color(0xFFE8DED3),
                        Color(0xFFE1A77F),
                        Color(0xFFFFF8F3),
                      ],
                      onTap: () =>
                          Navigator.of(context).pop(AppThemeVariant.kalmar),
                    ),
                    _ThemeSelectionOption(
                      index: 1,
                      itemCount: 6,
                      title: l10n.themeClassicLabel,
                      active: variant == AppThemeVariant.classic,
                      swatches: const [
                        Color(0xFF324670),
                        Color(0xFFD8E2FF),
                        Color(0xFF53627F),
                      ],
                      onTap: () =>
                          Navigator.of(context).pop(AppThemeVariant.classic),
                    ),
                    _ThemeSelectionOption(
                      index: 2,
                      itemCount: 6,
                      title: l10n.themeMossLabel,
                      active: variant == AppThemeVariant.moss,
                      swatches: const [
                        Color(0xFF84B179),
                        Color(0xFFC7EABB),
                        Color(0xFFA2CB8B),
                      ],
                      onTap: () =>
                          Navigator.of(context).pop(AppThemeVariant.moss),
                    ),
                    _ThemeSelectionOption(
                      index: 3,
                      itemCount: 6,
                      title: l10n.themeLavenderLabel,
                      active: variant == AppThemeVariant.lavender,
                      swatches: const [
                        Color(0xFF4D4C7D),
                        Color(0xFFD8B9C3),
                        Color(0xFF827397),
                      ],
                      onTap: () =>
                          Navigator.of(context).pop(AppThemeVariant.lavender),
                    ),
                    _ThemeSelectionOption(
                      index: 4,
                      itemCount: 6,
                      title: l10n.themeBlissLabel,
                      active: variant == AppThemeVariant.bliss,
                      swatches: const [
                        Color(0xFFFFFFFF),
                        Color(0xFFEFD9CE),
                        Color(0xFF635A5A),
                        Color(0xFFFCFAF9),
                      ],
                      onTap: () =>
                          Navigator.of(context).pop(AppThemeVariant.bliss),
                    ),
                    _ThemeSelectionOption(
                      index: 5,
                      itemCount: 6,
                      title: l10n.themeWhiteLabel,
                      active: variant == AppThemeVariant.white,
                      swatches: const [
                        Color(0xFFFFFFFF),
                        Color(0xFFF5F7F8),
                        Color(0xFFCBD2D7),
                        Color(0xFF44515D),
                      ],
                      onTap: () => Navigator.of(
                        context,
                      ).pop(AppThemeVariant.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (picked == null) {
      return;
    }
    await ThemeController.instance.setVariant(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openThemePicker(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.themeTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.themeBody,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _themeLabel(l10n),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeIconToggle extends StatelessWidget {
  const _ThemeIconToggle({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return _ThemeIconButton(
      asset: isDark
          ? 'assets/icons/contrast-2-fill.svg'
          : 'assets/icons/sun-fill.svg',
      onTap: () => ThemeController.instance.setThemeMode(
        isDark ? ThemeMode.light : ThemeMode.dark,
      ),
    );
  }
}

class _ProfileSelectionSheet extends StatelessWidget {
  const _ProfileSelectionSheet({
    required this.title,
    required this.subtitle,
    required this.child,
    this.maxHeight,
    this.bottomPadding = 24,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final double? maxHeight;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight ?? double.infinity),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSelectionOption extends StatelessWidget {
  const _ProfileSelectionOption({
    required this.index,
    required this.itemCount,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.active = false,
  });

  final int index;
  final int itemCount;
  final String title;
  final String? subtitle;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final slot = M3SegmentedListGeometry.standaloneListSlotForIndex(
      index,
      itemCount,
    );
    final radius = M3SegmentedListGeometry.cornerRadiusForSlot(slot);
    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: radius,
      backgroundColor: active
          ? scheme.secondaryContainer.withValues(alpha: 0.9)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.72),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: active
                          ? scheme.onSecondaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                  if ((subtitle ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: active
                            ? scheme.onSecondaryContainer.withValues(
                                alpha: 0.74,
                              )
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: AppMotion.medium,
              curve: AppMotion.smooth,
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                color: active ? scheme.primary : Colors.transparent,
                shape: BoxShape.circle,
                border:
                    active ? null : Border.all(color: scheme.outlineVariant),
              ),
              child: active
                  ? Icon(Icons.check_rounded, size: 16, color: scheme.onPrimary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSelectionOption extends StatelessWidget {
  const _ThemeSelectionOption({
    required this.index,
    required this.itemCount,
    required this.title,
    required this.swatches,
    required this.active,
    required this.onTap,
  });

  final int index;
  final int itemCount;
  final String title;
  final List<Color> swatches;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final slot = M3SegmentedListGeometry.standaloneListSlotForIndex(
      index,
      itemCount,
    );
    final radius = M3SegmentedListGeometry.cornerRadiusForSlot(slot);
    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: radius,
      backgroundColor: active
          ? scheme.secondaryContainer.withValues(alpha: 0.9)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.72),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color:
                      active ? scheme.onSecondaryContainer : scheme.onSurface,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final swatch in swatches) ...[
                  Container(
                    height: 14,
                    width: 14,
                    decoration: BoxDecoration(
                      color: swatch,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (swatch != swatches.last) const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: AppMotion.medium,
              curve: AppMotion.smooth,
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                color: active ? scheme.primary : Colors.transparent,
                shape: BoxShape.circle,
                border:
                    active ? null : Border.all(color: scheme.outlineVariant),
              ),
              child: active
                  ? Icon(Icons.check_rounded, size: 16, color: scheme.onPrimary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeIconButton extends StatelessWidget {
  const _ThemeIconButton({required this.asset, required this.onTap});

  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool darkModeIcon = asset.contains('contrast-2-fill');
    final IconData icon =
        darkModeIcon ? Icons.dark_mode_rounded : Icons.light_mode_rounded;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOutCubic,
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: AppTheme.actionSurface(context),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          transitionBuilder: (child, animation) {
            final turns = Tween<double>(
              begin: darkModeIcon ? -0.15 : 0.15,
              end: 0,
            ).animate(animation);
            return RotationTransition(
              turns: turns,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Icon(
            icon,
            key: ValueKey<String>(asset),
            size: 22,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.primary,
    required this.onPressed,
    required this.label,
  });

  final bool primary;
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return FilledButton(onPressed: onPressed, child: Text(label));
    }
    return OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}

class _BiometricPreferenceRow extends StatelessWidget {
  const _BiometricPreferenceRow({
    required this.enabled,
    required this.interactive,
    required this.onChanged,
  });

  final bool enabled;
  final bool interactive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.biometricEnableTitle,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                enabled
                    ? l10n.biometricEnabledBody
                    : l10n.biometricDisabledBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Theme(
          data: theme.copyWith(
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return scheme.surfaceContainerHighest;
                }
                if (states.contains(WidgetState.selected)) {
                  return scheme.onPrimary;
                }
                return scheme.outline;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return scheme.surfaceContainerHighest.withValues(alpha: 0.55);
                }
                if (states.contains(WidgetState.selected)) {
                  return scheme.primary;
                }
                return scheme.surfaceContainerHighest;
              }),
              trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.transparent;
                }
                return scheme.outlineVariant;
              }),
              trackOutlineWidth: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return 0;
                }
                return 1;
              }),
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return scheme.primary.withValues(alpha: 0.12);
                }
                return Colors.transparent;
              }),
              thumbIcon: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Icon(Icons.check_rounded, size: 14);
                }
                return const Icon(Icons.close_rounded, size: 12);
              }),
            ),
          ),
          child: Switch(
            value: enabled,
            onChanged: interactive ? onChanged : null,
          ),
        ),
      ],
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({
    required this.displayName,
    required this.cachedAvatarBytes,
    required this.pendingAvatarBytes,
  });

  final String displayName;
  final Uint8List? cachedAvatarBytes;
  final Uint8List? pendingAvatarBytes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final avatarCacheWidth =
        (96 * MediaQuery.devicePixelRatioOf(context)).ceil();
    final fallback = Container(
      height: 96,
      width: 96,
      decoration: BoxDecoration(
        color: AppTheme.actionSurface(context),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        (displayName.isNotEmpty ? displayName[0] : 'U').toUpperCase(),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );

    final bytes = pendingAvatarBytes != null && pendingAvatarBytes!.isNotEmpty
        ? pendingAvatarBytes
        : cachedAvatarBytes;
    final Widget avatar;
    if (bytes == null || bytes.isEmpty) {
      avatar = fallback;
    } else {
      avatar = ClipOval(
        child: ImageFade(
          image: MemoryImage(bytes),
          height: 96,
          width: 96,
          fit: BoxFit.cover,
          cacheWidth: avatarCacheWidth,
          placeholder: fallback,
          errorBuilder: (context, error) => fallback,
        ),
      );
    }

    return ProfileAvatarPreview(
      displayName: displayName,
      avatarImage: bytes == null || bytes.isEmpty ? null : MemoryImage(bytes),
      semanticLabel: l10n.profileAvatarZoomLabel,
      child: avatar,
    );
  }
}
