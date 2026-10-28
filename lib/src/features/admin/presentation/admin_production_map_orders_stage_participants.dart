part of 'admin_production_map_orders_screen.dart';

class _StageParticipantsSheet extends StatefulWidget {
  const _StageParticipantsSheet({
    required this.orderId,
    required this.stageNodeId,
    required this.apparatus,
    required this.apparatusTitle,
  });

  final String orderId;
  final String stageNodeId;
  final String apparatus;
  final String apparatusTitle;

  @override
  State<_StageParticipantsSheet> createState() =>
      _StageParticipantsSheetState();
}

class _StageParticipantsSheetState extends State<_StageParticipantsSheet> {
  late final String _scope;
  late Future<List<AdminStageParticipant>> _future;

  @override
  void initState() {
    super.initState();
    _scope = currentSessionReadScope();
    _future = _load();
    AppSession.instance.revision.addListener(_sessionChanged);
  }

  Future<List<AdminStageParticipant>> _load() =>
      MobileApi.instance.adminStageParticipants(
        orderId: widget.orderId,
        stageNodeId: widget.stageNodeId,
        apparatus: widget.apparatus,
      );

  void _sessionChanged() {
    if (mounted && _scope != currentSessionReadScope()) setState(() {});
  }

  @override
  void dispose() {
    AppSession.instance.revision.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final changed = _scope != currentSessionReadScope();
    final screenSize = MediaQuery.sizeOf(context);
    final maxHeight = screenSize.height * 0.7;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: screenSize.width,
          minHeight: min(280, maxHeight),
          maxHeight: maxHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.stageParticipantsText('title'),
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(widget.apparatusTitle,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                if (changed)
                  Text(l10n.stageParticipantsText('scope_changed'))
                else
                  Flexible(
                      child: FutureBuilder<List<AdminStageParticipant>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                            child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator()));
                      }
                      if (snapshot.hasError) {
                        return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(l10n.stageParticipantsText('error')),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _future = _load();
                                  });
                                },
                                child: Text(
                                    l10n.productionText('worker.action.retry')),
                              ),
                            ]);
                      }
                      final people =
                          snapshot.data ?? const <AdminStageParticipant>[];
                      if (people.isEmpty)
                        return Text(l10n.stageParticipantsText('empty'));
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: people.length,
                        itemBuilder: (context, index) {
                          final person = people[index];
                          final details = [
                            if (person.started)
                              l10n.stageParticipantsText('started'),
                            l10n.stageParticipantsText(person.state),
                          ];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                                child: Icon(Icons.person_outline_rounded)),
                            title: Text(person.displayName.isEmpty
                                ? l10n.stageParticipantsText('unknown')
                                : person.displayName),
                            subtitle: Text(details.join(' · ')),
                          );
                        },
                      );
                    },
                  )),
              ]),
        ),
      ),
    );
  }
}
