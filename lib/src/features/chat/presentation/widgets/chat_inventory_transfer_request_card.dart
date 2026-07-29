import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/session/state/app_session.dart';
import '../../../shared/models/app_models.dart';
import '../../models/chat_models.dart';

class ChatInventoryTransferRequestCard extends StatefulWidget {
  const ChatInventoryTransferRequestCard({super.key, required this.data});

  final InventoryTransferRequestCardData data;

  @override
  State<ChatInventoryTransferRequestCard> createState() =>
      _ChatInventoryTransferRequestCardState();
}

class _ChatInventoryTransferRequestCardState
    extends State<ChatInventoryTransferRequestCard> {
  late String _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _status = widget.data.status;
  }

  @override
  void didUpdateWidget(covariant ChatInventoryTransferRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.eventSequence != widget.data.eventSequence ||
        oldWidget.data.status != widget.data.status) {
      _status = widget.data.status;
    }
  }

  bool get _isRequester {
    final profile = AppSession.instance.profile;
    return profile != null &&
        userRoleToJson(profile.role) == widget.data.requesterRole.trim() &&
        profile.ref.trim() == widget.data.requesterRef.trim();
  }

  bool get _isTarget {
    final profile = AppSession.instance.profile;
    return profile != null &&
        userRoleToJson(profile.role) == widget.data.targetRole.trim() &&
        profile.ref.trim() == widget.data.targetRef.trim();
  }

  Future<void> _act(String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final transfer = await MobileApi.instance.inventoryTransferAction(
        transferId: widget.data.transferId,
        action: action,
        idempotencyKey:
            'chat-transfer-${widget.data.transferId}-$action-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (mounted) setState(() => _status = transfer.status.apiValue);
    } catch (error) {
      if (mounted) {
        final message = error is MobileApiException
            ? error.message
            : 'Transfer amali bajarilmadi';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visual = _TransferStatusVisual.from(_status, scheme);
    return Semantics(
      label: 'Ombor transferi',
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            margin: const EdgeInsets.only(top: 10),
            elevation: 0,
            color: visual.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: visual.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: visual.iconBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Icons.swap_horiz_rounded,
                            color: visual.foreground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ombor transferi',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              visual.label,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: visual.foreground,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _TransferInfo(
                      label: 'Yo‘nalish',
                      value:
                          '${widget.data.sourceWarehouse} → ${widget.data.destinationWarehouse}'),
                  _TransferInfo(
                      label: 'So‘rovchi',
                      value: widget.data.requesterDisplayName),
                  for (final line in widget.data.lines)
                    _TransferInfo(
                      label: 'Mahsulot',
                      value: '${line.itemName} — ${_qty(line.qty)} ${line.uom}',
                    ),
                  if (widget.data.note.trim().isNotEmpty)
                    _TransferInfo(
                        label: 'Izoh', value: widget.data.note.trim()),
                  if (_status == 'approved' &&
                      widget.data.approvedByName.isNotEmpty)
                    _TransferInfo(
                        label: 'Tasdiqladi', value: widget.data.approvedByName),
                  if (_status == 'in_transit' &&
                      widget.data.dispatchedByName.isNotEmpty)
                    _TransferInfo(
                        label: 'Jo‘natdi', value: widget.data.dispatchedByName),
                  if (_status == 'received' &&
                      widget.data.receivedByName.isNotEmpty)
                    _TransferInfo(
                        label: 'Qabul qildi',
                        value: widget.data.receivedByName),
                  if (_status == 'rejected' &&
                      widget.data.rejectedByName.isNotEmpty)
                    _TransferInfo(
                        label: 'Rad etdi', value: widget.data.rejectedByName),
                  if (_status == 'cancelled' &&
                      widget.data.cancelledByName.isNotEmpty)
                    _TransferInfo(
                        label: 'Bekor qildi',
                        value: widget.data.cancelledByName),
                  if (_status == 'requested' &&
                      (_isTarget || _isRequester)) ...[
                    const SizedBox(height: 14),
                    if (_isTarget)
                      FilledButton(
                        onPressed: _busy ? null : () => _act('approve'),
                        child: _busy
                            ? const _CardProgress()
                            : const Text('Tasdiqlash'),
                      ),
                    if (_isTarget)
                      TextButton(
                        onPressed: _busy ? null : () => _act('reject'),
                        child: const Text('Rad etish'),
                      ),
                    if (_isRequester)
                      OutlinedButton(
                        onPressed: _busy ? null : () => _act('cancel'),
                        child: const Text('So‘rovni bekor qilish'),
                      ),
                  ],
                  if (_status == 'approved' && _isRequester) ...[
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _busy ? null : () => _act('dispatch'),
                      child: _busy
                          ? const _CardProgress()
                          : const Text('Jo‘natildi'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => _act('cancel'),
                      child: const Text('So‘rovni bekor qilish'),
                    ),
                  ],
                  if (_status == 'in_transit' && _isTarget) ...[
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _busy ? null : () => _act('receive'),
                      child: _busy
                          ? const _CardProgress()
                          : const Text('Qabul qilish'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransferInfo extends StatelessWidget {
  const _TransferInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 84,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      );
}

class _CardProgress extends StatelessWidget {
  const _CardProgress();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
}

class _TransferStatusVisual {
  const _TransferStatusVisual({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
    required this.iconBackground,
  });

  final String label;
  final Color foreground;
  final Color background;
  final Color border;
  final Color iconBackground;

  factory _TransferStatusVisual.from(String status, ColorScheme scheme) {
    final terminal = {'received', 'rejected', 'cancelled'}.contains(status);
    final success = status == 'received';
    final warning =
        status == 'requested' || status == 'approved' || status == 'in_transit';
    final foreground = success
        ? scheme.primary
        : warning
            ? scheme.tertiary
            : scheme.error;
    return _TransferStatusVisual(
      label: switch (status) {
        'approved' => 'Tasdiqlandi',
        'in_transit' => 'Yo‘lda',
        'received' => 'Qabul qilindi',
        'rejected' => 'Rad etildi',
        'cancelled' => 'Bekor qilindi',
        _ => 'Tasdiqlash kutilmoqda',
      },
      foreground: foreground,
      background: terminal
          ? scheme.surfaceContainerLow
          : scheme.surfaceContainerHighest,
      border: foreground.withValues(alpha: 0.28),
      iconBackground: foreground.withValues(alpha: 0.12),
    );
  }
}

String _qty(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
