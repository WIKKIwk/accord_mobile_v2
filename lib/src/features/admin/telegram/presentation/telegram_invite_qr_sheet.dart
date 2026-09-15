import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../models/telegram_models.dart';

class TelegramInviteQrSheet extends StatefulWidget {
  const TelegramInviteQrSheet({
    super.key,
    required this.role,
    required this.start,
    required this.poll,
    required this.submitPassword,
    required this.cancel,
  });

  final TelegramInviteRole role;
  final Future<TelegramQrLogin> Function() start;
  final Future<TelegramQrLogin> Function(String) poll;
  final Future<TelegramQrLogin> Function(String, String) submitPassword;
  final Future<void> Function(String) cancel;

  @override
  State<TelegramInviteQrSheet> createState() => _TelegramInviteQrSheetState();
}

class _TelegramInviteQrSheetState extends State<TelegramInviteQrSheet> {
  final _password = TextEditingController();
  TelegramQrLogin? _login;
  String? _error;
  bool _busy = true;
  bool _closed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _cancel(String id) async {
    try {
      await widget.cancel(id);
    } catch (_) {/* Server also expires abandoned logins. */}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _password.dispose();
    final id = _login?.loginId;
    if (id != null) unawaited(_cancel(id));
    super.dispose();
  }

  Future<void> _start() async {
    _timer?.cancel();
    final oldId = _login?.loginId;
    setState(() {
      _busy = true;
      _error = null;
      _login = null;
    });
    if (oldId != null) await _cancel(oldId);
    if (!mounted || _closed) return;
    try {
      final login = await widget.start();
      if (!mounted || _closed) {
        await _cancel(login.loginId);
        return;
      }
      _accept(login);
    } catch (error) {
      if (mounted) setState(() => _error = _code(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _schedule();
      }
    }
  }

  String _code(Object error) =>
      error is TelegramQrException ? error.code : 'transport_failed';

  void _accept(TelegramQrLogin login) {
    if (!mounted || _closed) return;
    setState(() {
      _login = login;
      _error = login.errorCode;
    });
    if (login.status == 'authorized') {
      _closed = true;
      _timer?.cancel();
      Navigator.of(context).pop(true);
    }
  }

  void _schedule() {
    final status = _login?.status;
    if (!mounted ||
        _closed ||
        _error == 'expired' ||
        status == null ||
        status == 'authorized' ||
        status == 'failed') {
      return;
    }
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), _poll);
  }

  Future<void> _poll() async {
    if (!mounted || _closed || _busy) return;
    setState(() => _busy = true);
    try {
      _accept(await widget.poll(_login!.loginId));
    } catch (error) {
      if (mounted) setState(() => _error = _code(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _schedule();
      }
    }
  }

  Future<void> _submitPassword() async {
    if (_busy || _password.text.isEmpty) return;
    _timer?.cancel();
    final password = _password.text;
    _password.clear();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _accept(await widget.submitPassword(_login!.loginId, password));
    } catch (error) {
      if (mounted) setState(() => _error = _code(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _schedule();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final login = _login;
    final passwordRequired =
        login?.status == 'password_required' && _error != 'expired';
    final qrVisible = login?.status == 'waiting' &&
        (login?.expiresAtUnix ?? 0) >
            DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final failed = login?.status == 'failed' ||
        _error == 'expired' ||
        (login == null && _error != null);
    return PopScope<bool>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _closed = true;
          _timer?.cancel();
        }
      },
      child: Material(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                24, 8, 24, 12 + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(l10n.adminTelegramQrTitle,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                  widget.role.label(
                      adminLabel: l10n.adminTelegramAdminRoleTitle,
                      salesManagerLabel:
                          l10n.adminTelegramSalesManagerRoleTitle),
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                  passwordRequired
                      ? l10n.adminTelegramQrPasswordInstruction
                      : l10n.adminTelegramQrScanInstruction,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              if (qrVisible)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(18),
                  child: QrImageView(
                    key: const ValueKey('telegram-login-qr'),
                    data: login!.qrUrl!,
                    size: 230,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square, color: Colors.black),
                    dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black),
                  ),
                )
              else if (passwordRequired) ...[
                TextField(
                  key: const ValueKey('telegram-2fa-password'),
                  controller: _password,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: l10n.adminTelegramQrPasswordLabel,
                    hintText: login?.passwordHint,
                  ),
                  onSubmitted: (_) => _submitPassword(),
                ),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: _busy ? null : _submitPassword,
                    child: Text(l10n.confirmTitle)),
              ] else if (!failed)
                const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator()),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(l10n.adminTelegramQrError(_error!),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error)),
                if (!passwordRequired)
                  TextButton(
                      onPressed: _busy ? null : _start,
                      child: Text(l10n.retry)),
              ],
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.adminTelegramQrCancel),
                  )),
            ]),
          ),
        ),
      ),
    );
  }
}
