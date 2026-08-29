import 'dart:async';

import '../../../app/app_router.dart';
import '../../../features/shared/data/profile_avatar_cache.dart';
import '../../../features/auth/presentation/account_switcher_launcher.dart';
import '../../localization/app_localizations.dart';
import '../../session/session.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_theme.dart';
import '../../native_back_button_bridge.dart';
import '../../native_dock_bridge.dart';
import '../display/shared_header_title.dart';
import 'app_loading_indicator.dart';
import '../navigation/dock_gesture_overlay.dart';
import '../navigation/dock_system_bottom_inset.dart';
import '../navigation/native_back_button.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'app_shell__AppShellState_methods_01.dart';
part 'app_shell_helpers_part_01.dart';
part 'app_shell_models_part_02.dart';

const double _drawerEdgeDragWidth = 28;
const double _drawerOpenDragDistance = 48;
const double _drawerOpenDragVelocity = 450;
const double _contentHorizontalInset = 6;
const double _contentTopCornerRadius = 18;
const double _contentBottomCornerRadius = 18;
const double _contentBottomDockHeight = 60;
const double _nativeProfileActionSlotWidth = 58;

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  AnimationController? _expressiveDrawerController;
  CurvedAnimation? _expressiveDrawerCurve;
  LocalHistoryEntry? _expressiveDrawerHistory;
  double _drawerEdgeDragDelta = 0;

  @override
  void initState() {
    super.initState();
    if (widget.drawer != null) {
      _expressiveDrawerController = AnimationController(
        vsync: this,
        duration: AppMotion.expressiveDrawerDuration,
      );
      _expressiveDrawerCurve = CurvedAnimation(
        parent: _expressiveDrawerController!,
        curve: AppMotion.expressiveSpatialDefault,
        reverseCurve: AppMotion.expressiveSpatialDefault.flipped,
      );
      _expressiveDrawerController!.addStatusListener(
        _expressiveDrawerStatusChanged,
      );
    }
  }

  @override
  void dispose() {
    _expressiveDrawerHistory?.remove();
    _expressiveDrawerCurve?.dispose();
    _expressiveDrawerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final useNativeTitle =
        NativeBackButtonBridge.useNativeNavigationTitleWhenPossible(
      context,
      widget.title,
      allowWithoutBackButton: widget.preferNativeTitle,
    );
    final shouldHideLeading = widget.leading != null &&
        NativeBackButtonBridge.shouldUseNativeBackButton(context);
    final route = ModalRoute.of(context);
    final inferredBackLeading = !shouldHideLeading &&
        widget.automaticallyImplyNativeLeading &&
        widget.leading == null &&
        widget.drawer == null &&
        (route?.canPop ?? false) &&
        !(route?.isFirst ?? true);
    final compactTitleNearLeading = !shouldHideLeading &&
        (widget.drawer != null ||
            widget.leading != null ||
            inferredBackLeading);
    if (widget.bottom == null) {
      NativeDockBridge.instance.clearFromBuild();
    }

    final Widget scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      appBar: widget.nativeTopBar
          ? AppBar(
              title: widget.titleWidget ?? _nativeAppBarTitle(theme),
              leading: _nativeAppBarLeading(shouldHideLeading),
              automaticallyImplyLeading: shouldHideLeading
                  ? false
                  : widget.automaticallyImplyNativeLeading &&
                      widget.leading == null &&
                      widget.drawer == null,
              actions: _nativeAppBarActions(),
              backgroundColor: widget.backgroundColor ??
                  theme.appBarTheme.backgroundColor ??
                  theme.colorScheme.surfaceContainer,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              toolbarHeight: AppTheme.appBarHeight,
              titleSpacing: widget.titleWidget != null
                  ? 10
                  : (compactTitleNearLeading ? 0 : 20),
              centerTitle: false,
              bottom: widget.appBarBottomLoading ||
                      widget.nativeTopBarBottomInset > 0
                  ? PreferredSize(
                      preferredSize: Size.fromHeight(
                        (widget.nativeTopBarBottomInset > 0
                                ? widget.nativeTopBarBottomInset
                                : 0) +
                            (widget.appBarBottomLoading ? 3 : 0),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.nativeTopBarBottomInset > 0)
                            SizedBox(height: widget.nativeTopBarBottomInset),
                          if (widget.appBarBottomLoading)
                            _appShellStyleLinearProgress(theme),
                        ],
                      ),
                    )
                  : null,
            )
          : null,
      bottomNavigationBar: widget.bottom == null
          ? null
          : Padding(padding: widget.bottomPadding, child: widget.bottom!),
      body: SafeArea(
        bottom: false,
        child: _buildAnimatedContent(
          context,
          theme,
          shouldHideLeading,
          useNativeTitle,
          showHeader: !widget.nativeTopBar,
        ),
      ),
    );

    if (widget.drawer != null &&
        _expressiveDrawerController != null &&
        _expressiveDrawerCurve != null) {
      final controller = _expressiveDrawerController!;
      final curved = _expressiveDrawerCurve!;
      return _shellRoot(
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            // Scrim faqat chiziqli [0,1] progress bilan — Expressive cubic overshoot
            // (curved.value > 1) qora fonni bir kadrlik «qoraytirish» flashini berardi.
            final double linearT = controller.value.clamp(0.0, 1.0);
            final bool drawerBlocking =
                linearT > 0.001 || controller.isAnimating;
            return PopScope(
              canPop: !drawerBlocking,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop && drawerBlocking) {
                  _expressiveCloseDrawer();
                }
              },
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  scaffold,
                  if (!drawerBlocking)
                    PositionedDirectional(
                      start: 0,
                      top: _drawerEdgeDragTopInset(context),
                      bottom: 0,
                      width: _drawerEdgeDragWidth,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragStart: _handleDrawerEdgeDragStart,
                        onHorizontalDragUpdate: _handleDrawerEdgeDragUpdate,
                        onHorizontalDragEnd: _handleDrawerEdgeDragEnd,
                        onHorizontalDragCancel: _handleDrawerEdgeDragCancel,
                      ),
                    ),
                  if (drawerBlocking)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _expressiveCloseDrawer,
                        child: Semantics(
                          label: MaterialLocalizations.of(
                            context,
                          ).modalBarrierDismissLabel,
                          child: ColoredBox(
                            color: Colors.black.withValues(
                              alpha: 0.54 * linearT,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Offstage(
                    offstage: !drawerBlocking,
                    child: IgnorePointer(
                      ignoring: !drawerBlocking,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(-1, 0),
                          end: Offset.zero,
                        ).animate(curved),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: widget.drawer!,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return _shellRoot(scaffold);
  }
}
