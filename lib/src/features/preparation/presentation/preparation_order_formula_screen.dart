import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import 'preparation_navigation.dart';

/// Tayyorlov masteri uchun alohida formula sahifasi.
/// Hozircha skelet — keyingi logicalar shu yerga qo'shiladi.
///
/// Top bar + bottom navbar va kirish/chiqish animatsiyalari
/// boshqa sahifalar bilan bir xil (reuse):
/// - [AppShell] + [PreparationDock] (native top bar)
/// - [PreparationOrderFormulaRoute] ([AppMotion.pageEnter]/[pageExit]).
class PreparationOrderFormulaScreen extends StatelessWidget {
  const PreparationOrderFormulaScreen({
    super.key,
    required this.orderId,
    required this.orderCode,
    required this.productTitle,
    this.customerName,
  });

  final String orderId;
  final String orderCode;
  final String productTitle;
  final String? customerName;

  static Route<void> route({
    required String orderId,
    required String orderCode,
    required String productTitle,
    String? customerName,
  }) {
    return PreparationOrderFormulaRoute(
      builder: (_) => PreparationOrderFormulaScreen(
        orderId: orderId,
        orderCode: orderCode,
        productTitle: productTitle,
        customerName: customerName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final customer = customerName?.trim() ?? '';
    final subtitle = customer.isEmpty
        ? productTitle
        : productTitle.isEmpty
            ? customer
            : '$customer • $productTitle';
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;

    return AppShell(
      title: 'Formulalar',
      subtitle: orderCode.isEmpty ? '' : orderCode,
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      contentPadding: EdgeInsets.zero,
      // Drawer yo'q — AppShell avtomatik back tugmani chiqaradi.
      // Bottom navbar boshqa tayyorlov sahifalari bilan bir xil.
      bottom: const PreparationDock(),
      child: ListView(
        padding: EdgeInsets.only(bottom: bottomPadding),
        children: [
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Card(
              margin: EdgeInsets.zero,
              color: scheme.surfaceContainerLowest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zakaz kodi: ${orderCode.isEmpty ? '-' : orderCode}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Order ID: ${orderId.isEmpty ? '-' : orderId}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.functions_rounded,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Formula logikalari keyingi bosqichda shu yerga qo‘shiladi.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barcha sahifalar bilan bir xil kirish/chiqish animatsiyasi.
/// [AppRoutes] dagi `_AppMaterialPageRoute` bilan 1:1
/// ([AppMotion.pageEnter]/[AppMotion.pageExit]).
class PreparationOrderFormulaRoute<T> extends MaterialPageRoute<T> {
  PreparationOrderFormulaRoute({
    required super.builder,
    super.settings,
  });

  @override
  Duration get transitionDuration => AppMotion.pageEnter;

  @override
  Duration get reverseTransitionDuration => AppMotion.pageExit;
}
