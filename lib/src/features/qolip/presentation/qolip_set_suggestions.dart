import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../qolip_set_search.dart';
import '../qolip_search_engine.dart';

String qolipSetSubtitle(QolipManagedSet entry, AppLocalizations l10n) => [
      if (entry.name.isNotEmpty) entry.set.id,
      l10n.qolipText('products.mold_count',
          values: {'count': entry.set.members.length}),
    ].join(' · ');

Future<QolipManagedSet?> showQolipSetMatches(
    BuildContext context, List<QolipManagedSet> matches) {
  final l10n = context.l10n;
  return showModalBottomSheet<QolipManagedSet>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => M3PickerSheet<QolipManagedSet>(
      title: l10n
          .qolipManagementText('matches', values: {'count': matches.length}),
      hintText: l10n.qolipManagementText('search'),
      items: matches,
      itemTitle: (entry) => entry.displayName,
      itemSubtitle: (entry) => qolipSetSubtitle(entry, l10n),
      matchesQuery: (entry, query) => QolipSearchQuery(query).matches(
          QolipSearchDocument([
        entry.name,
        entry.set.id,
        ...entry.set.members.map((mold) => mold.qolipCode)
      ])),
      onSelected: (entry) => Navigator.of(sheetContext).pop(entry),
    ),
  );
}

class QolipSetSuggestions extends StatefulWidget {
  const QolipSetSuggestions(
      {super.key,
      required this.controller,
      required this.lookup,
      required this.onSelected,
      this.enabled = true,
      this.includeMoldCodes = true,
      this.onMatchesChanged});

  final TextEditingController controller;
  final QolipSetLookup lookup;
  final ValueChanged<QolipManagedSet> onSelected;
  final bool enabled;
  final bool includeMoldCodes;
  final ValueChanged<bool>? onMatchesChanged;

  @override
  State<QolipSetSuggestions> createState() => _QolipSetSuggestionsState();
}

class _QolipSetSuggestionsState extends State<QolipSetSuggestions> {
  Timer? _timer;
  int _generation = 0;
  List<QolipManagedSet> _matches = const [];
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _changed();
  }

  @override
  void didUpdateWidget(QolipSetSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.controller != widget.controller) {
      _changed();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    _timer?.cancel();
    final generation = ++_generation;
    final query = widget.controller.text.trim();
    _error = null;
    _loading = widget.enabled && query.isNotEmpty;
    if (!_loading) _matches = const [];
    setState(() {});
    if (_loading) {
      _timer = Timer(
          const Duration(milliseconds: 200), () => _search(query, generation));
    }
  }

  Future<void> _search(String query, int generation) async {
    bool current() =>
        mounted &&
        widget.enabled &&
        generation == _generation &&
        widget.lookup.isCurrent;
    try {
      final sets = await widget.lookup.load();
      if (!current()) return;
      final matches = await searchQolipSets(sets, query,
          includeMoldCodes: widget.includeMoldCodes, isCurrent: current);
      if (!current()) return;
      setState(() {
        _matches = matches;
        _loading = false;
      });
      widget.onMatchesChanged?.call(matches.isNotEmpty);
    } catch (error) {
      if (!current()) return;
      setState(() {
        _error = error;
        _matches = const [];
        _loading = false;
      });
      widget.onMatchesChanged?.call(false);
    }
  }

  Future<void> _showAll() async {
    final selected = await showQolipSetMatches(context, _matches);
    if (mounted &&
        widget.enabled &&
        selected != null &&
        widget.lookup.isCurrent) {
      widget.onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.controller.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    if (_loading) {
      return const Padding(
          padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator());
    }
    if (_error != null) {
      return TextButton.icon(
        onPressed: _changed,
        icon: const Icon(Icons.refresh),
        label: Text(l10n.qolipManagementText('lookup_retry')),
      );
    }
    if (_matches.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final entry in _matches.take(3))
            ListTile(
              key: ValueKey('qolip-set-suggestion-${entry.set.id}'),
              leading: const Icon(Icons.layers_outlined),
              title: Text(entry.displayName,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(qolipSetSubtitle(entry, l10n)),
              onTap: () {
                FocusScope.of(context).unfocus();
                widget.onSelected(entry);
              },
            ),
          if (_matches.length > 3)
            TextButton(
                onPressed: _showAll,
                child: Text(l10n.qolipManagementText('all_matches',
                    values: {'count': _matches.length}))),
        ]),
      ),
    );
  }
}
