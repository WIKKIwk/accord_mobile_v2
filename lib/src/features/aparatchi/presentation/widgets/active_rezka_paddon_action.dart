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

class _ActiveRezkaPaddonActionState extends State<ActiveRezkaPaddonAction> {
  String? _code;
  bool _busy = true;

  String _text(String key, {Map<String, Object> values = const {}}) =>
      context.l10n.productionText('worker.paddon.active.$key', values: values);

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final code = await ActiveRezkaPaddonStore.load(widget.apparatusId);
      if (mounted) setState(() => _code = code);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_text('save_failed'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final paddons =
          widget.loader?.call() ?? MobileApi.instance.adminPaddons(limit: 200);
      final selected = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(_text('choose'),
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            ListTile(
              key: const ValueKey('rezka-paddon-none'),
              leading: const Icon(Icons.link_off_outlined),
              title: Text(_text('none')),
              trailing: _code == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(''),
            ),
            Expanded(
                child: FutureBuilder<List<AdminPaddon>>(
              future: paddons,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: AppLoadingIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(_text('load_failed')));
                }
                final items = snapshot.data ?? const [];
                if (items.isEmpty) return Center(child: Text(_text('empty')));
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final paddon = items[index];
                    return ListTile(
                      key: ValueKey('rezka-paddon-${paddon.code}'),
                      leading: const Icon(Icons.pallet),
                      title: Text(paddon.code),
                      subtitle: Text(
                          _text('rolls', values: {'count': paddon.itemCount})),
                      trailing:
                          _code == paddon.code ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.of(context).pop(paddon.code),
                    );
                  },
                );
              },
            )),
          ]),
        ),
      );
      if (selected == null || !mounted) return;
      await ActiveRezkaPaddonStore.save(widget.apparatusId, selected);
      if (!mounted) return;
      setState(() => _code = selected.isEmpty ? null : selected);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
        selected.isEmpty
            ? _text('none')
            : _text('selected', values: {'code': selected}),
      )));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_text('save_failed'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
        key: const ValueKey('rezka-active-paddon'),
        tooltip: _code == null
            ? _text('choose')
            : _text('selected', values: {'code': _code!}),
        onPressed: _busy ? null : _choose,
        color: _code == null ? null : Theme.of(context).colorScheme.primary,
        icon: Badge(
          isLabelVisible: _code != null,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.pallet, size: 22),
        ),
      );
}
