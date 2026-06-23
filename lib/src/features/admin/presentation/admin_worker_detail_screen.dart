import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/timers/retry_after_countdown.dart';
import '../../../core/widgets/buttons/app_action_button_styles.dart';
import '../../../core/widgets/display/app_detail_field.dart';
import '../../../core/widgets/display/app_status_chip.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';

const double _workerDetailPanelGap = 4;
const double _workerDetailCardRadius = 18;
const double _workerDetailFieldRadius = 14;

class AdminWorkerDetailScreen extends StatefulWidget {
  const AdminWorkerDetailScreen({super.key, required this.entry});

  final AdminUserListEntry entry;

  @override
  State<AdminWorkerDetailScreen> createState() =>
      _AdminWorkerDetailScreenState();
}

class _AdminWorkerDetailScreenState extends State<AdminWorkerDetailScreen> {
  AdminWorkerDetail? _detail;
  Object? _loadError;
  bool _loading = true;
  bool _savingPhone = false;
  bool _regeneratingCode = false;
  bool _changed = false;
  late final RetryAfterCountdown _retryAfter;
  int get _retryAfterSec => _retryAfter.seconds;

  String get _workerId => widget.entry.id.trim();

  @override
  void initState() {
    super.initState();
    _retryAfter = RetryAfterCountdown(onChanged: _refreshRetryAfter);
    unawaited(_reload());
  }

  @override
  void dispose() {
    _retryAfter.dispose();
    super.dispose();
  }

  void _refreshRetryAfter() {
    if (mounted) {
      setState(() {});
    }
  }

  void _setRetryAfter(int seconds) => _retryAfter.set(seconds);

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final detail =
          await MobileApi.instance.adminWorkerDetail(_workerId).timeout(
                const Duration(seconds: 15),
                onTimeout: () => throw Exception('Worker detail timeout'),
              );
      if (!mounted) {
        return;
      }
      _setRetryAfter(detail.codeRetryAfterSec);
      setState(() {
        _detail = detail;
        _loadError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _addPhone(AdminWorkerDetail detail) async {
    final controller = TextEditingController(text: detail.phone);
    final phone = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_workerDetailCardRadius),
          ),
          title: const Text('Telefon raqam qo‘shish'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '+998901234567',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(_workerDetailFieldRadius),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: appOutlinedActionButtonStyle(
                        borderRadius: _workerDetailFieldRadius,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Bekor qilish'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: appFilledActionButtonStyle(
                        borderRadius: _workerDetailFieldRadius,
                      ),
                      onPressed: () =>
                          Navigator.of(context).pop(controller.text.trim()),
                      child: const Text('Saqlash'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (phone == null || phone.trim().isEmpty) {
      return;
    }

    setState(() => _savingPhone = true);
    try {
      final updated = await MobileApi.instance.adminUpdateWorkerPhone(
        id: detail.id,
        phone: phone,
      );
      if (!mounted) {
        return;
      }
      _changed = true;
      setState(() {
        _detail = detail.copyWith(phone: updated.phone);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Telefon saqlanmadi: $error')));
    } finally {
      if (mounted) {
        setState(() => _savingPhone = false);
      }
    }
  }

  Future<void> _regenerateCode() async {
    setState(() => _regeneratingCode = true);
    try {
      final updated = await MobileApi.instance.adminRegenerateWorkerCode(
        _workerId,
      );
      if (!mounted) {
        return;
      }
      _changed = true;
      _setRetryAfter(updated.codeRetryAfterSec);
      setState(() => _detail = updated);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Code yangilanmadi: $error')));
    } finally {
      if (mounted) {
        setState(() => _regeneratingCode = false);
      }
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Code nusxalandi')));
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail ??
        AdminWorkerDetail(
          id: _workerId,
          name: widget.entry.name,
          phone: _loading ? 'Yuklanmoqda...' : widget.entry.phone,
          level: widget.entry.roleLabel,
          code: _loading ? 'Yuklanmoqda...' : '',
          codeLocked: false,
          codeRetryAfterSec: _retryAfterSec,
        );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_changed);
      },
      child: AppShell(
        title: 'Worker',
        subtitle: '',
        nativeTopBar: true,
        nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
        contentPadding: EdgeInsets.zero,
        bottom: const AdminDock(activeTab: AdminDockTab.suppliers),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            _workerDetailPanelGap,
            _workerDetailPanelGap,
            _workerDetailPanelGap,
            116,
          ),
          children: [
            _WorkerDetailCard(
              detail: detail,
              statusLabel: _loading
                  ? 'Yuklanmoqda'
                  : _loadError != null
                      ? 'Xato'
                      : 'Tayyor',
              savingPhone: _savingPhone || _loading,
              regeneratingCode: _regeneratingCode,
              onAddPhone: _addPhone,
              onRegenerateCode: _regenerateCode,
              onCopyCode: _copyCode,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: appOutlinedActionButtonStyle(
                borderRadius: _workerDetailFieldRadius,
              ),
              onPressed: () => Navigator.of(context).pushNamed(
                AppRoutes.adminWorkerProfileDetail,
                arguments: widget.entry,
              ),
              child: const Text('Worker detail'),
            ),
            if (_loadError != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                style: appOutlinedActionButtonStyle(
                  borderRadius: _workerDetailFieldRadius,
                ),
                onPressed: _reload,
                child: const Text('Qayta yuklash'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkerDetailCard extends StatelessWidget {
  const _WorkerDetailCard({
    required this.detail,
    required this.statusLabel,
    required this.savingPhone,
    required this.regeneratingCode,
    required this.onAddPhone,
    required this.onRegenerateCode,
    required this.onCopyCode,
  });

  final AdminWorkerDetail detail;
  final String statusLabel;
  final bool savingPhone;
  final bool regeneratingCode;
  final Future<void> Function(AdminWorkerDetail detail) onAddPhone;
  final Future<void> Function() onRegenerateCode;
  final Future<void> Function(String code) onCopyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_workerDetailCardRadius),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    detail.name,
                    style: theme.textTheme.headlineMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppStatusChip(label: statusLabel),
              ],
            ),
            const SizedBox(height: 18),
            const _WorkerDetailLabel('Ref'),
            const SizedBox(height: 6),
            AppDetailField(value: detail.id),
            const SizedBox(height: 14),
            const _WorkerDetailLabel('User ismi'),
            const SizedBox(height: 6),
            AppDetailField(value: detail.name),
            const SizedBox(height: 14),
            const _WorkerDetailLabel('Telefon'),
            const SizedBox(height: 6),
            AppDetailField(value: detail.phone),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                style: appFilledActionButtonStyle(
                  borderRadius: _workerDetailFieldRadius,
                ),
                onPressed: savingPhone ? null : () => onAddPhone(detail),
                child: Text(
                  savingPhone
                      ? 'Saqlanmoqda...'
                      : detail.phone.trim().isEmpty
                          ? 'Telefon raqami kiritish'
                          : 'Telefonni yangilash',
                ),
              ),
            ),
            const SizedBox(height: 14),
            const _WorkerDetailLabel('Code'),
            const SizedBox(height: 6),
            AppDetailField(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      detail.code.trim().isEmpty
                          ? 'Hali generatsiya qilinmagan'
                          : detail.code,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (detail.code.trim().isNotEmpty)
                    IconButton(
                      onPressed: () => onCopyCode(detail.code),
                      icon: const Icon(Icons.content_copy_outlined),
                    ),
                  IconButton(
                    onPressed: regeneratingCode || detail.codeLocked
                        ? null
                        : onRegenerateCode,
                    icon: regeneratingCode
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            if (detail.codeRetryAfterSec > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Keyingi code uchun ${detail.codeRetryAfterSec} soniya kuting.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            const _WorkerDetailLabel('Daraja'),
            const SizedBox(height: 6),
            AppDetailField(value: detail.level),
          ],
        ),
      ),
    );
  }
}

class _WorkerDetailLabel extends StatelessWidget {
  const _WorkerDetailLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.bodySmall);
  }
}
