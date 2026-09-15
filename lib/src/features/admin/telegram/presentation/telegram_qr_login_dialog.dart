import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/telegram_models.dart';

class TelegramQrLoginDialog extends StatefulWidget {
  const TelegramQrLoginDialog({
    super.key,
    required this.user,
  });

  final TelegramUserAccount user;

  @override
  State<TelegramQrLoginDialog> createState() => _TelegramQrLoginDialogState();
}

class _TelegramQrLoginDialogState extends State<TelegramQrLoginDialog> {
  TelegramQrLogin? _login;
  Timer? _pollTimer;
  bool _loading = true;
  bool _polling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startLogin();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startLogin() async {
    _pollTimer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
      _login = null;
    });
    try {
      final login = await MobileApi.instance.startTelegramUserProfileQr(
        telegramUserId: widget.user.telegramUserId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _login = login;
        _loading = false;
      });
      if (!login.isAuthorized) {
        _pollTimer = Timer.periodic(
          const Duration(seconds: 1),
          (_) => _pollStatus(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = context.l10n.adminTelegramQrFailed;
        });
      }
    }
  }

  Future<void> _pollStatus() async {
    final login = _login;
    if (_polling || login == null || login.challengeId.isEmpty) {
      return;
    }
    _polling = true;
    try {
      final updated = await MobileApi.instance.telegramUserProfileQrStatus(
        login.challengeId,
      );
      if (!mounted) {
        return;
      }
      if (updated.isAuthorized) {
        _pollTimer?.cancel();
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _login = updated;
      });
    } catch (_) {
      if (mounted) {
        _pollTimer?.cancel();
        setState(() {
          _error = context.l10n.adminTelegramQrFailed;
        });
      }
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final login = _login;
    return AlertDialog(
      title: Text(context.l10n.adminTelegramQrTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: _loading
            ? const SizedBox(
                height: 230,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? SizedBox(
                    height: 180,
                    child: Center(
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                : login?.isAuthorized == true
                    ? SizedBox(
                        height: 180,
                        child: Center(
                          child: Text(
                            context.l10n.adminTelegramQrConnected,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _QrPendingContent(
                        login: login!,
                        scheme: scheme,
                      ),
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: _startLogin,
            child: Text(context.l10n.adminTelegramQrRetry),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.adminTelegramQrCancel),
        ),
      ],
    );
  }
}

class _QrPendingContent extends StatelessWidget {
  const _QrPendingContent({
    required this.login,
    required this.scheme,
  });

  final TelegramQrLogin login;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final qrUrl = login.qrUrl;
    if (qrUrl == null || qrUrl.isEmpty) {
      return Text(context.l10n.adminTelegramQrFailed);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.adminTelegramQrScanInstruction,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: QrImageView(
              data: qrUrl,
              size: 230,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
