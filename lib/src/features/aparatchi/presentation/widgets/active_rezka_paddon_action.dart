import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/production/active_rezka_paddon_store.dart';
import '../../../../core/widgets/shell/app_loading_indicator.dart';

class ActiveRezkaPaddonAction extends StatefulWidget {
  const ActiveRezkaPaddonAction(
      {super.key, required this.apparatusId, this.loader});

  final String apparatusId;
  final Future<List<AdminPaddon>> Function()? loader;

  @override
  State<ActiveRezkaPaddonAction> createState() =>
      _ActiveRezkaPaddonActionState();
}

class _ActiveRezkaPaddonActionState extends State<ActiveRezkaPaddonAction>
    with WidgetsBindingObserver {
  final _selection =
      ValueNotifier<AsyncSnapshot<String?>>(const AsyncSnapshot.waiting());
  Timer? _timer;
  Future<void>? _refreshing;
  bool _busy = false;
  bool _saving = false;

  String _text(String key, {Map<String, Object> values = const {}}) =>
      context.l10n.productionText('worker.paddon.active.$key', values: values);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      final state = WidgetsBinding.instance.lifecycleState;
      if (!_saving && (state == null || state == AppLifecycleState.resumed)) {
        unawaited(_refresh());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_saving) unawaited(_refresh());
  }

  Future<void> _refresh() =>
      _refreshing ??= _readSelection().whenComplete(() => _refreshing = null);

  Future<void> _readSelection() async {
    try {
      final code = await ActiveRezkaPaddonStore.load(widget.apparatusId);
      if (mounted) {
        _selection.value = AsyncSnapshot.withData(ConnectionState.done, code);
      }
    } catch (error) {
      // Unknown is not the same as deliberately selecting "no pallet".
      if (mounted) {
        _selection.value = AsyncSnapshot.withError(ConnectionState.done, error);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _selection.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _refresh();
      if (!mounted) return;
      final paddons =
          widget.loader?.call() ?? MobileApi.instance.adminPaddons(limit: 200);
      final selected = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: FutureBuilder<List<AdminPaddon>>(
            future: paddons,
            builder: (context, list) =>
                ValueListenableBuilder<AsyncSnapshot<String?>>(
              valueListenable: _selection,
              builder: (context, selection, _) => Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(_text('choose'),
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (selection.hasError || list.hasError)
                  Expanded(child: Center(child: Text(_text('load_failed'))))
                else if (selection.connectionState != ConnectionState.done ||
                    list.connectionState != ConnectionState.done)
                  const Expanded(child: Center(child: AppLoadingIndicator()))
                else ...[
                  ListTile(
                    key: const ValueKey('rezka-paddon-none'),
                    leading: const Icon(Icons.link_off_outlined),
                    title: Text(_text('none')),
                    trailing:
                        selection.data == null ? const Icon(Icons.check) : null,
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
                                  key: ValueKey('rezka-paddon-${paddon.code}'),
                                  leading: const Icon(Icons.pallet),
                                  title: Text(paddon.code),
                                  subtitle: Text(_text('rolls',
                                      values: {'count': paddon.itemCount})),
                                  trailing: selection.data == paddon.code
                                      ? const Icon(Icons.check)
                                      : null,
                                  onTap: () =>
                                      Navigator.of(context).pop(paddon.code),
                                );
                              },
                            )),
                ],
              ]),
            ),
          ),
        ),
      );
      if (selected == null || !mounted) return;
      _saving = true;
      await _refreshing;
      await ActiveRezkaPaddonStore.save(widget.apparatusId, selected);
      // Read again after saving: another device may have changed the choice.
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_text('save_failed'))));
      }
    } finally {
      _saving = false;
      if (mounted) setState(() => _busy = false);
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
            label: selection.hasError ? const Text('!') : null,
            backgroundColor: selection.hasError
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.pallet, size: 22),
          ),
        ),
      );
}
