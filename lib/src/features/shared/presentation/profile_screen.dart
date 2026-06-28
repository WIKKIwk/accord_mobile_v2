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
import '../../../core/widgets/feedback/logout_prompt.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/lists/lists.dart';
import '../../../core/widgets/display/motion_widgets.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../data/profile_avatar_cache.dart';
import '../data/profile_cover_cache.dart';
import '../models/app_models.dart';
import '../../admin/presentation/widgets/admin_dock.dart';
import '../../supplier/presentation/widgets/supplier_dock.dart';
import '../../supplier/presentation/widgets/supplier_navigation_drawer.dart';
import '../../customer/presentation/widgets/customer_dock.dart';
import '../../customer/presentation/widgets/customer_navigation_drawer.dart';
import '../../aparatchi/presentation/widgets/aparatchi_dock.dart';
import '../../aparatchi/presentation/widgets/aparatchi_navigation_drawer.dart';
import '../../qolip/presentation/widgets/qolip_dock.dart';
import '../../qolip/presentation/widgets/qolip_navigation_drawer.dart';
import '../../werka/presentation/widgets/werka_dock.dart';
import '../../werka/presentation/widgets/werka_navigation_drawer.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const double _profilePanelGap = 4;
const String _profileAvatarHeroTag = 'profile-avatar-preview';

Widget _profileAvatarFlightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  final radiusTween = flightDirection == HeroFlightDirection.push
      ? Tween<double>(begin: 48, end: 28)
      : Tween<double>(begin: 28, end: 48);
  final child = flightDirection == HeroFlightDirection.push
      ? toHeroContext.widget
      : fromHeroContext.widget;
  return AnimatedBuilder(
    animation: curved,
    builder: (context, _) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radiusTween.evaluate(curved)),
        child: child,
      );
    },
  );
}

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
  Uint8List? cachedCoverBytes;
  Uint8List? pendingCoverBytes;
  _ProfileCoverArt? coverArt;
  int _coverArtGeneration = 0;

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
    _loadCachedAvatar();
    _loadCachedCover();
  }

  Future<void> _loadCachedAvatar() async {
    final bytes = await ProfileAvatarCache.ensureCached(profile);
    if (!mounted) {
      return;
    }
    setState(() {
      cachedAvatarBytes = bytes;
    });
    unawaited(_refreshCoverArt());
  }

  Future<void> _loadCachedCover() async {
    final bytes = await ProfileCoverCache.getCached(profile);
    if (!mounted) {
      return;
    }
    setState(() {
      cachedCoverBytes = bytes;
    });
    unawaited(_refreshCoverArt());
  }

  Future<void> _refreshProfile() async {
    final updated = await MobileApi.instance.profile();
    final bytes = await ProfileAvatarCache.ensureCached(updated);
    if (!mounted) {
      return;
    }
    setState(() {
      nicknameController.text = _normalizedDisplayName(updated);
      cachedAvatarBytes = bytes;
      pendingCoverBytes = null;
      errorMessage = null;
    });
    await _loadCachedCover();
    unawaited(_refreshCoverArt());
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
      unawaited(_refreshCoverArt());
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        errorMessage = context.l10n.imagePickFailed;
      });
    }
  }

  Future<void> _pickCover() async {
    try {
      final picked = await _avatarPicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 900,
        imageQuality: 84,
      );
      if (picked == null) {
        return;
      }
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('empty cover');
      }
      if (!mounted) {
        return;
      }
      setState(() {
        errorMessage = null;
        pendingCoverBytes = bytes;
      });
      unawaited(_refreshCoverArt());
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
      unawaited(_refreshCoverArt());
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

  void _showAvatarPreview(String displayName) {
    final bytes = pendingAvatarBytes != null && pendingAvatarBytes!.isNotEmpty
        ? pendingAvatarBytes
        : cachedAvatarBytes;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        barrierLabel:
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _AvatarPreviewOverlay(
            displayName: displayName,
            avatarBytes: bytes,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(opacity: fade, child: child);
        },
      ),
    );
  }

  Future<void> _saveProfileChanges() async {
    if (_hasNicknameChanges) {
      await _saveNickname();
    }
    if (pendingAvatarBytes != null) {
      await _saveAvatar();
    }
    if (pendingCoverBytes != null) {
      final cached = await ProfileCoverCache.cacheFromBytes(
        profile,
        pendingCoverBytes!,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        cachedCoverBytes = cached ?? pendingCoverBytes;
        pendingCoverBytes = null;
      });
      unawaited(_refreshCoverArt());
    }
  }

  Future<void> _refreshCoverArt() async {
    final source = pendingCoverBytes ??
        cachedCoverBytes ??
        pendingAvatarBytes ??
        cachedAvatarBytes;
    final generation = ++_coverArtGeneration;
    final art = await _extractProfileCoverArt(source);
    if (!mounted || generation != _coverArtGeneration) {
      return;
    }
    setState(() {
      coverArt = art;
    });
  }

  Future<void> _openProfileEditor() async {
    final editController = TextEditingController(
      text: nicknameController.text.trim(),
    );
    final previousPendingAvatarBytes = pendingAvatarBytes;
    final previousPendingAvatarName = pendingAvatarName;
    final previousPendingCoverBytes = pendingCoverBytes;
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
                    const SizedBox(height: 10),
                    _ProfileEditImageRow(
                      title: context.l10n.profileCoverTitle,
                      actionLabel: pendingCoverBytes == null
                          ? context.l10n.chooseImage
                          : context.l10n.changeImage,
                      imageBytes: pendingCoverBytes ?? cachedCoverBytes,
                      fallbackIcon: Icons.image_rounded,
                      wide: true,
                      onTap: () async {
                        await _pickCover();
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
        pendingCoverBytes = previousPendingCoverBytes;
      });
      unawaited(_refreshCoverArt());
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
          animateOnEnter: current.accessRole != UserRole.customer,
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
            _ProfileShellKind.aparatchi => AparatchiNavigationDrawer(
                selectedIndex: 1,
                onNavigate: _openAparatchiDrawerRoute,
              ),
            _ProfileShellKind.qolip => QolipNavigationDrawer(
                selectedIndex: 1,
                onNavigate: _openQolipDrawerRoute,
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
            _ProfileShellKind.aparatchi => const AparatchiDock(
                activeTab: AparatchiDockTab.profile,
              ),
            _ProfileShellKind.qolip => const QolipDock(
                activeTab: QolipDockTab.profile,
              ),
            _ProfileShellKind.admin => const AdminDock(
                activeTab: null,
                showPrimaryFab: false,
              ),
            _ProfileShellKind.none => null,
          },
          contentPadding: EdgeInsets.zero,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                    delay: const Duration(milliseconds: 20),
                    child: AppSegmentSurfaceCard(
                      padding: EdgeInsets.zero,
                      child: _ProfileHeroCard(
                        displayName: displayName,
                        subtitle: subtitle,
                        phone: current.phone,
                        legalName: effectiveLegalName,
                        cachedAvatarBytes: cachedAvatarBytes,
                        pendingAvatarBytes: pendingAvatarBytes,
                        cachedCoverBytes: cachedCoverBytes,
                        pendingCoverBytes: pendingCoverBytes,
                        coverArt: coverArt,
                        savingAvatar: savingAvatar,
                        savingProfileChanges: savingProfileChanges,
                        hasPendingAvatar: pendingAvatarBytes != null,
                        onAvatarTap: () => _showAvatarPreview(displayName),
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
}

enum _ProfileShellKind {
  supplier,
  werka,
  customer,
  aparatchi,
  qolip,
  admin,
  none,
}

_ProfileShellKind _profileShellKindForHomeRoute(String homeRoute) {
  return switch (homeRoute) {
    AppRoutes.supplierHome => _ProfileShellKind.supplier,
    AppRoutes.werkaHome => _ProfileShellKind.werka,
    AppRoutes.customerHome => _ProfileShellKind.customer,
    AppRoutes.apparatusQueue => _ProfileShellKind.aparatchi,
    AppRoutes.qolipHome => _ProfileShellKind.qolip,
    AppRoutes.adminHome => _ProfileShellKind.admin,
    _ => _ProfileShellKind.none,
  };
}

Future<_ProfileCoverArt?> _extractProfileCoverArt(Uint8List? bytes) async {
  if (bytes == null || bytes.isEmpty) {
    return null;
  }
  try {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 64,
      targetHeight: 64,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    codec.dispose();
    if (byteData == null) {
      return null;
    }
    final pixels = byteData.buffer.asUint8List();
    const sampleWidth = 64;
    const sampleHeight = 64;
    final buckets = <int, _PaletteBucket>{};
    final imageShape = _extractImageShape(pixels, sampleWidth, sampleHeight);
    for (var i = 0; i + 3 < pixels.length; i += 16) {
      final r = pixels[i];
      final g = pixels[i + 1];
      final b = pixels[i + 2];
      final a = pixels[i + 3];
      if (a < 180) {
        continue;
      }
      final key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
      buckets.putIfAbsent(key, () => _PaletteBucket()).add(r, g, b);
    }
    if (buckets.isEmpty) {
      return null;
    }
    final ranked = buckets.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final colors = <Color>[];
    for (final bucket in ranked) {
      final color = bucket.color;
      if (colors.every((picked) => _colorDistance(picked, color) > 1764)) {
        colors.add(_coverColor(color));
      }
      if (colors.length == 3) {
        break;
      }
    }
    if (colors.isEmpty) {
      return null;
    }
    while (colors.length < 3) {
      final hsl = HSLColor.fromColor(colors.first);
      if (_isNeutralColor(colors.first)) {
        colors.add(
          hsl
              .withSaturation(0.03)
              .withLightness(
                (hsl.lightness + (colors.length * 0.08)).clamp(0.34, 0.82),
              )
              .toColor(),
        );
      } else {
        colors.add(
          hsl
              .withHue((hsl.hue + (colors.length * 42)) % 360)
              .withLightness((hsl.lightness + 0.08).clamp(0.35, 0.78))
              .toColor(),
        );
      }
    }
    return _ProfileCoverArt(
      colors: colors,
      contourPoints: imageShape.contourPoints,
      edgePoints: imageShape.edgePoints,
      contrast: imageShape.contrast,
    );
  } catch (_) {
    return null;
  }
}

_ImageShape _extractImageShape(Uint8List pixels, int width, int height) {
  final luminance = List<double>.filled(width * height, 0);
  var count = 0;
  var sum = 0.0;
  for (var i = 0, pixel = 0; i + 3 < pixels.length; i += 4, pixel++) {
    if (pixel >= luminance.length) {
      break;
    }
    final a = pixels[i + 3];
    if (a < 80) {
      continue;
    }
    final value = (pixels[i] * 0.2126 +
            pixels[i + 1] * 0.7152 +
            pixels[i + 2] * 0.0722) /
        255;
    luminance[pixel] = value;
    sum += value;
    count += 1;
  }
  if (count == 0) {
    return const _ImageShape(
      contourPoints: [],
      edgePoints: [],
      contrast: 0,
    );
  }

  final mean = sum / count;
  var variance = 0.0;
  for (final value in luminance) {
    if (value == 0) {
      continue;
    }
    final delta = value - mean;
    variance += delta * delta;
  }
  final contrast = math.sqrt(variance / count).clamp(0.0, 1.0);
  final mask = List<bool>.filled(width * height, false);
  final edges = <_EdgePoint>[];
  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final i = y * width + x;
      final gx = -luminance[i - width - 1] -
          2 * luminance[i - 1] -
          luminance[i + width - 1] +
          luminance[i - width + 1] +
          2 * luminance[i + 1] +
          luminance[i + width + 1];
      final gy = -luminance[i - width - 1] -
          2 * luminance[i - width] -
          luminance[i - width + 1] +
          luminance[i + width - 1] +
          2 * luminance[i + width] +
          luminance[i + width + 1];
      final strength = gx * gx + gy * gy;
      final tonalDelta = (luminance[i] - mean).abs();
      final isShapePixel =
          tonalDelta > math.max(0.055, contrast * 0.58) || strength > 0.018;
      if (isShapePixel) {
        mask[i] = true;
      }
      if (strength > 0.014) {
        edges.add(_EdgePoint(x / (width - 1), y / (height - 1), strength));
      }
    }
  }

  final contour = <Offset>[];
  for (var y = 2; y < height - 2; y += 3) {
    var minX = width;
    var maxX = -1;
    for (var x = 2; x < width - 2; x++) {
      if (!mask[y * width + x]) {
        continue;
      }
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
    }
    if (maxX >= minX) {
      contour.add(Offset(minX / (width - 1), y / (height - 1)));
      if (maxX != minX) {
        contour.add(Offset(maxX / (width - 1), y / (height - 1)));
      }
    }
  }
  for (var x = 2; x < width - 2; x += 4) {
    var minY = height;
    var maxY = -1;
    for (var y = 2; y < height - 2; y++) {
      if (!mask[y * width + x]) {
        continue;
      }
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    if (maxY >= minY) {
      contour.add(Offset(x / (width - 1), minY / (height - 1)));
      if (maxY != minY) {
        contour.add(Offset(x / (width - 1), maxY / (height - 1)));
      }
    }
  }

  edges.sort((a, b) => b.strength.compareTo(a.strength));
  final edgePoints = <Offset>[];
  for (final edge in edges) {
    final point = Offset(edge.x, edge.y);
    if (edgePoints.every((picked) => (picked - point).distance > 0.075)) {
      edgePoints.add(point);
    }
    if (edgePoints.length == 28) {
      break;
    }
  }

  final contourPoints = _dedupeShapePoints(contour, maxCount: 56);
  return _ImageShape(
    contourPoints: contourPoints.length >= 6 ? contourPoints : edgePoints,
    edgePoints: edgePoints,
    contrast: contrast.toDouble(),
  );
}

List<Offset> _dedupeShapePoints(List<Offset> points, {required int maxCount}) {
  final result = <Offset>[];
  for (final point in points) {
    if (result.every((picked) => (picked - point).distance > 0.045)) {
      result.add(point);
    }
    if (result.length == maxCount) {
      break;
    }
  }
  return result;
}

class _ProfileCoverArt {
  const _ProfileCoverArt({
    required this.colors,
    required this.contourPoints,
    required this.edgePoints,
    required this.contrast,
  });

  final List<Color> colors;
  final List<Offset> contourPoints;
  final List<Offset> edgePoints;
  final double contrast;
}

class _ImageShape {
  const _ImageShape({
    required this.contourPoints,
    required this.edgePoints,
    required this.contrast,
  });

  final List<Offset> contourPoints;
  final List<Offset> edgePoints;
  final double contrast;
}

class _EdgePoint {
  const _EdgePoint(this.x, this.y, this.strength);

  final double x;
  final double y;
  final double strength;
}

double _colorDistance(Color a, Color b) {
  final dr = (a.r - b.r) * 255;
  final dg = (a.g - b.g) * 255;
  final db = (a.b - b.b) * 255;
  return (dr * dr + dg * dg + db * db).abs().toDouble();
}

Color _coverColor(Color color) {
  final hsl = HSLColor.fromColor(color);
  if (hsl.saturation < 0.12) {
    return hsl
        .withSaturation(0.03)
        .withLightness(hsl.lightness.clamp(0.36, 0.76))
        .toColor();
  }
  return hsl
      .withSaturation(hsl.saturation.clamp(0.22, 0.72))
      .withLightness(hsl.lightness.clamp(0.46, 0.72))
      .toColor();
}

bool _isNeutralColor(Color color) {
  return HSLColor.fromColor(color).saturation < 0.12;
}

class _PaletteBucket {
  int r = 0;
  int g = 0;
  int b = 0;
  int count = 0;

  void add(int red, int green, int blue) {
    r += red;
    g += green;
    b += blue;
    count += 1;
  }

  Color get color => Color.fromARGB(255, r ~/ count, g ~/ count, b ~/ count);

  double get score {
    final hsl = HSLColor.fromColor(color);
    final balancedLightness = 1 - (hsl.lightness - 0.56).abs();
    return count * (0.36 + hsl.saturation) * balancedLightness.clamp(0.2, 1.0);
  }
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
    this.wide = false,
  });

  final String title;
  final String actionLabel;
  final Uint8List? imageBytes;
  final IconData fallbackIcon;
  final VoidCallback onTap;
  final bool wide;

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
              borderRadius: BorderRadius.circular(wide ? 14 : 999),
              child: SizedBox(
                height: 54,
                width: wide ? 88 : 54,
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
                        cacheWidth: wide ? 220 : 120,
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
    required this.cachedCoverBytes,
    required this.pendingCoverBytes,
    required this.coverArt,
    required this.savingAvatar,
    required this.savingProfileChanges,
    required this.hasPendingAvatar,
    required this.onAvatarTap,
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
  final Uint8List? cachedCoverBytes;
  final Uint8List? pendingCoverBytes;
  final _ProfileCoverArt? coverArt;
  final bool savingAvatar;
  final bool savingProfileChanges;
  final bool hasPendingAvatar;
  final VoidCallback onAvatarTap;
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
                child: _ProfileCoverPreview(
                  displayName: displayName,
                  cachedAvatarBytes: cachedAvatarBytes,
                  pendingAvatarBytes: pendingAvatarBytes,
                  cachedCoverBytes: cachedCoverBytes,
                  pendingCoverBytes: pendingCoverBytes,
                  art: coverArt,
                ),
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
                  onAvatarTap: onAvatarTap,
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
                      _ProfileInfoChip(
                        icon: Icons.phone_rounded,
                        label: phoneText,
                      ),
                    if (legalNameText.isNotEmpty)
                      _ProfileInfoChip(
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
  const _ProfileCoverPreview({
    required this.displayName,
    required this.cachedAvatarBytes,
    required this.pendingAvatarBytes,
    required this.cachedCoverBytes,
    required this.pendingCoverBytes,
    required this.art,
  });

  final String displayName;
  final Uint8List? cachedAvatarBytes;
  final Uint8List? pendingAvatarBytes;
  final Uint8List? cachedCoverBytes;
  final Uint8List? pendingCoverBytes;
  final _ProfileCoverArt? art;

  Uint8List? get _previewBytes {
    if (pendingCoverBytes != null && pendingCoverBytes!.isNotEmpty) {
      return pendingCoverBytes;
    }
    if (cachedCoverBytes != null && cachedCoverBytes!.isNotEmpty) {
      return cachedCoverBytes;
    }
    if (pendingAvatarBytes != null && pendingAvatarBytes!.isNotEmpty) {
      return pendingAvatarBytes;
    }
    if (cachedAvatarBytes != null && cachedAvatarBytes!.isNotEmpty) {
      return cachedAvatarBytes;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bytes = _previewBytes;
    final colors = art?.colors ??
        [
          scheme.primaryContainer,
          scheme.secondaryContainer,
          scheme.tertiaryContainer,
        ];
    final fallbackLetter =
        (displayName.isNotEmpty ? displayName[0] : 'U').toUpperCase();
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _ProfileAbstractGradientPainter(
              colors: colors,
              contourPoints: art?.contourPoints ?? const [],
              edgePoints: art?.edgePoints ?? const [],
              imageContrast: art?.contrast ?? 0,
              seed: _stableCoverSeed(displayName, bytes),
              surface: scheme.surface,
            ),
          ),
        ),
        if (bytes != null)
          Positioned.fill(
            child: Opacity(
              opacity: 0.30,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Transform.scale(
                  scale: 1.34,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    cacheWidth: 360,
                    filterQuality: FilterQuality.low,
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surface.withValues(alpha: bytes == null ? 0.02 : 0.04),
                  scheme.surface.withValues(alpha: bytes == null ? 0.10 : 0.16),
                  scheme.surface.withValues(alpha: bytes == null ? 0.52 : 0.68),
                ],
                stops: const [0.0, 0.58, 1.0],
              ),
            ),
          ),
        ),
        if (bytes == null)
          Positioned(
            right: 18,
            bottom: 14,
            child: Text(
              fallbackLetter,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.16),
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
      ],
    );
  }
}

int _stableCoverSeed(String displayName, Uint8List? bytes) {
  var hash = 0x811c9dc5;
  for (final codeUnit in displayName.codeUnits) {
    hash = (hash ^ codeUnit) * 0x01000193;
  }
  if (bytes != null && bytes.isNotEmpty) {
    final step = math.max(1, bytes.length ~/ 48);
    for (var i = 0; i < bytes.length; i += step) {
      hash = (hash ^ bytes[i]) * 0x01000193;
    }
  }
  return hash & 0x7fffffff;
}

class _ProfileAbstractGradientPainter extends CustomPainter {
  const _ProfileAbstractGradientPainter({
    required this.colors,
    required this.contourPoints,
    required this.edgePoints,
    required this.imageContrast,
    required this.seed,
    required this.surface,
  });

  final List<Color> colors;
  final List<Offset> contourPoints;
  final List<Offset> edgePoints;
  final double imageContrast;
  final int seed;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final rect = Offset.zero & size;
    final artColors = _artDirectedColors(colors, surface);
    final c0 = artColors[0];
    final c1 = artColors[1];
    final c2 = artColors[2];
    final c3 = artColors[3];
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(
          -0.9 + rng.nextDouble() * 0.35,
          -1,
        ),
        end: Alignment(
          0.65 + rng.nextDouble() * 0.35,
          1,
        ),
        colors: [
          c0.withValues(alpha: 0.98),
          c1.withValues(alpha: 0.88),
          c2.withValues(alpha: 0.86),
          c3.withValues(alpha: 0.76),
        ],
        stops: const [0.0, 0.42, 0.72, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    if (contourPoints.length >= 3) {
      _drawContourShadows(canvas, size, artColors, rng);
    }
    if (edgePoints.length >= 4) {
      _drawEdgeStreaks(canvas, size, artColors, rng);
    }
    for (var i = 0; i < 5; i++) {
      _drawPetalVeil(
        canvas,
        size,
        rng: rng,
        color: artColors[i % artColors.length],
        index: i,
      );
    }

    _drawFlowBlob(
      canvas,
      size,
      center: Offset(size.width * 0.18, size.height * 0.08),
      radius: size.width * (0.52 + rng.nextDouble() * 0.18),
      color: c1.withValues(alpha: 0.30),
    );
    _drawFlowBlob(
      canvas,
      size,
      center: Offset(size.width * (0.72 + rng.nextDouble() * 0.16), -8),
      radius: size.width * (0.46 + rng.nextDouble() * 0.20),
      color: c2.withValues(alpha: 0.28),
    );
    _drawFlowBlob(
      canvas,
      size,
      center: Offset(size.width * (0.22 + rng.nextDouble() * 0.20),
          size.height * (0.82 + rng.nextDouble() * 0.12)),
      radius: size.width * 0.48,
      color: c3.withValues(alpha: 0.22),
    );

    for (var i = 0; i < 5; i++) {
      final path = Path();
      final startY = size.height * (0.18 + rng.nextDouble() * 0.52);
      path.moveTo(-size.width * 0.18, startY);
      path.cubicTo(
        size.width * (0.18 + rng.nextDouble() * 0.20),
        startY - size.height * (0.38 + rng.nextDouble() * 0.28),
        size.width * (0.52 + rng.nextDouble() * 0.20),
        startY + size.height * (0.24 + rng.nextDouble() * 0.34),
        size.width * 1.18,
        size.height * (0.20 + rng.nextDouble() * 0.62),
      );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * (0.16 + rng.nextDouble() * 0.22)
        ..strokeCap = StrokeCap.round
        ..color = (i.isEven ? surface : artColors[i % artColors.length])
            .withValues(alpha: i.isEven ? 0.22 : 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
      canvas.drawPath(path, paint);
    }

    final washPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.12, -0.18),
        radius: 1.0,
        colors: [
          surface.withValues(alpha: 0.08),
          surface.withValues(alpha: 0.02),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, washPaint);
  }

  void _drawContourShadows(
    Canvas canvas,
    Size size,
    List<Color> artColors,
    math.Random rng,
  ) {
    final centroid = contourPoints.fold<Offset>(
          Offset.zero,
          (sum, point) => sum + point,
        ) /
        contourPoints.length.toDouble();
    final sorted = [...contourPoints]..sort((a, b) {
        final aa = math.atan2(a.dy - centroid.dy, a.dx - centroid.dx);
        final bb = math.atan2(b.dy - centroid.dy, b.dx - centroid.dx);
        return aa.compareTo(bb);
      });
    for (var layer = 0; layer < 5; layer++) {
      final scale = 1.18 + layer * 0.23 + imageContrast * 0.34;
      final offset = Offset(
        size.width * (-0.12 + rng.nextDouble() * 0.18 + layer * 0.032),
        size.height * (-0.14 + rng.nextDouble() * 0.22 - layer * 0.010),
      );
      final path = Path();
      for (var i = 0; i < sorted.length; i++) {
        final p = _growPoint(sorted[i], centroid, scale, size, offset);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
          continue;
        }
        final prev = _growPoint(sorted[i - 1], centroid, scale, size, offset);
        final mid = Offset((prev.dx + p.dx) / 2, (prev.dy + p.dy) / 2);
        path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      }
      final first = _growPoint(sorted.first, centroid, scale, size, offset);
      path.quadraticBezierTo(first.dx, first.dy, first.dx, first.dy);
      path.close();
      final bounds = path.getBounds().inflate(size.width * 0.12);
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          center: Alignment(
            -0.35 + layer * 0.22,
            -0.38 + rng.nextDouble() * 0.44,
          ),
          radius: 1.0,
          colors: [
            artColors[layer % artColors.length]
                .withValues(alpha: 0.26 + imageContrast * 0.28),
            surface.withValues(alpha: 0.04 + imageContrast * 0.06),
            artColors[(layer + 1) % artColors.length]
                .withValues(alpha: 0.08 + imageContrast * 0.10),
          ],
        ).createShader(bounds)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          18 + layer * 6 + imageContrast * 14,
        );
      canvas.drawPath(path, paint);
    }
  }

  void _drawEdgeStreaks(
    Canvas canvas,
    Size size,
    List<Color> artColors,
    math.Random rng,
  ) {
    final sorted = [...edgePoints]
      ..sort((a, b) => (a.dx + a.dy).compareTo(b.dx + b.dy));
    final count = math.min(sorted.length - 1, 12);
    for (var i = 0; i < count; i++) {
      final a = sorted[i];
      final b = sorted[(i + 3).clamp(0, sorted.length - 1)];
      final start = Offset(a.dx * size.width, a.dy * size.height);
      final end = Offset(b.dx * size.width, b.dy * size.height);
      final lift = Offset(
        size.width * (-0.12 + rng.nextDouble() * 0.24),
        size.height * (-0.22 + rng.nextDouble() * 0.18),
      );
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + size.width * (0.10 + rng.nextDouble() * 0.24),
          start.dy - size.height * (0.18 + rng.nextDouble() * 0.20),
          end.dx + lift.dx,
          end.dy + lift.dy,
          end.dx + size.width * (0.10 + rng.nextDouble() * 0.22),
          end.dy - size.height * (0.04 + rng.nextDouble() * 0.18),
        );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * (0.055 + rng.nextDouble() * 0.075)
        ..strokeCap = StrokeCap.round
        ..color = artColors[(i + 1) % artColors.length]
            .withValues(alpha: 0.18 + imageContrast * 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13);
      canvas.drawPath(path, paint);
    }
  }

  Offset _growPoint(
    Offset point,
    Offset centroid,
    double scale,
    Size size,
    Offset offset,
  ) {
    final grown = centroid + (point - centroid) * scale;
    return Offset(grown.dx * size.width, grown.dy * size.height) + offset;
  }

  List<Color> _artDirectedColors(List<Color> source, Color surface) {
    if (source.every(_isNeutralColor)) {
      final hsl = HSLColor.fromColor(source.first);
      final base = hsl.withSaturation(0.02);
      return [
        base.withLightness(0.30).toColor(),
        base.withLightness(0.48).toColor(),
        base.withLightness(0.72).toColor(),
        base.withLightness(0.88).toColor(),
      ];
    }
    return [
      source[0],
      source[1],
      source[2],
      HSLColor.fromColor(source[1])
          .withHue((HSLColor.fromColor(source[1]).hue + 24) % 360)
          .withLightness(
            (HSLColor.fromColor(source[1]).lightness + 0.16).clamp(0.54, 0.86),
          )
          .toColor(),
    ];
  }

  void _drawPetalVeil(
    Canvas canvas,
    Size size, {
    required math.Random rng,
    required Color color,
    required int index,
  }) {
    final startX = size.width * (-0.16 + rng.nextDouble() * 0.34);
    final startY = size.height * (0.18 + rng.nextDouble() * 0.58);
    final endX = size.width * (0.82 + rng.nextDouble() * 0.36);
    final endY = size.height * (-0.04 + rng.nextDouble() * 0.86);
    final lift = size.height * (0.32 + rng.nextDouble() * 0.36);
    final thickness = size.height * (0.28 + rng.nextDouble() * 0.30);
    final path = Path()
      ..moveTo(startX, startY)
      ..cubicTo(
        size.width * (0.20 + rng.nextDouble() * 0.18),
        startY - lift,
        size.width * (0.42 + rng.nextDouble() * 0.24),
        endY + lift * 0.22,
        endX,
        endY,
      )
      ..cubicTo(
        size.width * (0.54 + rng.nextDouble() * 0.24),
        endY + thickness,
        size.width * (0.18 + rng.nextDouble() * 0.20),
        startY + thickness * 0.72,
        startX - size.width * 0.10,
        startY + thickness * 0.28,
      )
      ..close();

    final bounds = path.getBounds().inflate(size.width * 0.08);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: index.isEven ? 0.26 : 0.18),
          surface.withValues(alpha: index.isEven ? 0.08 : 0.05),
          color.withValues(alpha: 0.06),
        ],
      ).createShader(bounds)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawPath(path, paint);
  }

  void _drawFlowBlob(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _ProfileAbstractGradientPainter oldDelegate) {
    return oldDelegate.seed != seed ||
        oldDelegate.surface != surface ||
        oldDelegate.colors.length != colors.length ||
        oldDelegate.contourPoints.length != contourPoints.length ||
        oldDelegate.edgePoints.length != edgePoints.length ||
        oldDelegate.imageContrast != imageContrast ||
        !_sameColors(oldDelegate.colors, colors) ||
        !_samePoints(oldDelegate.contourPoints, contourPoints) ||
        !_samePoints(oldDelegate.edgePoints, edgePoints);
  }

  bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  bool _samePoints(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
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
    required this.onAvatarTap,
    required this.onPickAvatar,
  });

  final String displayName;
  final Uint8List? cachedAvatarBytes;
  final Uint8List? pendingAvatarBytes;
  final bool savingAvatar;
  final VoidCallback onAvatarTap;
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context)
                    .colorScheme
                    .shadow
                    .withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: _AvatarPreview(
              displayName: displayName,
              cachedAvatarBytes: cachedAvatarBytes,
              pendingAvatarBytes: pendingAvatarBytes,
              onTap: onAvatarTap,
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

class _ProfileInfoChip extends StatelessWidget {
  const _ProfileInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
      AppThemeVariant.blush => l10n.themeBlushLabel,
      AppThemeVariant.moss => l10n.themeMossLabel,
      AppThemeVariant.lavender => l10n.themeLavenderLabel,
      AppThemeVariant.slate => l10n.themeSlateLabel,
      AppThemeVariant.ocean => l10n.themeOceanLabel,
      AppThemeVariant.blackEdition => l10n.themeBlackEditionLabel,
      AppThemeVariant.bingsu => l10n.themeBingsuLabel,
      AppThemeVariant.bliss => l10n.themeBlissLabel,
      AppThemeVariant.dollar => l10n.themeDollarLabel,
      AppThemeVariant.fleuriste => l10n.themeFleuristeLabel,
      AppThemeVariant.paleNimbus => l10n.themePaleNimbusLabel,
      AppThemeVariant.earthy => l10n.themeEarthLabel,
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
                      itemCount: 13,
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
                      index: 1,
                      itemCount: 13,
                      title: l10n.themeEarthLabel,
                      active: variant == AppThemeVariant.earthy,
                      swatches: const [
                        Color(0xFF8A7650),
                        Color(0xFFDBCEA5),
                        Color(0xFF8E977D),
                      ],
                      onTap: () =>
                          Navigator.of(context).pop(AppThemeVariant.earthy),
                    ),
                    _ThemeSelectionOption(
                      index: 2,
                      itemCount: 13,
                      title: l10n.themeBlushLabel,
                      active: variant == AppThemeVariant.blush,
                      swatches: const [
                        Color(0xFFF5AFAF),
                        Color(0xFFF9DFDF),
                        Color(0xFFFBEFEF),
                      ],
                      onTap: () =>
                          Navigator.of(context).pop(AppThemeVariant.blush),
                    ),
                    _ThemeSelectionOption(
                      index: 3,
                      itemCount: 13,
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
                      index: 4,
                      itemCount: 13,
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
                      index: 5,
                      itemCount: 13,
                      title: l10n.themeSlateLabel,
                      active: variant == AppThemeVariant.slate,
                      swatches: const [
                        Color(0xFF30364F),
                        Color(0xFFACBAC4),
                        Color(0xFFE1D9BC),
                      ],
                      onTap: () =>
                          Navigator.of(context).pop(AppThemeVariant.slate),
                    ),
                    _ThemeSelectionOption(
                      index: 6,
                      itemCount: 13,
                      title: l10n.themeBlackEditionLabel,
                      active: variant == AppThemeVariant.blackEdition,
                      swatches: const [
                        Color(0xFF000000),
                        Color(0xFF0D0F10),
                        Color(0xFF202427),
                        Color(0xFFAEB4BA),
                      ],
                      onTap: () => Navigator.of(
                        context,
                      ).pop(AppThemeVariant.blackEdition),
                    ),
                    _ThemeSelectionOption(
                      index: 7,
                      itemCount: 13,
                      title: l10n.themeOceanLabel,
                      active: variant == AppThemeVariant.ocean,
                      swatches: const [
                        Color(0xFF1C4D8D),
                        Color(0xFF4988C4),
                        Color(0xFFBDE8F5),
                      ],
                      onTap: () =>
                          Navigator.of(context).pop(AppThemeVariant.ocean),
                    ),
                    _ThemeSelectionOption(
                      index: 8,
                      itemCount: 13,
                      title: l10n.themeBingsuLabel,
                      active: variant == AppThemeVariant.bingsu,
                      swatches: const [
                        Color(0xFFE5DFE5),
                        Color(0xFF8E7381),
                        Color(0xFF4A3E45),
                        Color(0xFFF2F0F2),
                      ],
                      onTap: () =>
                          Navigator.of(context).pop(AppThemeVariant.bingsu),
                    ),
                    _ThemeSelectionOption(
                      index: 9,
                      itemCount: 13,
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
                      index: 10,
                      itemCount: 13,
                      title: l10n.themeDollarLabel,
                      active: variant == AppThemeVariant.dollar,
                      swatches: const [
                        Color(0xFF5E635E),
                        Color(0xFF7A8B7A),
                        Color(0xFF96A176),
                        Color(0xFF4A4F4A),
                      ],
                      onTap: () =>
                          Navigator.of(context).pop(AppThemeVariant.dollar),
                    ),
                    _ThemeSelectionOption(
                      index: 11,
                      itemCount: 13,
                      title: l10n.themeFleuristeLabel,
                      active: variant == AppThemeVariant.fleuriste,
                      swatches: const [
                        Color(0xFF0A140F),
                        Color(0xFF4A5F58),
                        Color(0xFF633F4D),
                        Color(0xFF0D1A14),
                      ],
                      onTap: () => Navigator.of(
                        context,
                      ).pop(AppThemeVariant.fleuriste),
                    ),
                    _ThemeSelectionOption(
                      index: 12,
                      itemCount: 13,
                      title: l10n.themePaleNimbusLabel,
                      active: variant == AppThemeVariant.paleNimbus,
                      swatches: const [
                        Color(0xFFFFFFE3),
                        Color(0xFFA3FFD1),
                        Color(0xFFFFA3A3),
                        Color(0xFFFFFFF0),
                      ],
                      onTap: () => Navigator.of(
                        context,
                      ).pop(AppThemeVariant.paleNimbus),
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
    required this.onTap,
  });

  final String displayName;
  final Uint8List? cachedAvatarBytes;
  final Uint8List? pendingAvatarBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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

    Widget avatar;
    if (pendingAvatarBytes != null && pendingAvatarBytes!.isNotEmpty) {
      avatar = ClipOval(
        child: Image.memory(
          pendingAvatarBytes!,
          height: 96,
          width: 96,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      );
    } else if (cachedAvatarBytes == null || cachedAvatarBytes!.isEmpty) {
      avatar = fallback;
    } else {
      avatar = ClipOval(
        child: Image.memory(
          cachedAvatarBytes!,
          height: 96,
          width: 96,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      );
    }

    return Semantics(
      button: true,
      label: l10n.profileAvatarZoomLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Hero(
          tag: _profileAvatarHeroTag,
          createRectTween: (begin, end) {
            return MaterialRectCenterArcTween(begin: begin, end: end);
          },
          flightShuttleBuilder: _profileAvatarFlightShuttleBuilder,
          child: avatar,
        ),
      ),
    );
  }
}

class _AvatarPreviewOverlay extends StatelessWidget {
  const _AvatarPreviewOverlay({
    required this.displayName,
    required this.avatarBytes,
  });

  final String displayName;
  final Uint8List? avatarBytes;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final previewWidth = (size.width - 32).clamp(260.0, 420.0);
    final previewHeight =
        (previewWidth * 1.25).clamp(280.0, size.height * 0.72);
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 3,
                child: Hero(
                  tag: _profileAvatarHeroTag,
                  createRectTween: (begin, end) {
                    return MaterialRectCenterArcTween(
                      begin: begin,
                      end: end,
                    );
                  },
                  flightShuttleBuilder: _profileAvatarFlightShuttleBuilder,
                  child: _LargeAvatarPreview(
                    displayName: displayName,
                    avatarBytes: avatarBytes,
                    width: previewWidth,
                    height: previewHeight,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LargeAvatarPreview extends StatelessWidget {
  const _LargeAvatarPreview({
    required this.displayName,
    required this.avatarBytes,
    required this.width,
    required this.height,
  });

  final String displayName;
  final Uint8List? avatarBytes;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppTheme.actionSurface(context),
        borderRadius: BorderRadius.circular(28),
      ),
      alignment: Alignment.center,
      child: Text(
        (displayName.isNotEmpty ? displayName[0] : 'U').toUpperCase(),
        style: Theme.of(context).textTheme.displayMedium,
      ),
    );

    final bytes = avatarBytes;
    if (bytes == null || bytes.isEmpty) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Image.memory(
        bytes,
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}
