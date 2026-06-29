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
import '../../../core/widgets/lists/app_segment_surface_card.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../../shared/presentation/widgets/profile_info_chip.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_profile_avatar.dart';

const double _workerDetailPanelGap = 4;
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
  bool _adminPanelExpanded = false;
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

  Future<void> _savePhone(AdminWorkerDetail detail, String phone) async {
    final trimmedPhone = phone.trim();
    if (trimmedPhone.isEmpty) {
      return;
    }

    setState(() => _savingPhone = true);
    try {
      final updated = await MobileApi.instance.adminUpdateWorkerPhone(
        id: detail.id,
        phone: trimmedPhone,
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
          avatarUrl: '',
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
                child: _WorkerProfileExpandableCard(
                  detail: detail,
                  statusLabel: _loading
                      ? 'Yuklanmoqda'
                      : _loadError != null
                          ? 'Xato'
                          : 'Tayyor',
                  expanded: _adminPanelExpanded,
                  savingPhone: _savingPhone,
                  regeneratingCode: _regeneratingCode,
                  onExpandedChanged: (expanded) {
                    setState(() => _adminPanelExpanded = expanded);
                  },
                  onSavePhone: _savePhone,
                  onRegenerateCode: _regenerateCode,
                  onCopyCode: _copyCode,
                ),
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

class _WorkerProfileExpandableCard extends StatelessWidget {
  const _WorkerProfileExpandableCard({
    required this.detail,
    required this.statusLabel,
    required this.expanded,
    required this.savingPhone,
    required this.regeneratingCode,
    required this.onExpandedChanged,
    required this.onSavePhone,
    required this.onRegenerateCode,
    required this.onCopyCode,
  });

  final AdminWorkerDetail detail;
  final String statusLabel;
  final bool expanded;
  final bool savingPhone;
  final bool regeneratingCode;
  final ValueChanged<bool> onExpandedChanged;
  final Future<void> Function(AdminWorkerDetail detail, String phone)
      onSavePhone;
  final Future<void> Function() onRegenerateCode;
  final Future<void> Function(String code) onCopyCode;

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
                child: AdminProfileAvatar(
                  avatarUrl: detail.avatarUrl,
                  fallbackText: initials,
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ProfileInfoChip(
                      icon: Icons.phone_rounded,
                      label: phone.isEmpty ? 'Telefon kiritilmagan' : phone,
                    ),
                    ProfileInfoChip(
                      icon: Icons.badge_rounded,
                      label: level.isEmpty ? 'Daraja belgilanmagan' : level,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey('admin-worker-detail-admin-toggle'),
                tooltip: expanded ? 'Boshqaruvni yopish' : 'Boshqaruvni ochish',
                onPressed: () => onExpandedChanged(!expanded),
                icon: AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _WorkerAdminPanel(
                    detail: detail,
                    savingPhone: savingPhone,
                    regeneratingCode: regeneratingCode,
                    onSavePhone: onSavePhone,
                    onRegenerateCode: onRegenerateCode,
                    onCopyCode: onCopyCode,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _WorkerAdminPanel extends StatelessWidget {
  const _WorkerAdminPanel({
    required this.detail,
    required this.savingPhone,
    required this.regeneratingCode,
    required this.onSavePhone,
    required this.onRegenerateCode,
    required this.onCopyCode,
  });

  final AdminWorkerDetail detail;
  final bool savingPhone;
  final bool regeneratingCode;
  final Future<void> Function(AdminWorkerDetail detail, String phone)
      onSavePhone;
  final Future<void> Function() onRegenerateCode;
  final Future<void> Function(String code) onCopyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(
          height: 1,
          color: scheme.outlineVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 14),
        Text(
          'Admin boshqaruv',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        const _WorkerDetailLabel('Telefon'),
        const SizedBox(height: 6),
        _WorkerPhoneInlineField(
          detail: detail,
          savingPhone: savingPhone,
          onSavePhone: onSavePhone,
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
    );
  }
}

class _WorkerPhoneInlineField extends StatefulWidget {
  const _WorkerPhoneInlineField({
    required this.detail,
    required this.savingPhone,
    required this.onSavePhone,
  });

  final AdminWorkerDetail detail;
  final bool savingPhone;
  final Future<void> Function(AdminWorkerDetail detail, String phone)
      onSavePhone;

  @override
  State<_WorkerPhoneInlineField> createState() =>
      _WorkerPhoneInlineFieldState();
}

class _WorkerPhoneInlineFieldState extends State<_WorkerPhoneInlineField> {
  late final TextEditingController _controller;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.detail.phone.trim());
  }

  @override
  void didUpdateWidget(covariant _WorkerPhoneInlineField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.detail.phone != widget.detail.phone) {
      _controller.text = widget.detail.phone.trim();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await widget.onSavePhone(widget.detail, _controller.text);
    if (mounted) {
      setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phone = widget.detail.phone.trim();
    return AppDetailField(
      child: Row(
        children: [
          Expanded(
            child: _editing
                ? TextField(
                    key: const ValueKey('admin-worker-detail-phone-input'),
                    controller: _controller,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: '+998901234567',
                    ),
                    style: theme.textTheme.titleMedium,
                    onSubmitted: (_) => _submit(),
                  )
                : Text(
                    phone.isEmpty ? 'Kiritilmagan' : phone,
                    style: theme.textTheme.titleMedium,
                  ),
          ),
          IconButton(
            key: const ValueKey('admin-worker-detail-phone-action'),
            tooltip: _editing
                ? 'Telefonni saqlash'
                : phone.isEmpty
                    ? 'Telefon raqami kiritish'
                    : 'Telefonni yangilash',
            onPressed: widget.savingPhone
                ? null
                : _editing
                    ? _submit
                    : () => setState(() => _editing = true),
            icon: widget.savingPhone
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_editing ? Icons.check_rounded : Icons.edit_rounded),
          ),
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
