import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/session/state/app_session.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_drawer_navigation.dart';
import '../../shared/models/app_models.dart';
import 'widgets/aparatchi_dock.dart';
import 'widgets/aparatchi_navigation_drawer.dart';
import 'package:flutter/material.dart';

class AparatchiWorkInstructionsScreen extends StatefulWidget {
  const AparatchiWorkInstructionsScreen({super.key});

  @override
  State<AparatchiWorkInstructionsScreen> createState() =>
      _AparatchiWorkInstructionsScreenState();
}

class _AparatchiWorkInstructionsScreenState
    extends State<AparatchiWorkInstructionsScreen> {
  late final Future<List<AdminApparatus>> _apparatusFuture;

  @override
  void initState() {
    super.initState();
    _apparatusFuture = MobileApi.instance.adminApparatus(limit: 300);
  }

  @override
  Widget build(BuildContext context) {
    final assignedIds = _assignedApparatus(
      AppSession.instance.profile?.assignedApparatus ?? const <String>[],
    );
    return AppShell(
      title: context.l10n.productionText('worker.instructions'),
      subtitle: context.l10n.productionText('worker.guide.subtitle'),
      nativeTopBar: true,
      drawer: AparatchiNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.apparatusWorkInstructions,
        onNavigate: (routeName) =>
            AdminDrawerNavigation.openRoute(context, routeName),
      ),
      bottom: const AparatchiDock(activeTab: null),
      contentPadding: EdgeInsets.zero,
      child: ColoredBox(
        color: AppTheme.shellStart(context),
        child: FutureBuilder<List<AdminApparatus>>(
          future: _apparatusFuture,
          builder: (context, snapshot) {
            final assigned = snapshot.data
                    ?.where(
                      (apparatus) => assignedIds.contains(apparatus.id.trim()),
                    )
                    .toList(growable: false) ??
                const <AdminApparatus>[];
            if (snapshot.connectionState != ConnectionState.done &&
                assigned.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (assigned.isEmpty) return const _NoAssignedApparatus();
            return ListView(
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                MediaQuery.viewPaddingOf(context).bottom + 120,
              ),
              children: [
                const _GuideIntro(),
                const SizedBox(height: 12),
                _GuideSectionCard(
                  title: context.l10n.productionText(
                    'worker.guide.open_order',
                  ),
                  items: [
                    for (var index = 1; index <= 5; index++)
                      context.l10n.productionText(
                        'worker.guide.open_order.$index',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _GuideSectionCard(
                  title: context.l10n.productionText(
                    'worker.guide.states_actions',
                  ),
                  items: [
                    for (var index = 1; index <= 4; index++)
                      context.l10n.productionText(
                        'worker.guide.states_actions.$index',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final item in assigned) ...[
                  _ApparatusGuideCard(
                    guide: _ApparatusGuide.forApparatus(item, context.l10n),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

List<String> _assignedApparatus(Iterable<String> values) {
  final seen = <String>{};
  return values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .where((value) => seen.add(value.toLowerCase()))
      .toList(growable: false);
}

List<String> _guideItems(
  AppLocalizations l10n,
  String prefix,
  int count,
) {
  return [
    for (var index = 1; index <= count; index++)
      l10n.productionText('$prefix.$index'),
  ];
}

class _GuideIntro extends StatelessWidget {
  const _GuideIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.l10n.productionText('worker.guide.intro'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onPrimaryContainer,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _NoAssignedApparatus extends StatelessWidget {
  const _NoAssignedApparatus();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.productionText('worker.guide.no_machine.title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.productionText('worker.guide.no_machine.body'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ApparatusGuideCard extends StatelessWidget {
  const _ApparatusGuideCard({required this.guide});

  final _ApparatusGuide guide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              guide.apparatus,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              guide.kindLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            _GuideSection(
              title: context.l10n.productionText('worker.guide.before_start'),
              items: guide.startChecks,
            ),
            const SizedBox(height: 16),
            _GuideSection(
              title: context.l10n.productionText('worker.guide.pause'),
              items: guide.pauseSteps,
            ),
            const SizedBox(height: 16),
            _GuideSection(
              title: context.l10n.productionText('worker.guide.complete'),
              items: guide.completionFields,
            ),
            const SizedBox(height: 16),
            _GuideSection(
              title: context.l10n.productionText('worker.guide.partial'),
              items: [
                for (var index = 1; index <= 3; index++)
                  context.l10n.productionText('worker.guide.partial.$index'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideSectionCard extends StatelessWidget {
  const _GuideSectionCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _GuideSection(title: title, items: items),
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < items.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${index + 1}. ${items[index]}',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.32),
            ),
          ),
      ],
    );
  }
}

class _ApparatusGuide {
  const _ApparatusGuide({
    required this.apparatus,
    required this.kindLabel,
    required this.startChecks,
    required this.pauseSteps,
    required this.completionFields,
  });

  final String apparatus;
  final String kindLabel;
  final List<String> startChecks;
  final List<String> pauseSteps;
  final List<String> completionFields;

  factory _ApparatusGuide.forApparatus(
    AdminApparatus apparatus,
    AppLocalizations l10n,
  ) {
    final operation = apparatus.operation.trim().toLowerCase();
    final colorCount = apparatus.colorStations;
    if (operation == 'print') {
      return _ApparatusGuide(
        apparatus: apparatus.name,
        kindLabel: apparatus.technology.trim().toLowerCase() == 'flexographic'
            ? l10n.productionText('worker.guide.kind.print.flexo')
            : colorCount == null
                ? l10n.productionText('worker.guide.kind.machine')
                : l10n.productionText(
                    'worker.guide.kind.print.color',
                    values: {'count': colorCount},
                  ),
        startChecks: _guideItems(l10n, 'worker.guide.print.start', 4),
        pauseSteps: _guideItems(l10n, 'worker.guide.print.pause', 3),
        completionFields: _guideItems(l10n, 'worker.guide.print.complete', 3),
      );
    }
    if (operation == 'laminate') {
      return _ApparatusGuide(
        apparatus: apparatus.name,
        kindLabel: l10n.productionText('worker.guide.kind.lamination'),
        startChecks: _guideItems(l10n, 'worker.guide.lamination.start', 3),
        pauseSteps: _guideItems(l10n, 'worker.guide.lamination.pause', 3),
        completionFields: _guideItems(
          l10n,
          'worker.guide.lamination.complete',
          3,
        ),
      );
    }
    if (operation == 'cut') {
      return _ApparatusGuide(
        apparatus: apparatus.name,
        kindLabel: l10n.productionText('worker.guide.kind.cutting'),
        startChecks: _guideItems(l10n, 'worker.guide.cutting.start', 3),
        pauseSteps: _guideItems(l10n, 'worker.guide.cutting.pause', 3),
        completionFields: _guideItems(l10n, 'worker.guide.cutting.complete', 3),
      );
    }
    return _ApparatusGuide(
      apparatus: apparatus.name,
      kindLabel: l10n.productionText('worker.guide.kind.machine'),
      startChecks: _guideItems(l10n, 'worker.guide.machine.start', 3),
      pauseSteps: _guideItems(l10n, 'worker.guide.machine.pause', 2),
      completionFields: _guideItems(l10n, 'worker.guide.machine.complete', 3),
    );
  }
}
