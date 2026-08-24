import '../../../core/localization/app_localizations.dart';
import '../../../core/session/accounts/saved_account_store.dart';
import '../../../core/widgets/forms/pin_pad.dart';
import '../../shared/models/app_models.dart';
import 'package:flutter/material.dart';

typedef ProfilePinPresence = bool Function(SessionProfile profile);
typedef ProfilePinVerifier = Future<bool> Function(
  SessionProfile profile,
  String pin,
);
typedef SavedAccountSelection = Future<void> Function(SavedAccount account);

class AccountSwitcherSheet extends StatefulWidget {
  const AccountSwitcherSheet({
    super.key,
    required this.accounts,
    required this.activeAccountId,
    required this.hasPinForProfile,
    required this.verifyPinForProfile,
    required this.onSwitch,
    required this.onAddAccount,
  });

  final List<SavedAccount> accounts;
  final String? activeAccountId;
  final ProfilePinPresence hasPinForProfile;
  final ProfilePinVerifier verifyPinForProfile;
  final SavedAccountSelection onSwitch;
  final VoidCallback onAddAccount;

  @override
  State<AccountSwitcherSheet> createState() => _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends State<AccountSwitcherSheet> {
  final TextEditingController _pinController = TextEditingController();
  SavedAccount? _pinTarget;
  bool _busy = false;
  String? _errorText;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _select(SavedAccount account) async {
    if (_busy || account.id == widget.activeAccountId) {
      return;
    }
    if (widget.hasPinForProfile(account.profile)) {
      setState(() {
        _pinTarget = account;
        _pinController.clear();
        _errorText = null;
      });
      return;
    }
    await _switch(account);
  }

  Future<void> _verifyAndSwitch() async {
    final target = _pinTarget;
    if (_busy || target == null) {
      return;
    }
    setState(() {
      _busy = true;
      _errorText = null;
    });
    final verified = await widget.verifyPinForProfile(
      target.profile,
      _pinController.text,
    );
    if (!mounted) {
      return;
    }
    if (!verified) {
      setState(() {
        _busy = false;
        _pinController.clear();
        _errorText = AppLocalizations.of(context).pinWrong;
      });
      return;
    }
    setState(() => _busy = false);
    await _switch(target);
  }

  Future<void> _switch(SavedAccount account) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      await widget.onSwitch(account);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _errorText = AppLocalizations.of(context).accountSwitchFailed;
      });
    }
  }

  void _closePin() {
    if (_busy) {
      return;
    }
    setState(() {
      _pinTarget = null;
      _pinController.clear();
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = _pinTarget;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: target == null
              ? _buildAccountList(context, l10n, theme)
              : _buildPinEntry(context, l10n, theme, target),
        ),
      ),
    );
  }

  Widget _buildAccountList(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Column(
      key: const ValueKey<String>('account-list'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        const SizedBox(height: 12),
        Text(l10n.accountSwitchTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 14),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: widget.accounts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final account = widget.accounts[index];
              final isActive = account.id == widget.activeAccountId;
              final hasPin = widget.hasPinForProfile(account.profile);
              return _SavedAccountTile(
                key: ValueKey<String>('saved-account-${account.id}'),
                account: account,
                isActive: isActive,
                hasPin: hasPin,
                currentLabel: l10n.accountCurrent,
                enabled: !_busy,
                onTap: () => _select(account),
              );
            },
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorText!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey<String>('add-saved-account'),
          onPressed: _busy ? null : widget.onAddAccount,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: Text(l10n.accountAdd),
        ),
      ],
    );
  }

  Widget _buildPinEntry(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    SavedAccount target,
  ) {
    final name = _displayName(target.profile);
    return Column(
      key: ValueKey<String>('account-pin-${target.id}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: _busy ? null : _closePin,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        Text(
          l10n.accountPinPrompt(name),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 22),
        PinCodeEditor(
          controller: _pinController,
          onAction: _verifyAndSwitch,
          actionLabel: _busy ? l10n.checking : l10n.unlock,
          actionIcon: Icons.lock_open_rounded,
          errorText: _errorText,
          busy: _busy,
        ),
      ],
    );
  }
}

class _SavedAccountTile extends StatelessWidget {
  const _SavedAccountTile({
    super.key,
    required this.account,
    required this.isActive,
    required this.hasPin,
    required this.currentLabel,
    required this.enabled,
    required this.onTap,
  });

  final SavedAccount account;
  final bool isActive;
  final bool hasPin;
  final String currentLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = _displayName(account.profile);
    final initial = name.characters.first.toUpperCase();
    return Material(
      color: isActive
          ? scheme.primaryContainer.withValues(alpha: 0.58)
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
                child: Text(initial),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      userRoleLabel(account.profile.role),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (hasPin)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 19,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              if (isActive)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(currentLabel),
                )
              else
                Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

String _displayName(SessionProfile profile) {
  final displayName = profile.displayName.trim();
  if (displayName.isNotEmpty) {
    return displayName;
  }
  final legalName = profile.legalName.trim();
  return legalName.isNotEmpty ? legalName : profile.ref;
}
