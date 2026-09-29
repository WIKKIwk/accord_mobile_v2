import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/localization/app_localizations.dart';

/// An order-level reminder; no roll or mold selection is needed.
class OrderAlertButton extends StatefulWidget {
  const OrderAlertButton({
    super.key,
    required this.orderId,
    required this.apparatusId,
    required this.kind,
  });

  final String orderId;
  final String apparatusId;
  final OrderAlertKind kind;

  @override
  State<OrderAlertButton> createState() => _OrderAlertButtonState();
}

class _OrderAlertButtonState extends State<OrderAlertButton> {
  String _requestId = _newRequestId();
  bool _sending = false;
  bool _sent = false;
  String? _errorCode;

  static String _newRequestId() {
    final random = Random.secure();
    return List.generate(4, (_) => random.nextInt(0x7fffffff).toRadixString(16))
        .join('-');
  }

  @override
  void didUpdateWidget(covariant OrderAlertButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId ||
        oldWidget.apparatusId != widget.apparatusId ||
        oldWidget.kind != widget.kind) {
      _requestId = _newRequestId();
      _sending = false;
      _sent = false;
      _errorCode = null;
    }
  }

  Future<void> _send() async {
    if (_sending || _sent) return;
    final requestId = _requestId;
    setState(() {
      _sending = true;
      _errorCode = null;
    });
    try {
      await MobileApi.instance.sendOrderAlert(
        orderId: widget.orderId,
        apparatus: widget.apparatusId,
        kind: widget.kind,
        requestId: requestId,
      );
      if (mounted && requestId == _requestId) setState(() => _sent = true);
    } catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() => _errorCode = error is MobileApiException
            ? error.code
            : 'order_alert_send_failed');
      }
    } finally {
      if (mounted && requestId == _requestId) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = _sent
        ? 'worker.alert.sent'
        : _sending
            ? 'worker.alert.sending'
            : widget.kind == OrderAlertKind.rawMaterial
                ? 'worker.alert.material'
                : 'worker.alert.qolip';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _sending || _sent ? null : _send,
          icon: Icon(_sent
              ? Icons.check_rounded
              : Icons.notifications_active_outlined),
          label: Text(l10n.productionText(label)),
        ),
        if (_errorCode != null)
          Text(
            l10n.productionText(switch (_errorCode) {
              'order_alert_no_recipients' => 'worker.alert.no_recipients',
              'order_alert_test_mode' => 'worker.alert.test_mode',
              _ => 'worker.alert.failed',
            }),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
