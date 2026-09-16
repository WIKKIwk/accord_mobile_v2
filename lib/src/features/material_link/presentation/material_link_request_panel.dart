import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../models/material_link_request.dart';
import 'material_link_request_card.dart';

class MaterialLinkRequestPanel extends StatefulWidget {
  const MaterialLinkRequestPanel(
      {super.key,
      required this.orderId,
      required this.apparatusId,
      required this.onMaterialsLinked});
  final String orderId, apparatusId;
  final VoidCallback onMaterialsLinked;
  @override
  State<MaterialLinkRequestPanel> createState() =>
      _MaterialLinkRequestPanelState();
}

class _MaterialLinkRequestPanelState extends State<MaterialLinkRequestPanel> {
  Timer? _timer;
  MaterialLinkOverview? _overview;
  final Set<String> _seenMaterialChanges = {};
  bool _loading = false, _busy = false;
  String _error = '';
  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_busy) unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final overview = await MobileApi.instance.materialLinkRequests(
          orderId: widget.orderId, apparatus: widget.apparatusId);
      if (!mounted) return;
      final changed = overview.requests
          .where((r) => r.status == 'approved' || r.status == 'stale')
          .map((r) => r.id)
          .toSet()
          .difference(_seenMaterialChanges);
      _seenMaterialChanges.addAll(changed);
      setState(() {
        _overview = overview;
        _error = '';
      });
      if (changed.isNotEmpty) widget.onMaterialsLinked();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is MobileApiException
            ? error.message
            : 'So‘rov holatini yangilab bo‘lmadi');
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final overview = await MobileApi.instance.materialLinkRequests(
          orderId: widget.orderId, apparatus: widget.apparatusId);
      if (!mounted) return;
      setState(() => _overview = overview);
      if (overview.requests.any((r) => r.pending)) return;
      if (overview.candidates.isEmpty) {
        setState(() =>
            _error = 'Ulash mumkin bo‘lgan rulon qolmagan. Holatni yangilang');
        return;
      }
      final selected = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => MaterialLinkRollPicker(
          rolls: overview.candidates,
          title: 'So‘rov yuboriladigan rulonlarni tanlang',
          submitLabel: 'So‘rov yuborish',
        ),
      );
      if (!mounted || selected == null || selected.isEmpty) return;
      await MobileApi.instance.createMaterialLinkRequests(
          orderId: widget.orderId,
          apparatus: widget.apparatusId,
          barcodes: selected);
      await _refresh();
    } catch (error) {
      // Re-read after ambiguous transport errors; a committed request must not be duplicated.
      await _refresh();
      if (mounted) {
        setState(() => _error = error is MobileApiException
            ? error.message
            : 'So‘rov yuborilmadi. Holatni yangilang');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(MaterialLinkRequest request) async {
    setState(() => _busy = true);
    try {
      await MobileApi.instance
          .decideMaterialLinkRequest(requestId: request.id, action: 'cancel');
      await _refresh();
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            error is MobileApiException ? error.message : 'Aloqa uzildi');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = _overview?.requests ?? const <MaterialLinkRequest>[];
    final latest = <String, MaterialLinkRequest>{};
    for (final request in requests) {
      latest.putIfAbsent(request.moverRef, () => request);
    }
    final pending = latest.values.any((r) => r.pending);
    final available = _overview?.candidates.isNotEmpty ?? false;
    if (!available && latest.isEmpty && _error.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (available) ...[
              Text('Orderga ulanmagan rulonlar',
                  style: Theme.of(context).textTheme.titleSmall),
              Text(
                  'Apparat oldidagi ${_overview!.candidates.length} ta mos rulondan keraklisini tanlab so‘rov yuboring'),
            ],
            for (final request in latest.values) ...[
              Text('${request.moverName}: ${request.statusLabel}'),
              Text('So‘ralgan rulonlar: '
                  '${request.rolls.map((roll) => roll.barcode).join(', ')}'),
              if (request.reason.isNotEmpty) Text(request.reason),
              if (request.pending)
                TextButton(
                  onPressed: _busy ? null : () => _cancel(request),
                  child: const Text('So‘rovni bekor qilish'),
                ),
            ],
            if (_error.isNotEmpty) ...[
              Text(_error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              TextButton(
                  onPressed: _busy ? null : _refresh,
                  child: const Text('Holatni yangilash')),
            ],
            if (available || pending)
              OutlinedButton.icon(
                onPressed: _busy || pending || !available ? null : _send,
                icon: const Icon(Icons.send_outlined),
                label:
                    Text(pending ? 'Tasdiq kutilmoqda' : 'Ulash uchun so‘rov'),
              ),
            if (!available && !pending && latest.isNotEmpty)
              const Text(
                  'Hozir bu orderga ulash mumkin bo‘lgan bo‘sh rulon yo‘q'),
          ],
        ));
  }
}
