import 'dart:math' as math;

import '../../../../core/session/state/app_session.dart';
import '../../../admin/presentation/widgets/admin_dock.dart';
import '../../../aparatchi/presentation/widgets/aparatchi_dock.dart';
import '../../../customer/presentation/widgets/customer_dock.dart';
import '../../../material_taminotchi/presentation/widgets/material_taminotchi_dock.dart';
import '../../../qolip/presentation/widgets/qolip_dock.dart';
import '../../../boyoqchi/presentation/widgets/boyoqchi_dock.dart';
import '../../../shared/models/app_models.dart';
import '../../../supplier/presentation/widgets/supplier_dock.dart';
import '../../../werka/presentation/widgets/werka_dock.dart';
import '../../../../core/widgets/navigation/app_navigation_bar.dart';
import 'package:flutter/material.dart';

const double chatComposerMaxHeight = 172;
const Duration chatKeyboardInsetAnimationDuration = Duration(milliseconds: 220);

class ChatKeyboardInsetLayout extends StatelessWidget {
  const ChatKeyboardInsetLayout({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext context, double keyboardInset) builder;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: mediaQuery.viewInsets.bottom),
      duration: chatKeyboardInsetAnimationDuration,
      curve: Curves.easeOutCubic,
      builder: (context, keyboardInset, _) {
        return MediaQuery(
          data: mediaQuery.copyWith(viewInsets: EdgeInsets.zero),
          child: Builder(
            builder: (context) => builder(context, keyboardInset),
          ),
        );
      },
    );
  }
}

/// Keeps the role-specific navigation visible on the conversation list and
/// provides the shared dock container for the conversation composer.
class ChatRoleDock extends StatelessWidget {
  const ChatRoleDock({
    super.key,
    this.messageComposer,
    this.composerController,
  });

  static const double messageComposerHeight = 76;
  static const double maxMessageComposerHeight = chatComposerMaxHeight;
  static const double _composerRowHeight = 44;
  static const double _composerVerticalPadding = 16;
  // Keep the resting field above the bottom edge of the dock. The same lift
  // is included in the dynamic-height calculation so multiline growth keeps
  // the field's bottom spacing unchanged.
  static const double _composerLift = 13;
  static const double _composerTopGap = messageComposerHeight -
      _composerRowHeight -
      _composerVerticalPadding -
      _composerLift;

  final Widget? messageComposer;
  final TextEditingController? composerController;

  static double composerHeight(BuildContext context, String text) {
    if (text.trim().isEmpty) {
      return messageComposerHeight;
    }

    final width = MediaQuery.sizeOf(context).width;
    final inputContentWidth = math.max(1.0, width - 106);
    final textStyle = Theme.of(context).textTheme.bodyLarge ??
        const TextStyle(fontSize: 16, height: 1.2);
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: Directionality.of(context),
      maxLines: 5,
    )..layout(maxWidth: inputContentWidth);
    final lineCount = painter.computeLineMetrics().length.clamp(1, 5);
    if (lineCount == 1) {
      return messageComposerHeight;
    }
    final inputHeight = painter.preferredLineHeight * lineCount + 20;
    final rowHeight = math.max(_composerRowHeight, inputHeight);
    return math.min(
      maxMessageComposerHeight,
      math.max(
        messageComposerHeight,
        rowHeight + _composerVerticalPadding + _composerLift + _composerTopGap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (messageComposer != null) {
      final controller = composerController;
      if (controller == null) {
        return AppNavigationBar(
          height: messageComposerHeight,
          destinations: const [],
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          content: messageComposer,
        );
      }
      return ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          return AppNavigationBar(
            height: composerHeight(context, value.text),
            destinations: const [],
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            content: messageComposer,
          );
        },
      );
    }

    final profile = AppSession.instance.profile;
    final role = profile?.accessRole ?? profile?.role;
    return switch (role) {
      UserRole.admin => const AdminDock(
          activeTab: null,
          showPrimaryFab: false,
        ),
      UserRole.werka => const WerkaDock(
          activeTab: null,
          showPrimaryFab: false,
        ),
      UserRole.supplier => const SupplierDock(
          activeTab: null,
          showPrimaryFab: false,
        ),
      UserRole.customer => const CustomerDock(activeTab: null),
      UserRole.aparatchi => const AparatchiDock(activeTab: null),
      UserRole.qolipchi => const QolipDock(activeTab: null),
      UserRole.boyoqchi => const BoyoqchiDock(activeTab: null),
      UserRole.materialTaminotchi => const MaterialTaminotchiDock(
          activeTab: null,
        ),
      null => const SizedBox.shrink(),
    };
  }
}
