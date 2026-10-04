import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/production/active_rezka_paddon_store.dart';
import '../../../../core/session/session.dart';
import '../../../../core/session/session_read_scope.dart';
import '../../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../../core/localization/urdu_aware_text.dart';

class ActiveRezkaPaddonAction extends StatefulWidget {
  const ActiveRezkaPaddonAction({
    super.key,
    required this.apparatusId,
    this.loader,
  });

  final String apparatusId;
  final Future<List<AdminPaddon>> Function()? loader;

  @override
  State<ActiveRezkaPaddonAction> createState() =>
      _ActiveRezkaPaddonActionState();
}

class _ActiveRezkaPaddonActionState extends State<ActiveRezkaPaddonAction>
    with WidgetsBindingObserver {
  final _selection = ValueNotifier<AsyncSnapshot<String?>>(
    const AsyncSnapshot.waiting(),
  );
  Timer? _timer;
  Future<void>? _refreshing;
  bool _busy = false;
  bool _saving = false;
  ModalRoute<dynamic>? _route;
  ModalRoute<dynamic>? _pickerRoute;
  bool _routeVisible = false;
  int _generation = 0;

  late Object _observedScope;

  Object get _scope => (currentSessionReadScope(), widget.apparatusId);

  bool get _canPoll {
    final state = WidgetsBinding.instance.lifecycleState;
    // The owned picker displays this same selection and remains live.
    final visible = (_route?.isCurrent ?? _routeVisible) ||
        (_pickerRoute?.isCurrent ?? false);
    return visible &&
        !_saving &&
        (state == null || state == AppLifecycleState.resumed);
  }

  bool _isCurrent(Object scope, int generation) =>
      mounted && scope == _scope && generation == _generation;

  String _text(String key, {Map<String, Object> values = const {}}) =>
      context.l10n.productionText('worker.paddon.active.$key', values: values);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _observedScope = _scope;
    AppSession.instance.revision.addListener(_sessionChanged);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_canPoll) {
        unawaited(_refresh());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    final visible = _route?.isCurrent ?? true;
    final becameVisible = visible && !_routeVisible;
    _routeVisible = visible;
    if (becameVisible && _canPoll && !_busy) unawaited(_refresh());
  }

  @override
  void didUpdateWidget(covariant ActiveRezkaPaddonAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apparatusId != widget.apparatusId) _resetScope();
  }

  void _sessionChanged() {
    if (_observedScope != _scope) _resetScope();
  }

  void _resetScope() {
    _observedScope = _scope;
    _generation++;
    _refreshing = null;
    _busy = false;
    _saving = false;
    _pickerRoute = null;
    _selection.value = const AsyncSnapshot.waiting();
    if (_canPoll) unawaited(_refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _canPoll) {
      // Route dependency rebuilds may have been deferred while paused. Mark
      // the current visibility now so the resume frame does not read twice.
      _routeVisible = _route?.isCurrent ?? true;
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() {
    if (_refreshing case final pending?) return pending;
    late final Future<void> future;
    future = _readSelection().whenComplete(() {
      if (identical(_refreshing, future)) _refreshing = null;
    });
    _refreshing = future;
    return future;
  }

  Future<void> _readSelection() async {
    final scope = _scope;
    final generation = _generation;
    try {
      final code = await ActiveRezkaPaddonStore.load(widget.apparatusId);
      if (_isCurrent(scope, generation)) {
        _selection.value = AsyncSnapshot.withData(ConnectionState.done, code);
      }
    } catch (error) {
      // Unknown is not the same as deliberately selecting "no pallet".
      if (_isCurrent(scope, generation)) {
        _selection.value = AsyncSnapshot.withError(ConnectionState.done, error);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AppSession.instance.revision.removeListener(_sessionChanged);
    _selection.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    if (_busy) return;
    final scope = _scope;
    final generation = _generation;
    final apparatusId = widget.apparatusId;
    setState(() => _busy = true);
    try {
      await _refresh();
      if (!mounted || !_isCurrent(scope, generation)) return;
      final paddons =
          widget.loader?.call() ?? MobileApi.instance.adminPaddons(limit: 200);
      final selected = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          if (_isCurrent(scope, generation)) {
            _pickerRoute = ModalRoute.of(context);
          }
          return SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.65,
            child: FutureBuilder<List<AdminPaddon>>(
              future: paddons,
              builder: (context, list) =>
                  ValueListenableBuilder<AsyncSnapshot<String?>>(
                valueListenable: _selection,
                builder: (context, selection, _) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        _text('choose'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (!_isCurrent(scope, generation) ||
                        selection.hasError ||
                        list.hasError)
                      Expanded(
                        child: Center(child: Text(_text('load_failed'))),
                      )
                    else if (selection.connectionState !=
                            ConnectionState.done ||
                        list.connectionState != ConnectionState.done)
                      const Expanded(
                        child: Center(child: AppLoadingIndicator()),
                      )
                    else ...[
                      ListTile(
                        key: const ValueKey('rezka-paddon-none'),
                        leading: const Icon(Icons.link_off_outlined),
                        title: Text(_text('none')),
                        trailing: selection.data == null
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () => Navigator.of(context).pop(''),
                      ),
                      Expanded(
                        child: (list.data ?? []).isEmpty
                            ? Center(child: Text(_text('empty')))
                            : ListView.builder(
                                itemCount: list.data!.length,
                                itemBuilder: (context, index) {
                                  final paddon = list.data![index];
                                  return ListTile(
                                    key: ValueKey(
                                      'rezka-paddon-${paddon.code}',
                                    ),
                                    leading: const Icon(Icons.pallet),
                                    title: Text(paddon.code),
                                    subtitle: Text(
                                      _text(
                                        'rolls',
                                        values: {'count': paddon.itemCount},
                                      ),
                                    ),
                                    trailing: selection.data == paddon.code
                                        ? const Icon(Icons.check)
                                        : null,
                                    onTap: () => Navigator.of(
                                      context,
                                    ).pop(paddon.code),
                                  );
                                },
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (!_isCurrent(scope, generation)) return;
      _pickerRoute = null;
      if (selected == null) return;
      _saving = true;
      await _refreshing;
      if (!_isCurrent(scope, generation)) return;
      await ActiveRezkaPaddonStore.save(apparatusId, selected);
      if (!_isCurrent(scope, generation)) return;
      // Read again after saving: another device may have changed the choice.
      await _refresh();
    } catch (_) {
      if (mounted && _isCurrent(scope, generation)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_text('save_failed'))));
      }
    } finally {
      if (_isCurrent(scope, generation)) {
        _pickerRoute = null;
        _saving = false;
        _routeVisible = _route?.isCurrent ?? true;
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<AsyncSnapshot<String?>>(
        valueListenable: _selection,
        builder: (context, selection, _) => IconButton(
          key: const ValueKey('rezka-active-paddon'),
          tooltip: selection.hasError
              ? _text('load_failed')
              : selection.data == null
                  ? _text('choose')
                  : _text('selected', values: {'code': selection.data!}),
          onPressed: _busy ? null : _choose,
          color: selection.data == null
              ? null
              : Theme.of(context).colorScheme.primary,
          icon: Badge(
            isLabelVisible: selection.data != null || selection.hasError,
            label: selection.hasError ? const UrduAwareText('!') : null,
            backgroundColor: selection.hasError
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.pallet, size: 22),
          ),
        ),
      );
}
