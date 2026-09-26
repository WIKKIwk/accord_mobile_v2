import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../shared/models/app_models.dart';
import '../../logic/factory_map_bindings.dart';
import '../../logic/factory_map_live.dart';
import '../../logic/factory_map_status.dart';

enum _MachineFilter { all, working, queued, paused }

/// Uses the map's existing snapshots; opening/searching adds no API requests.
class FactoryMapDirectory extends StatefulWidget {
  const FactoryMapDirectory(
      {super.key, required this.bindings, required this.live});

  final FactoryMapBindings bindings;
  final FactoryMapLive live;

  @override
  State<FactoryMapDirectory> createState() => _FactoryMapDirectoryState();
}

class _FactoryMapDirectoryState extends State<FactoryMapDirectory> {
  final _search = TextEditingController();
  _MachineFilter _filter = _MachineFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  FactoryMapStatus _status(AdminApparatus machine) => widget.live.fresh
      ? factoryMapMachineStatus(
              snapshot: widget.live.snapshot, apparatusId: machine.id)
          .status
      : FactoryMapStatus.unknown;

  bool _matches(FactoryMapStatus status) => switch (_filter) {
        _MachineFilter.all => true,
        _MachineFilter.working =>
          status.isCurrentWork && status != FactoryMapStatus.paused,
        _MachineFilter.queued => status == FactoryMapStatus.pending,
        _MachineFilter.paused => status == FactoryMapStatus.paused,
      };

  int _priority(FactoryMapStatus status) => switch (status) {
        FactoryMapStatus.inProgress => 0,
        FactoryMapStatus.paused => 1,
        FactoryMapStatus.printPreflight ||
        FactoryMapStatus.printPreflightPassed =>
          2,
        FactoryMapStatus.pending => 3,
        FactoryMapStatus.unknown => 4,
        _ => 5,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge([widget.bindings, widget.live]),
      builder: (context, _) {
        final query = _search.text.trim().toLowerCase();
        final orders = {
          for (final item in widget.live.maps) item.map.id: item.map
        };
        final machines = widget.bindings.apparatus.where((machine) {
          if (!machine.isActive || !_matches(_status(machine))) return false;
          final work = factoryMapMachineStatus(
              snapshot: widget.live.snapshot, apparatusId: machine.id);
          final order = orders[work.orderId];
          return query.isEmpty ||
              [machine.name, order?.orderNumber ?? '', order?.title ?? '']
                  .any((value) => value.toLowerCase().contains(query));
        }).toList()
          ..sort((a, b) {
            final priority =
                _priority(_status(a)).compareTo(_priority(_status(b)));
            return priority == 0 ? a.name.compareTo(b.name) : priority;
          });
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                child: Row(children: [
                  Expanded(
                      child: Text(l10n.adminText('factory_map.directory.title'),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700))),
                  IconButton(
                      tooltip: l10n.adminText('factory_map.close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  key: const ValueKey('factory-map-search'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: l10n.adminText('factory_map.directory.search'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip:
                                l10n.adminText('factory_map.directory.clear'),
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(_search.clear)),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(children: [
                  for (final filter in _MachineFilter.values)
                    Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: ValueKey(
                              'factory-map-machine-filter-${filter.name}'),
                          label: Text(l10n.adminText(
                              'factory_map.directory.${filter.name}')),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        )),
                ]),
              ),
              if (!widget.live.fresh)
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(l10n.adminText('factory_map.live.unknown'),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant))),
              Expanded(
                  child: machines.isEmpty
                      ? Center(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                  l10n.adminText('factory_map.directory.empty'),
                                  textAlign: TextAlign.center)))
                      : ListView.separated(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: machines.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final machine = machines[index];
                            final status = _status(machine);
                            final work = factoryMapMachineStatus(
                                snapshot: widget.live.snapshot,
                                apparatusId: machine.id);
                            final order = orders[work.orderId];
                            final color = Color(status.colorValue);
                            return Material(
                              color: scheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(18),
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                key: ValueKey(
                                    'factory-map-machine-${machine.id}'),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                leading: CircleAvatar(
                                    backgroundColor:
                                        color.withValues(alpha: .12),
                                    child: Icon(
                                        status == FactoryMapStatus.inProgress
                                            ? Icons.play_arrow_rounded
                                            : status == FactoryMapStatus.paused
                                                ? Icons.pause_rounded
                                                : Icons
                                                    .precision_manufacturing_outlined,
                                        color: color)),
                                title: Text(machine.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                    [
                                      l10n.adminText(status.labelKey),
                                      if (order != null)
                                        '${order.orderNumber.isEmpty ? '' : '№ ${order.orderNumber} · '}${order.title}',
                                      if (machine.factoryMapObjectId.isEmpty)
                                        l10n.adminText(
                                            'factory_map.directory.unmapped'),
                                    ].join('\n'),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis),
                                trailing:
                                    const Icon(Icons.chevron_right_rounded),
                                onTap: () => Navigator.of(context).pop(machine),
                              ),
                            );
                          },
                        )),
            ],
          ),
        );
      },
    );
  }
}
