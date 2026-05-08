import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/hub/refresh_hub.dart';
import '../../../core/notifications/store/werka_runtime_store.dart';
import '../../../core/search/search_activity_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'werka_archive_batch_qr.dart';
import 'werka_success_screen.dart';

class WerkaArchiveBatchQrLookupArgs {
  const WerkaArchiveBatchQrLookupArgs({
    required this.payload,
  });

  final WerkaArchiveBatchQrPayload payload;
}

class WerkaArchiveBatchQrLookupScreen extends StatefulWidget {
  const WerkaArchiveBatchQrLookupScreen({
    super.key,
    required this.args,
  });

  final WerkaArchiveBatchQrLookupArgs args;

  @override
  State<WerkaArchiveBatchQrLookupScreen> createState() =>
      _WerkaArchiveBatchQrLookupScreenState();
}

class _WerkaArchiveBatchQrLookupScreenState
    extends State<WerkaArchiveBatchQrLookupScreen> {
  late Future<CustomerItemOption> _future;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = _resolveItem();
  }

  Future<CustomerItemOption> _resolveItem() async {
    final payload = widget.args.payload;
    final options = await MobileApi.instance.werkaCustomerItemOptions(
      query: payload.itemName,
      limit: 200,
    );
    if (options.isEmpty) {
      throw StateError('batch_item_not_found');
    }

    final normalizedItem = _normalize(payload.itemName);
    return options.firstWhere(
      (option) =>
          _normalize(option.itemName) == normalizedItem ||
          _normalize(option.itemCode) == normalizedItem,
      orElse: () => options.first,
    );
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toStringAsFixed(0);
    }
    return qty
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  Future<void> _send(CustomerItemOption option) async {
    final payload = widget.args.payload;
    final l10n = context.l10n;
    if (option.customerRef.trim().isEmpty || option.itemCode.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer yoki mahsulot topilmadi.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final created = await MobileApi.instance.createWerkaCustomerIssue(
        customerRef: option.customerRef,
        itemCode: option.itemCode,
        qty: payload.qty,
      );
      await SearchActivityStore.instance.recordItemSelection(created.itemCode);
      if (!mounted) {
        return;
      }

      final record = DispatchRecord(
        id: created.entryID,
        supplierRef: created.customerRef,
        supplierName: created.customerName,
        itemCode: created.itemCode,
        itemName: created.itemName,
        uom: created.uom,
        sentQty: created.qty,
        acceptedQty: 0,
        amount: 0,
        currency: '',
        note: '',
        eventType: 'customer_issue_pending',
        highlight: '',
        status: DispatchStatus.pending,
        createdLabel: created.createdLabel,
      );
      WerkaRuntimeStore.instance.recordCreatedPending(record);
      RefreshHub.instance.emit('werka');
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.werkaSuccess,
        (route) => route.isFirst,
        arguments: WerkaSuccessArgs(
          record: record,
          returnRouteName: AppRoutes.werkaStockEntryQrScan,
          returnLabel: 'QR scan ga qaytish',
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message =
          error is MobileApiException && error.code == 'insufficient_stock'
              ? l10n.insufficientStockMessage
              : l10n.customerIssueFailed(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final payload = widget.args.payload;

    return AppShell(
      title: 'Batch QR',
      subtitle: payload.sessionID,
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      contentPadding: EdgeInsets.zero,
      backgroundColor: scheme.surface,
      child: FutureBuilder<CustomerItemOption>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _ArchiveBatchQrPanel(
              payload: payload,
              title: payload.itemName,
              subtitle: 'Mahsulot customer ro‘yxatidan qidirilmoqda...',
              trailing: const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              formatQty: _formatQty,
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return _ArchiveBatchQrPanel(
              payload: payload,
              title: 'Mahsulot topilmadi',
              subtitle:
                  'Batch QR ichidagi mahsulot customer jo‘natish ro‘yxatidan topilmadi.',
              trailing: Icon(
                Icons.error_outline_rounded,
                color: scheme.error,
              ),
              formatQty: _formatQty,
              showScanActions: true,
            );
          }

          final option = snapshot.data!;
          return _ArchiveBatchQrPanel(
            payload: payload,
            title: option.itemName,
            subtitle: option.customerName,
            trailing: Icon(
              Icons.check_circle_rounded,
              color: scheme.primary,
            ),
            formatQty: _formatQty,
            resolvedOption: option,
            isSubmitting: _submitting,
            onSend: _submitting ? null : () => _send(option),
            showScanActions: true,
          );
        },
      ),
    );
  }
}

class _ArchiveBatchQrPanel extends StatelessWidget {
  const _ArchiveBatchQrPanel({
    required this.payload,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.formatQty,
    this.resolvedOption,
    this.isSubmitting = false,
    this.onSend,
    this.showScanActions = false,
  });

  final WerkaArchiveBatchQrPayload payload;
  final String title;
  final String subtitle;
  final Widget trailing;
  final String Function(double qty) formatQty;
  final CustomerItemOption? resolvedOption;
  final bool isSubmitting;
  final Future<void> Function()? onSend;
  final bool showScanActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final option = resolvedOption;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 112),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    trailing,
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Netto',
                        value: '${formatQty(payload.nettoQty)} Kg',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricTile(
                        label: 'Brutto',
                        value: '${formatQty(payload.bruttoQty)} Kg',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'Session', value: payload.sessionID),
                if (payload.batchTime.trim().isNotEmpty)
                  _InfoRow(label: 'Sana', value: payload.batchTime),
                if (option != null)
                  _InfoRow(label: 'Kod', value: option.itemCode),
                if (option?.warehouse.trim().isNotEmpty ?? false)
                  _InfoRow(
                    label: 'Ombor',
                    value: option!.warehouse,
                    icon: Icons.warehouse_outlined,
                  ),
                if (onSend != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () {
                              final send = onSend;
                              if (send != null) {
                                send();
                              }
                            },
                      icon: isSubmitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          : const Icon(Icons.local_shipping_outlined),
                      label: Text(
                        isSubmitting
                            ? 'Jo‘natilmoqda...'
                            : 'Customerga jo‘natish',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showScanActions) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).pushReplacementNamed(
                    AppRoutes.werkaStockEntryQrScan,
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Qayta scan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Ortga'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value.isEmpty ? '—' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayValue = value.trim().isEmpty ? '—' : value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displayValue,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
