import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/notifications/store/notification_unread_store.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/navigation/native_back_button.dart';
import '../../../core/widgets/display/app_status_chip.dart';
import '../../supplier/presentation/widgets/supplier_dock.dart';
import '../../supplier/state/supplier_store.dart';
import '../../werka/presentation/widgets/werka_dock.dart';
import '../models/app_models.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

part 'notification_detail_screen__NotificationDetailScreenState_methods_01.dart';
part 'notification_detail_screen_widgets_part_01.dart';

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  late Future<NotificationDetail> _future;
  final TextEditingController _commentController = TextEditingController();
  bool _sending = false;
  bool _hasCommentText = false;
  String _accountKey = '';

  @override
  void initState() {
    super.initState();
    _accountKey = _currentAccountKey();
    final profile = AppSession.instance.profile;
    if (profile?.accessRole == UserRole.customer &&
        widget.receiptID.startsWith('MAT-DN-')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.customerDetail,
          arguments: widget.receiptID,
        );
      });
      _future = Future<NotificationDetail>.value(
        const NotificationDetail(
          record: DispatchRecord(
            id: '',
            supplierRef: '',
            supplierName: '',
            itemCode: '',
            itemName: '',
            uom: '',
            sentQty: 0,
            acceptedQty: 0,
            amount: 0,
            currency: '',
            note: '',
            eventType: '',
            highlight: '',
            status: DispatchStatus.pending,
            createdLabel: '',
          ),
          comments: <NotificationComment>[],
        ),
      );
      _commentController.addListener(_handleCommentChanged);
      return;
    }
    _future = _loadAfterMarkSeen();
    _commentController.addListener(_handleCommentChanged);
  }

  @override
  void dispose() {
    _commentController.removeListener(_handleCommentChanged);
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = AppSession.instance.profile?.accessRole;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    if (_accountKey != _currentAccountKey()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _reloadForAccountChange();
      });
      return AppShell(
        leading: const _NotificationBackButton(),
        title: 'Batafsil',
        subtitle: '',
        nativeTopBar: true,
        bottom: role == UserRole.supplier
            ? const SupplierDock(activeTab: null)
            : role == UserRole.werka
                ? const WerkaDock(activeTab: null)
                : null,
        child: const Center(child: AppLoadingIndicator()),
      );
    }
    return AppShell(
      leading: const _NotificationBackButton(),
      title: 'Batafsil',
      subtitle: '',
      nativeTopBar: true,
      contentPadding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
      bottom: role == UserRole.supplier
          ? const SupplierDock(activeTab: null)
          : role == UserRole.werka
              ? const WerkaDock(activeTab: null)
              : null,
      child: FutureBuilder<NotificationDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: AppLoadingIndicator());
          }
          if (snapshot.hasError) {
            return AppRetryState(onRetry: () async => _reload());
          }

          final detail = snapshot.data!;
          final record = detail.record;
          final currentProfile = AppSession.instance.profile;
          final belongsToCurrentSupplier = role != UserRole.supplier ||
              currentProfile == null ||
              record.supplierRef.trim().isEmpty ||
              record.supplierRef.trim() == currentProfile.ref.trim();
          if (!belongsToCurrentSupplier) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              Navigator.of(context).maybePop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bu receipt sizga tegishli emas.'),
                ),
              );
            });
            return const SizedBox.shrink();
          }
          final canConfirm = role == UserRole.werka &&
              record.eventType.isEmpty &&
              (record.status == DispatchStatus.pending ||
                  record.status == DispatchStatus.draft);
          final canRespondWerkaUnannounced = role == UserRole.supplier &&
              record.eventType == 'werka_unannounced_pending';
          final isSupplierAckEvent = record.eventType == 'supplier_ack';
          final supplierAcknowledged = detail.comments.any(
            (item) =>
                item.authorLabel.startsWith('Supplier') &&
                item.body.toLowerCase().contains('tasdiqlayman'),
          );
          final canAcknowledge = role == UserRole.supplier &&
              !canRespondWerkaUnannounced &&
              !supplierAcknowledged &&
              (record.status == DispatchStatus.partial ||
                  record.status == DispatchStatus.rejected ||
                  record.status == DispatchStatus.cancelled ||
                  record.note.trim().isNotEmpty);
          final canComment = record.note.trim().isNotEmpty ||
              record.status == DispatchStatus.partial ||
              record.status == DispatchStatus.rejected ||
              record.status == DispatchStatus.cancelled;
          final canWriteIssueComment = canComment &&
              !canRespondWerkaUnannounced &&
              !isSupplierAckEvent &&
              !(role == UserRole.supplier && supplierAcknowledged);

          return AppRefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPadding),
              children: [
                _NotificationSummarySection(record: record),
                if (record.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _NotificationNoteSection(note: record.note),
                ],
                if (isSupplierAckEvent &&
                    record.highlight.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _NotificationNoteSection(
                    note: record.highlight,
                    emphasized: true,
                  ),
                ],
                if (canConfirm) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.werkaDetail, arguments: record),
                      child: const Text('Qabul qilishga o‘tish'),
                    ),
                  ),
                ],
                if (canRespondWerkaUnannounced) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _sending
                              ? null
                              : () => _respondWerkaUnannounced(false),
                          child: const Text('Rad etaman'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                          ),
                          onPressed: _sending
                              ? null
                              : () => _respondWerkaUnannounced(true),
                          child: Text(
                            _sending ? 'Yuborilmoqda...' : 'Tasdiqlayman',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (canAcknowledge) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _sending
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final bool? confirmed =
                                  await _showActionConfirmDialog(
                                title: 'Tasdiqlash',
                                message:
                                    'Haqiqatan ham shu holatni tasdiqlaysizmi?',
                                cancelLabel: 'Yo‘q',
                                confirmLabel: 'Ha',
                              );
                              if (confirmed != true) {
                                return;
                              }
                              setState(() => _sending = true);
                              try {
                                final updated = await MobileApi.instance
                                    .addNotificationComment(
                                  receiptID: widget.receiptID,
                                  message:
                                      'Tasdiqlayman, shu holat bo‘lganini ko‘rdim.',
                                );
                                if (!mounted) {
                                  return;
                                }
                                setState(() {
                                  _future = Future<NotificationDetail>.value(
                                    updated,
                                  );
                                });
                              } catch (error) {
                                if (!mounted) {
                                  return;
                                }
                                final text = '$error';
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      text.contains('forbidden')
                                          ? 'Bu receipt sizga tegishli emas.'
                                          : 'Tasdiqlash yuborilmadi: $error',
                                    ),
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _sending = false);
                                }
                              }
                            },
                      child: Text(
                        _sending ? 'Yuborilmoqda...' : 'Tasdiqlayman',
                      ),
                    ),
                  ),
                ],
                if (canWriteIssueComment) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Izohlar',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (detail.comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Text('Hozircha izoh yo‘q.'),
                    )
                  else
                    ...detail.comments.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.authorLabel,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.body,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                item.createdLabel,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 10),
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: Theme.of(
                                  context,
                                ).dividerColor.withValues(alpha: 0.45),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(hintText: 'Izoh yozing'),
                  ),
                  if (_hasCommentText) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _sending ? null : _sendComment,
                        child: Text(
                          _sending ? 'Yuborilmoqda...' : 'Comment yuborish',
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
