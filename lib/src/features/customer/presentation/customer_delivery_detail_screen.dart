import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/hub/refresh_hub.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import 'widgets/customer_dock.dart';
import '../../shared/models/app_models.dart';
import '../state/customer_store.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

part 'customer_delivery_detail_screen__CustomerDeliveryDetailScreenState_methods_01.dart';
part 'customer_delivery_detail_screen_widgets_part_01.dart';

class _CustomerDeliveryDetailScreenState
    extends State<CustomerDeliveryDetailScreen> {
  late Future<CustomerDeliveryDetail> _future;
  bool _submitting = false;
  static const int _minRejectCommentLength = 3;

  @override
  void initState() {
    super.initState();
    _future = MobileApi.instance.customerDeliveryDetail(widget.deliveryNoteID);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: context.l10n.detailsTitle,
      subtitle: '',
      leading: AppShellIconAction(
        icon: Icons.arrow_back_rounded,
        onTap: () => Navigator.of(context).maybePop(),
      ),
      bottom: const CustomerDock(activeTab: null),
      child: FutureBuilder<CustomerDeliveryDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: AppLoadingIndicator());
          }
          if (snapshot.hasError) {
            return AppRetryState(onRetry: _reload);
          }
          final detail = snapshot.data!;
          final record = detail.record;
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          return AppRefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                Card.filled(
                  margin: EdgeInsets.zero,
                  color: scheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CustomerDetailSectionHeader(
                        label: context.l10n.shipmentInfoTitle,
                        topRounded: true,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DetailLine(
                              label: context.l10n.customerLabel,
                              value: record.supplierName,
                            ),
                            const SizedBox(height: 12),
                            _DetailLine(
                              label: context.l10n.itemLabel,
                              value: '${record.itemCode} • ${record.itemName}',
                            ),
                            const SizedBox(height: 12),
                            _DetailLine(
                              label: context.l10n.pendingStatus,
                              value:
                                  '${record.sentQty.toStringAsFixed(2)} ${record.uom}',
                            ),
                            if (record.acceptedQty > 0) ...[
                              const SizedBox(height: 12),
                              _DetailLine(
                                label: context.l10n.acceptedFromQtyPrefix,
                                value:
                                    '${record.acceptedQty.toStringAsFixed(2)} ${record.uom}',
                              ),
                            ],
                            const SizedBox(height: 12),
                            _DetailLine(
                              label: context.l10n.statusLabel,
                              value: _statusLabel(record.status),
                            ),
                          ],
                        ),
                      ),
                      if (record.note.trim().isNotEmpty) ...[
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: 18,
                          endIndent: 18,
                          color: scheme.outlineVariant.withValues(alpha: 0.55),
                        ),
                        _CustomerDetailSectionHeader(
                          label: context.l10n.noteTitle,
                          topRounded: false,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Text(
                            record.note,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                      if (record.status == DispatchStatus.accepted ||
                          record.status == DispatchStatus.partial ||
                          record.status == DispatchStatus.rejected) ...[
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: 18,
                          endIndent: 18,
                          color: scheme.outlineVariant.withValues(alpha: 0.55),
                        ),
                        _CustomerDetailSectionHeader(
                          label: context.l10n.commentsTitle,
                          topRounded: false,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _openDiscussion,
                              child: Text(context.l10n.openDiscussionAction),
                            ),
                          ),
                        ),
                      ],
                      if (detail.canApprove ||
                          detail.canReject ||
                          detail.canPartiallyAccept ||
                          detail.canReportClaim) ...[
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: 18,
                          endIndent: 18,
                          color: scheme.outlineVariant.withValues(alpha: 0.55),
                        ),
                        _CustomerDetailSectionHeader(
                          label: context.l10n.responseTitle,
                          topRounded: false,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              if (detail.canApprove)
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _submitting ? null : _approveAll,
                                    child: Text(
                                      _submitting
                                          ? context.l10n.sending
                                          : context.l10n.approveAction,
                                    ),
                                  ),
                                ),
                              if (detail.canApprove &&
                                  (detail.canPartiallyAccept ||
                                      detail.canReject))
                                const SizedBox(height: 12),
                              if (detail.canPartiallyAccept)
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.tonal(
                                    onPressed:
                                        _submitting ? null : _acceptPartial,
                                    child: Text(
                                      context.l10n.partialAcceptAction,
                                    ),
                                  ),
                                ),
                              if (detail.canPartiallyAccept && detail.canReject)
                                const SizedBox(height: 12),
                              if (detail.canReject)
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: _submitting ? null : _rejectAll,
                                    child: Text(context.l10n.rejectAction),
                                  ),
                                ),
                              if (detail.canReportClaim) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.tonal(
                                    onPressed:
                                        _submitting ? null : _reportClaim,
                                    child: Text(context.l10n.reportIssueAction),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
