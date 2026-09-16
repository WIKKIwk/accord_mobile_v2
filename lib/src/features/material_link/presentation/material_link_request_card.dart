import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/session/state/app_session.dart';
import '../../shared/models/app_models.dart';
import '../models/material_link_request.dart';

class MaterialLinkRequestCard extends StatefulWidget {
  const MaterialLinkRequestCard({super.key, required this.request});
  final MaterialLinkRequest request;
  @override
  State<MaterialLinkRequestCard> createState() =>
      _MaterialLinkRequestCardState();
}

class _MaterialLinkRequestCardState extends State<MaterialLinkRequestCard> {
  late MaterialLinkRequest _request = widget.request;
  Timer? _timer;
  bool _busy = false;
  bool _refreshing = false;
  String _error = '';

  bool get _canDecide {
    final profile = AppSession.instance.profile;
    return profile != null &&
        profile.hasCapability('raw_material.assign') &&
        (profile.role == UserRole.admin ||
            (profile.role == UserRole.materialTaminotchi &&
                profile.ref == _request.moverRef));
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_request.pending && !_busy) unawaited(_refresh());
    });
  }

  @override
  void didUpdateWidget(covariant MaterialLinkRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.request.id != _request.id ||
        widget.request.revision > _request.revision) {
      _request = widget.request;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<bool> _refresh() async {
    if (_refreshing) return false;
    _refreshing = true;
    try {
      final request = await MobileApi.instance.materialLinkRequest(_request.id);
      if (!mounted) return false;
      if (request.revision >= _request.revision) {
        setState(() {
          _request = request;
          _error = '';
        });
      }
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
      return false;
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _decide(bool approve) async {
    if (_busy || !_canDecide || !_request.pending) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      if (!await _refresh() || !mounted || !_request.pending) return;
      List<String> selected = const [];
      if (approve) {
        final picked = await showModalBottomSheet<List<String>>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (_) => MaterialLinkRollPicker(rolls: _request.rolls),
        );
        if (picked == null || picked.isEmpty || !mounted) return;
        selected = picked;
      }
      final request = await MobileApi.instance.decideMaterialLinkRequest(
        requestId: _request.id,
        action: approve ? 'approve' : 'reject',
        barcodes: selected,
      );
      if (!mounted) return;
      if (request.revision >= _request.revision) {
        setState(() => _request = request);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
      // A timeout may have happened after commit. Recover from the shared server state.
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final decidedAt = _request.decidedAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(_request.decidedAt * 1000)
            .toLocal()
        : null;
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Homashyo ulash so‘rovi',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
            'Order: ${_request.orderNumber.isEmpty ? _request.orderId : _request.orderNumber}'),
        Text('Apparat: ${_request.apparatusName}'),
        Text('Worker: ${_request.requesterName}'),
        Text('Ko‘chirgan: ${_request.moverName}'),
        const SizedBox(height: 8),
        Text(_request.statusLabel, key: const ValueKey('material-link-status')),
        if (_request.pending)
          Text('${_request.rolls.length} ta rulondan keraklisini tanlang'),
        if (_request.selectedBarcodes.isNotEmpty)
          Text('Ulangan rulonlar: ${_request.selectedBarcodes.join(', ')}'),
        if (_request.reason.isNotEmpty) Text(_request.reason),
        if (_request.decidedBy.isNotEmpty) Text('Qaror: ${_request.decidedBy}'),
        if (decidedAt != null)
          Text('${decidedAt.day}.${decidedAt.month}.${decidedAt.year} '
              '${decidedAt.hour.toString().padLeft(2, '0')}:${decidedAt.minute.toString().padLeft(2, '0')}'),
        if (_error.isNotEmpty) ...[
          Text(_error,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          TextButton(
              onPressed: _busy ? null : _refresh,
              child: const Text('Holatni yangilash')),
        ],
        if (_request.pending && _canDecide) ...[
          const SizedBox(height: 12),
          FilledButton(
              onPressed: _busy ? null : () => _decide(true),
              child: const Text('Ha, ulash')),
          OutlinedButton(
              onPressed: _busy ? null : () => _decide(false),
              child: const Text('Yo‘q')),
        ],
      ]),
    ));
  }
}

String _errorText(Object error) => error is MobileApiException
    ? error.message
    : 'Aloqa uzildi. So‘rov holatini yangilang';

/// Always opens empty. Only explicitly checked barcodes are submitted.
class MaterialLinkRollPicker extends StatefulWidget {
  const MaterialLinkRollPicker({super.key, required this.rolls});
  final List<MaterialLinkRoll> rolls;
  @override
  State<MaterialLinkRollPicker> createState() => _MaterialLinkRollPickerState();
}

class _MaterialLinkRollPickerState extends State<MaterialLinkRollPicker> {
  final Set<String> _selected = {};
  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text('Ulanadigan rulonlarni tanlang',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(
                  child: ListView.builder(
                itemCount: widget.rolls.length,
                itemBuilder: (context, index) {
                  final roll = widget.rolls[index];
                  return CheckboxListTile(
                    key: ValueKey('material-link-roll-${roll.barcode}'),
                    value: _selected.contains(roll.barcode),
                    title: Text('${roll.barcode} • ${roll.itemName}'),
                    subtitle:
                        Text('${roll.qty} ${roll.uom} • ${roll.locationName}'),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _selected.add(roll.barcode);
                      } else {
                        _selected.remove(roll.barcode);
                      }
                    }),
                  );
                },
              )),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.of(context)
                            .pop(_selected.toList()..sort()),
                    child: Text('Tanlanganlarni ulash (${_selected.length})'),
                  )),
            ])),
      );
}
