import '../../../core/api/mobile_api.dart';
import '../../../core/timers/retry_after_countdown.dart';
import '../../../core/widgets/buttons/app_action_button_styles.dart';
import '../../../core/widgets/display/app_detail_field.dart';
import '../../../core/widgets/display/app_status_chip.dart';
import '../../../core/widgets/lists/app_segment_surface_card.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/models/app_models.dart';
import '../../shared/presentation/widgets/profile_info_chip.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_profile_avatar.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double _werkaDetailPanelGap = 4;
const double _werkaDetailFieldRadius = 14;

class AdminWerkaScreen extends StatefulWidget {
  const AdminWerkaScreen({super.key});

  @override
  State<AdminWerkaScreen> createState() => _AdminWerkaScreenState();
}

class _AdminWerkaScreenState extends State<AdminWerkaScreen> {
  late Future<AdminSettings> _future;
  final phone = TextEditingController();
  final name = TextEditingController();
  String werkaCode = '';
  late final RetryAfterCountdown _retryAfter;
  int get _retryAfterSec => _retryAfter.seconds;
  bool saving = false;
  bool regenerating = false;
  bool hydrated = false;
  bool changed = false;
  bool adminPanelExpanded = false;

  @override
  void initState() {
    super.initState();
    _retryAfter = RetryAfterCountdown(onChanged: _refreshRetryAfter);
    _future = MobileApi.instance.adminSettings();
  }

  @override
  void dispose() {
    _retryAfter.dispose();
    phone.dispose();
    name.dispose();
    super.dispose();
  }

  void _fill(AdminSettings settings) {
    if (hydrated) {
      return;
    }
    phone.text = settings.werkaPhone;
    name.text = settings.werkaName;
    werkaCode = settings.werkaCode;
    _setRetryAfter(settings.werkaCodeRetryAfterSec);
    hydrated = true;
  }

  void _refreshRetryAfter() {
    if (mounted) {
      setState(() {});
    }
  }

  void _setRetryAfter(int seconds) => _retryAfter.set(seconds);

  Future<void> _reload() async {
    final future = MobileApi.instance.adminSettings();
    setState(() {
      hydrated = false;
      _future = future;
    });
    final updated = await future;
    if (!mounted) {
      return;
    }
    setState(() {
      werkaCode = updated.werkaCode;
    });
  }

  Future<void> _save(AdminSettings current) async {
    setState(() => saving = true);
    try {
      final updated = await MobileApi.instance.updateAdminSettings(
        AdminSettings(
          erpUrl: current.erpUrl,
          erpApiKey: current.erpApiKey,
          erpApiSecret: current.erpApiSecret,
          defaultTargetWarehouse: current.defaultTargetWarehouse,
          defaultUom: current.defaultUom,
          werkaPhone: phone.text.trim(),
          werkaName: name.text.trim(),
          werkaAvatarUrl: current.werkaAvatarUrl,
          werkaCode: werkaCode,
          werkaCodeLocked: current.werkaCodeLocked,
          werkaCodeRetryAfterSec: _retryAfterSec,
          adminPhone: current.adminPhone,
          adminName: current.adminName,
        ),
      );
      setState(() {
        werkaCode = updated.werkaCode;
      });
      changed = true;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _regenerate() async {
    setState(() => regenerating = true);
    try {
      final updated = await MobileApi.instance.adminRegenerateWerkaCode();
      setState(() {
        werkaCode = updated.werkaCode;
      });
      changed = true;
      _setRetryAfter(updated.werkaCodeRetryAfterSec);
    } finally {
      if (mounted) {
        setState(() => regenerating = false);
      }
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: werkaCode));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Code nusxalandi')));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(changed);
      },
      child: AppShell(
        title: 'Profil',
        subtitle: '',
        nativeTopBar: true,
        nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
        bottom: const AdminDock(activeTab: AdminDockTab.settings),
        contentPadding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
          child: FutureBuilder<AdminSettings>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: AppLoadingIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    AppRetryState(onRetry: _reload, padding: EdgeInsets.zero),
                  ],
                );
              }
              final current = snapshot.data!;
              _fill(current);
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  _werkaDetailPanelGap,
                  _werkaDetailPanelGap,
                  _werkaDetailPanelGap,
                  116,
                ),
                children: [
                  AppSegmentSurfaceCard(
                    padding: EdgeInsets.zero,
                    child: _AdminWerkaDetailCard(
                      name: name,
                      phone: phone,
                      avatarUrl: snapshot.data?.werkaAvatarUrl ?? '',
                      code: werkaCode,
                      retryAfterSec: _retryAfterSec,
                      expanded: adminPanelExpanded,
                      saving: saving,
                      regenerating: regenerating,
                      onExpandedChanged: (expanded) {
                        setState(() => adminPanelExpanded = expanded);
                      },
                      onSave: () => _save(current),
                      onCopyCode: _copyCode,
                      onRegenerateCode: _regenerate,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AdminWerkaDetailCard extends StatelessWidget {
  const _AdminWerkaDetailCard({
    required this.name,
    required this.phone,
    required this.avatarUrl,
    required this.code,
    required this.retryAfterSec,
    required this.expanded,
    required this.saving,
    required this.regenerating,
    required this.onExpandedChanged,
    required this.onSave,
    required this.onCopyCode,
    required this.onRegenerateCode,
  });

  final TextEditingController name;
  final TextEditingController phone;
  final String avatarUrl;
  final String code;
  final int retryAfterSec;
  final bool expanded;
  final bool saving;
  final bool regenerating;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback onSave;
  final Future<void> Function() onCopyCode;
  final Future<void> Function() onRegenerateCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayName =
        name.text.trim().isEmpty ? 'Omborchi' : name.text.trim();
    final phoneText = phone.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 204,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                top: 112,
                child: ColoredBox(color: scheme.surface),
              ),
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
              const Positioned(
                right: 14,
                top: 14,
                child: AppStatusChip(label: 'Tayyor'),
              ),
              Positioned(
                left: 16,
                top: 74,
                child: AdminProfileAvatar(
                  avatarUrl: avatarUrl,
                  fallbackText: _werkaInitials(displayName),
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
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Omborchi profili',
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
                      label: phoneText.isEmpty
                          ? 'Telefon kiritilmagan'
                          : phoneText,
                    ),
                    const ProfileInfoChip(
                      icon: Icons.warehouse_rounded,
                      label: 'Omborchi',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey('admin-werka-detail-admin-toggle'),
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
                  child: _WerkaAdminPanel(
                    name: name,
                    phone: phone,
                    code: code,
                    retryAfterSec: retryAfterSec,
                    saving: saving,
                    regenerating: regenerating,
                    onSave: onSave,
                    onCopyCode: onCopyCode,
                    onRegenerateCode: onRegenerateCode,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _WerkaAdminPanel extends StatelessWidget {
  const _WerkaAdminPanel({
    required this.name,
    required this.phone,
    required this.code,
    required this.retryAfterSec,
    required this.saving,
    required this.regenerating,
    required this.onSave,
    required this.onCopyCode,
    required this.onRegenerateCode,
  });

  final TextEditingController name;
  final TextEditingController phone;
  final String code;
  final int retryAfterSec;
  final bool saving;
  final bool regenerating;
  final VoidCallback onSave;
  final Future<void> Function() onCopyCode;
  final Future<void> Function() onRegenerateCode;

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
        Text('Nomi', style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        _WerkaTextField(
          controller: name,
          hintText: 'Omborchi',
        ),
        const SizedBox(height: 14),
        Text('Telefon', style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        _WerkaTextField(
          controller: phone,
          hintText: '+998901234567',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),
        Text('Kirish kodi', style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        AppDetailField(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  code.trim().isEmpty ? 'Hali generatsiya qilinmagan' : code,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (code.trim().isNotEmpty)
                IconButton(
                  onPressed: onCopyCode,
                  icon: const Icon(Icons.content_copy_outlined),
                ),
              IconButton(
                onPressed:
                    regenerating || retryAfterSec > 0 ? null : onRegenerateCode,
                icon: regenerating
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
        if (retryAfterSec > 0) ...[
          const SizedBox(height: 12),
          Text(
            'Keyingi code uchun $retryAfterSec soniya kuting.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            style: appFilledActionButtonStyle(),
            onPressed: saving ? null : onSave,
            child: Text(saving ? 'Saqlanmoqda...' : 'Saqlash'),
          ),
        ),
      ],
    );
  }
}

String _werkaInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'O';
  }
  final first = parts.first.characters.first.toUpperCase();
  if (parts.length == 1) {
    return first;
  }
  return '$first${parts.last.characters.first.toUpperCase()}';
}

class _WerkaTextField extends StatelessWidget {
  const _WerkaTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_werkaDetailFieldRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_werkaDetailFieldRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_werkaDetailFieldRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}
