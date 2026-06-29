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
import '../../../core/widgets/feedback/app_text_input_dialog.dart';
import '../../../core/widgets/lists/app_segment_surface_card.dart';
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
    final phone = await showAppTextInputDialog(
      context: context,
      title: 'Telefon raqam qo‘shish',
      initialText: detail.phone,
      hintText: '+998901234567',
      keyboardType: TextInputType.phone,
      cardRadius: _workerDetailCardRadius,
      fieldRadius: _workerDetailFieldRadius,
      buttonRadius: _workerDetailFieldRadius,
    );
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
        title: 'Profil',
        subtitle: '',
        nativeTopBar: true,
        nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
        contentPadding: EdgeInsets.zero,
        bottom: const AdminDock(activeTab: AdminDockTab.suppliers),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              _workerDetailPanelGap,
              _workerDetailPanelGap,
              _workerDetailPanelGap,
              116,
            ),
            children: [
              AppSegmentSurfaceCard(
                padding: EdgeInsets.zero,
                child: _WorkerProfileHeroCard(
                  detail: detail,
                  statusLabel: _loading
                      ? 'Yuklanmoqda'
                      : _loadError != null
                          ? 'Xato'
                          : 'Tayyor',
                ),
              ),
              const SizedBox(height: 10),
              _WorkerAdminPanel(
                detail: detail,
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
                child: const Text('Ish faoliyati tafsilotlari'),
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
      ),
    );
  }
}

class _WorkerProfileHeroCard extends StatelessWidget {
  const _WorkerProfileHeroCard({
    required this.detail,
    required this.statusLabel,
  });

  final AdminWorkerDetail detail;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final phone = detail.phone.trim();
    final level = detail.level.trim();
    final initials = _workerInitials(detail.name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 204,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                  top: 112, child: ColoredBox(color: scheme.surface)),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 112,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        scheme.surfaceContainerHighest,
                        scheme.surfaceContainerLow,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 14,
                top: 14,
                child: AppStatusChip(label: statusLabel),
              ),
              Positioned(
                left: 16,
                top: 74,
                child: Container(
                  height: 92,
                  width: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primaryContainer,
                    border: Border.all(color: scheme.surface, width: 5),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.16),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 124,
                right: 16,
                top: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.name.trim().isEmpty
                          ? 'Nomsiz ishchi'
                          : detail.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      level.isEmpty ? 'Ishchi profili' : '$level profili',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _WorkerProfileChip(
                icon: Icons.phone_rounded,
                label: phone.isEmpty ? 'Telefon kiritilmagan' : phone,
              ),
              _WorkerProfileChip(
                icon: Icons.badge_rounded,
                label: level.isEmpty ? 'Daraja belgilanmagan' : level,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkerProfileChip extends StatelessWidget {
  const _WorkerProfileChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerAdminPanel extends StatelessWidget {
  const _WorkerAdminPanel({
    required this.detail,
    required this.savingPhone,
    required this.regeneratingCode,
    required this.onAddPhone,
    required this.onRegenerateCode,
    required this.onCopyCode,
  });

  final AdminWorkerDetail detail;
  final bool savingPhone;
  final bool regeneratingCode;
  final Future<void> Function(AdminWorkerDetail detail) onAddPhone;
  final Future<void> Function() onRegenerateCode;
  final Future<void> Function(String code) onCopyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppSegmentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Admin boshqaruv',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          const _WorkerDetailLabel('Worker ref'),
          const SizedBox(height: 6),
          AppDetailField(value: detail.id),
          const SizedBox(height: 14),
          const _WorkerDetailLabel('Telefon'),
          const SizedBox(height: 6),
          AppDetailField(
            value: detail.phone.trim().isEmpty
                ? 'Kiritilmagan'
                : detail.phone.trim(),
          ),
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
          const _WorkerDetailLabel('Kirish kodi'),
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
        ],
      ),
    );
  }
}

String _workerInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'I';
  }
  final first = parts.first.characters.first.toUpperCase();
  if (parts.length == 1) {
    return first;
  }
  return '$first${parts.last.characters.first.toUpperCase()}';
}

class _WorkerDetailLabel extends StatelessWidget {
  const _WorkerDetailLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.bodySmall);
  }
}
