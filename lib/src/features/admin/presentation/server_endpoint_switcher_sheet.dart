import '../../../core/localization/app_localizations.dart';
import '../../../core/network/server_endpoint_store.dart';
import '../../../core/widgets/feedback/spring_pressable.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import 'package:flutter/material.dart';

typedef ServerEndpointSelection = Future<bool> Function(
  SavedServerEndpoint endpoint,
);
typedef ServerEndpointSave = Future<SavedServerEndpoint> Function(String raw);

class ServerEndpointSwitcherSheet extends StatefulWidget {
  const ServerEndpointSwitcherSheet({
    super.key,
    required this.endpoints,
    required this.activeBaseUrl,
    required this.onSwitch,
    required this.onSave,
  });

  final List<SavedServerEndpoint> endpoints;
  final String activeBaseUrl;
  final ServerEndpointSelection onSwitch;
  final ServerEndpointSave onSave;

  @override
  State<ServerEndpointSwitcherSheet> createState() =>
      _ServerEndpointSwitcherSheetState();
}

class _ServerEndpointSwitcherSheetState
    extends State<ServerEndpointSwitcherSheet> {
  final TextEditingController _endpointController = TextEditingController();
  late List<SavedServerEndpoint> _endpoints;
  bool _adding = false;
  bool _busy = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _endpoints = List<SavedServerEndpoint>.of(widget.endpoints);
  }

  @override
  void dispose() {
    _endpointController.dispose();
    super.dispose();
  }

  Future<void> _select(SavedServerEndpoint endpoint) async {
    if (_busy || endpoint.baseUrl == widget.activeBaseUrl) {
      return;
    }
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      final switched = await widget.onSwitch(endpoint);
      if (!mounted) {
        return;
      }
      if (switched) {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _busy = false);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _errorText = error.toString();
      });
    }
  }

  Future<void> _save() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      final endpoint = await widget.onSave(_endpointController.text);
      if (!mounted) {
        return;
      }
      final next = <SavedServerEndpoint>[
        endpoint,
        for (final item in _endpoints)
          if (item.baseUrl != endpoint.baseUrl) item,
      ];
      setState(() {
        _endpoints = next;
        _endpointController.clear();
        _adding = false;
        _busy = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() {
        _busy = false;
        _errorText = error is FormatException
            ? l10n.adminText('server.invalid_endpoint')
            : error.toString();
      });
    }
  }

  void _openAdd() {
    if (_busy) {
      return;
    }
    setState(() {
      _adding = true;
      _errorText = null;
    });
  }

  void _closeAdd() {
    if (_busy) {
      return;
    }
    setState(() {
      _adding = false;
      _endpointController.clear();
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 20),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _adding
              ? _buildAddForm(context, l10n, theme)
              : _buildEndpointList(context, l10n, theme),
        ),
      ),
    );
  }

  Widget _buildEndpointList(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Column(
      key: const ValueKey<String>('server-endpoint-list'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _ServerSheetHandle(),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            l10n.adminText('server.saved_title'),
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            l10n.adminText('server.saved_description'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: _endpoints.length,
            itemBuilder: (context, index) {
              final endpoint = _endpoints[index];
              final isActive = endpoint.baseUrl == widget.activeBaseUrl;
              return Padding(
                padding: EdgeInsets.only(
                  top: index == 0 ? 0 : M3SegmentedListGeometry.gap,
                ),
                child: _SavedServerEndpointTile(
                  key: ValueKey<String>('saved-server-${endpoint.baseUrl}'),
                  endpoint: endpoint,
                  isActive: isActive,
                  currentLabel: l10n.adminText('server.current_short'),
                  enabled: !_busy,
                  onTap: () => _select(endpoint),
                  slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                    index,
                    _endpoints.length,
                  ),
                ),
              );
            },
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _errorText!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SpringPressable(
            enabled: !_busy,
            child: FilledButton.icon(
              key: const ValueKey<String>('add-saved-server'),
              onPressed: _busy ? null : _openAdd,
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                minimumSize: const Size(double.infinity, 64),
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 24,
                ),
                textStyle: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                iconSize: 22,
              ),
              icon: const Icon(Icons.add_link_rounded),
              label: Text(l10n.adminText('server.add_endpoint')),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddForm(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        key: const ValueKey<String>('server-endpoint-add-form'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ServerSheetHandle(),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: _busy ? null : _closeAdd,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          Text(
            l10n.adminText('server.add_endpoint_title'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.adminText('server.add_endpoint_description'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            key: const ValueKey<String>('server-endpoint-add-input'),
            controller: _endpointController,
            enabled: !_busy,
            autofocus: true,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: l10n.adminText('server.endpoint_label'),
              hintText: 'https://erp.example.com',
              prefixIcon: const Icon(Icons.language_rounded),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _closeAdd,
                  child: Text(l10n.adminText('action.cancel')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey<String>('server-endpoint-save'),
                  onPressed: _busy ? null : _save,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(l10n.adminText('action.save')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SavedServerEndpointTile extends StatelessWidget {
  const _SavedServerEndpointTile({
    super.key,
    required this.endpoint,
    required this.isActive,
    required this.currentLabel,
    required this.enabled,
    required this.onTap,
    required this.slot,
  });

  final SavedServerEndpoint endpoint;
  final bool isActive;
  final String currentLabel;
  final bool enabled;
  final VoidCallback onTap;
  final M3SegmentVerticalSlot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );
    return Material(
      color: isActive
          ? scheme.primaryContainer.withValues(alpha: 0.55)
          : scheme.surfaceContainerLowest,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 30,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.dns_rounded,
                    size: 18,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      endpoint.baseUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(height: 2),
                      Text(
                        currentLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isActive)
                Icon(
                  Icons.check_circle_rounded,
                  color: scheme.primary,
                  size: 22,
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerSheetHandle extends StatelessWidget {
  const _ServerSheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
