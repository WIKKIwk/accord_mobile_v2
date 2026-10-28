import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';

String qolipReworkDate(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}

String qolipMileageMeter(double value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

Future<void> showQolipMileageSheet(BuildContext context, String code,
        {Widget Function(Widget child)? wrap}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          wrap?.call(_QolipMileageSheet(code: code)) ??
          _QolipMileageSheet(code: code),
    );

class _QolipMileageSheet extends StatefulWidget {
  const _QolipMileageSheet({required this.code});
  final String code;
  @override
  State<_QolipMileageSheet> createState() => _QolipMileageSheetState();
}

class _QolipMileageSheetState extends State<_QolipMileageSheet> {
  late Future<QolipMileage> _future;
  @override
  void initState() {
    super.initState();
    _future = MobileApi.instance.qolipMileage(widget.code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l10n.qolipReworkText('mileage'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SelectableText(widget.code,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Expanded(
              child: FutureBuilder<QolipMileage>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: AppLoadingIndicator());
              }
              if (snapshot.hasError) {
                return AppRetryState(onRetry: () async {
                  setState(() =>
                      _future = MobileApi.instance.qolipMileage(widget.code));
                  await _future;
                });
              }
              final mileage = snapshot.data!;
              return ListView(children: [
                Text(
                    mileage.trackingEnabled && mileage.currentMeter != null
                        ? l10n.qolipReworkText('current', values: {
                            'meter': qolipMileageMeter(mileage.currentMeter!)
                          })
                        : l10n.qolipReworkText('not_started'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                for (final cycle in mileage.cycles.reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(cycle.endedAt == null
                        ? Icons.speed_rounded
                        : Icons.history_rounded),
                    title: Text(l10n.qolipReworkText('cycle',
                        values: {'meter': qolipMileageMeter(cycle.meter)})),
                    subtitle: Text('${qolipReworkDate(cycle.startedAt)} → '
                        '${cycle.endedAt == null ? l10n.qolipReworkText('active_cycle') : qolipReworkDate(cycle.endedAt!)}'),
                  ),
              ]);
            },
          )),
        ]),
      ),
    );
  }
}
