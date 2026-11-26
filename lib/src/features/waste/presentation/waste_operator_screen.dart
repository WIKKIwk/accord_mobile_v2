import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/session/session.dart';
import '../../../core/session/session_read_scope.dart';
import '../../admin/presentation/raw_material_scan_dialog.dart';
import 'waste_bin_details.dart';

class WasteOperatorAction extends StatelessWidget {
  const WasteOperatorAction({
    super.key,
    this.apparatusId,
    this.apparatusName,
    this.orderId,
  });

  final String? apparatusId, apparatusName, orderId;

  @override
  Widget build(BuildContext context) {
    final profile = AppSession.instance.profile;
    final assigned = profile?.assignedApparatus ?? const [];
    if (assigned.isEmpty ||
        (apparatusId != null && !assigned.contains(apparatusId))) {
      return const SizedBox.shrink();
    }
    String labelFor(String id) {
      final labels = profile?.assignedApparatusLabels ?? const <String>[];
      final index = assigned.indexOf(id);
      return labels.length == assigned.length && index >= 0
          ? labels[index]
          : id;
    }

    return IconButton(
      icon: const Icon(Icons.recycling),
      tooltip: 'Chiqindi qutisi',
      onPressed: () async {
        final scope = currentSessionReadScope();
        final String? id;
        if (apparatusId != null) {
          id = apparatusId;
        } else if (assigned.length == 1) {
          id = assigned.single;
        } else {
          id = await showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            builder: (_) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  const ListTile(title: Text('Apparatni tanlang')),
                  for (final id in assigned)
                    ListTile(
                      title: Text(labelFor(id)),
                      onTap: () => Navigator.pop(context, id),
                    ),
                ],
              ),
            ),
          );
        }
        final selectedId = id;
        if (!context.mounted ||
            selectedId == null ||
            scope != currentSessionReadScope()) {
          return;
        }
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => WasteOperatorScreen(
              apparatusId: selectedId,
              apparatusName: apparatusName ?? labelFor(selectedId),
              orderId: orderId,
            ),
          ),
        );
      },
    );
  }
}

class WasteOperatorScreen extends StatefulWidget {
  const WasteOperatorScreen({
    super.key,
    required this.apparatusId,
    required this.apparatusName,
    this.orderId,
  });

  final String apparatusId, apparatusName;
  final String? orderId;

  @override
  State<WasteOperatorScreen> createState() => _WasteOperatorScreenState();
}

class _WasteOperatorScreenState extends State<WasteOperatorScreen> {
  final _api = MobileApi.instance;
  final _scope = currentSessionReadScope();
  WasteActiveBins? _snapshot;
  String? _error;
  bool _busy = false;
  (String, double, String)? _entryAttempt;
  String? _entryRequestId;

  bool get _current => mounted && currentSessionReadScope() == _scope;

  @override
  void initState() {
    super.initState();
    _run(_refresh);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!_current || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (_current) setState(() => _error = wasteErrorText(error));
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    final snapshot = await _api.activeWasteBin(widget.apparatusId);
    if (_current) setState(() => _snapshot = snapshot);
  }

  Future<String?> _pickBin() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EmptyWasteBinPicker(apparatusId: widget.apparatusId),
    );
    if (!mounted || choice != '' || !_current) return choice;
    return showRawMaterialScanDialog(
      context,
      title: 'Bo‘sh chiqindi qutisini skan qiling',
      manualLabel: 'Quti kodi',
      acceptCameraCode: isWasteBinQr,
    );
  }

  Future<void> _assign() async {
    final code = await _pickBin();
    if (!_current || code == null) return;
    await _run(() async {
      await _api.assignWasteBin(code, widget.apparatusId);
      await _refresh();
    });
  }

  Future<void> _submit(WasteBin bin, {required bool replace}) async {
    String? replacement;
    if (replace) {
      replacement = await _pickBin();
      if (!mounted || !_current || replacement == null) return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${bin.code} qutisini topshirish'),
        content: Text(replacement == null
            ? 'Quti qabulga yuboriladi. Keyingi chiqindi uchun bo‘sh quti biriktiring.'
            : 'Quti qabulga yuboriladi va bo‘sh quti apparatga biriktiriladi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Topshirish'),
          ),
        ],
      ),
    );
    if (!_current || confirmed != true) return;
    await _run(() async {
      await _api.submitWasteBin(
        bin: bin,
        apparatusId: widget.apparatusId,
        replacementCode: replacement,
      );
      await _refresh();
    });
  }

  Future<void> _record(WasteBin bin) async {
    final entry = await showDialog<(double, String)>(
      context: context,
      builder: (_) => _WasteRecordDialog(
        orderId: widget.orderId,
        initialKg:
            _entryAttempt?.$1 == bin.cycle!.id ? _entryAttempt?.$2 : null,
        initialReason:
            _entryAttempt?.$1 == bin.cycle!.id ? _entryAttempt?.$3 : null,
      ),
    );
    if (!_current || entry == null) return;
    final (kg, reason) = entry;
    final attempt = (bin.cycle!.id, kg, reason);
    if (_entryAttempt != attempt) {
      _entryAttempt = attempt;
      _entryRequestId = newWasteRequestId();
    }
    await _run(() async {
      await _api.addWasteEntry(
        bin: bin,
        apparatusId: widget.apparatusId,
        requestId: _entryRequestId!,
        kg: kg,
        reason: reason,
        orderId: widget.orderId,
      );
      _entryAttempt = null;
      _entryRequestId = null;
      await _refresh();
    });
  }

  Future<void> _reconcile(WasteBin bin, List<WasteEntry> pending) async {
    final selected = <String>{};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Qutiga yozuv biriktirish'),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                    'Faqat ${bin.code} qutisiga solingan chiqindilarni belgilang.'),
                for (final entry in pending)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title:
                        Text('${wasteKgLabel(entry.kg)} · ${entry.actorName}'),
                    subtitle: Text([
                      entry.reason,
                      entry.orderId,
                      wasteWhen(context, entry.createdAt),
                    ].where((value) => value.isNotEmpty).join(' · ')),
                    value: selected.contains(entry.id),
                    onChanged: (checked) => setDialogState(() {
                      if (checked == true) {
                        selected.add(entry.id);
                      } else {
                        selected.remove(entry.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Biriktirish'),
            ),
          ],
        ),
      ),
    );
    if (!_current || confirmed != true) return;
    await _run(() async {
      await _api.reconcileWasteEntries(
        bin: bin,
        apparatusId: widget.apparatusId,
        entryIds: selected.toList(),
      );
      await _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bin = _snapshot?.bin;
    final cycle = bin?.cycle;
    final pending = _snapshot?.pending ?? const <WasteEntry>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chiqindi qutisi'),
        actions: [
          IconButton(
            tooltip: 'Yangilash',
            onPressed: _busy ? null : () => _run(_refresh),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.apparatusName,
                style: Theme.of(context).textTheme.titleLarge),
            if (widget.orderId != null)
              Text('Buyurtma: ${widget.orderId}')
            else
              const Text('Buyurtmaga bog‘liq bo‘lmagan chiqindini kiriting.'),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.error),
                title: Text(_error!),
              ),
            if (_snapshot != null && bin == null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Faol quti yo‘q'),
                subtitle:
                    const Text('Bo‘sh qutini tanlang yoki QR’ni skan qiling.'),
                trailing: IconButton.filled(
                  tooltip: 'Quti tanlash',
                  onPressed: _busy ? null : _assign,
                  icon: const Icon(Icons.add),
                ),
              ),
            if (pending.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Qutiga biriktirilmagan: ${pending.length} ta'),
                trailing: bin != null
                    ? TextButton(
                        onPressed:
                            _busy ? null : () => _reconcile(bin, pending),
                        child: const Text('Biriktirish'),
                      )
                    : null,
              ),
            if (bin != null && cycle != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Faol quti ${bin.code}'),
                subtitle: Text(
                    'Qayd etilgan chiqindi: ${wasteKgLabel(cycle.expectedKg)}'),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _record(bin),
                    icon: const Icon(Icons.add),
                    label: const Text('Chiqindi qo‘shish'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _submit(bin, replace: true),
                    child: const Text('Qutini almashtirish'),
                  ),
                  OutlinedButton(
                    onPressed:
                        _busy ? null : () => _submit(bin, replace: false),
                    child: const Text('Qutini topshirish'),
                  ),
                ],
              ),
              WasteCycleDetails(cycle: cycle),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyWasteBinPicker extends StatefulWidget {
  const _EmptyWasteBinPicker({required this.apparatusId});

  final String apparatusId;

  @override
  State<_EmptyWasteBinPicker> createState() => _EmptyWasteBinPickerState();
}

class _EmptyWasteBinPickerState extends State<_EmptyWasteBinPicker> {
  late final _load = MobileApi.instance.wasteBins(
    apparatusId: widget.apparatusId,
    status: WasteBinStatus.empty,
  );

  @override
  Widget build(BuildContext context) => SafeArea(
        child: FutureBuilder<List<WasteBin>>(
          future: _load,
          builder: (context, snapshot) => ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('Qutini skan qilish'),
                onTap: () => Navigator.pop(context, ''),
              ),
              if (snapshot.connectionState != ConnectionState.done)
                const LinearProgressIndicator(),
              if (snapshot.hasError)
                ListTile(title: Text(wasteErrorText(snapshot.error!))),
              if (snapshot.data?.isEmpty == true)
                const ListTile(title: Text('Bo‘sh quti topilmadi')),
              for (final bin in snapshot.data ?? <WasteBin>[])
                ListTile(
                  title: Text(bin.code),
                  subtitle: Text('Tara ${wasteKgLabel(bin.tareKg)}'),
                  onTap: () => Navigator.pop(context, bin.code),
                ),
            ],
          ),
        ),
      );
}

class _WasteRecordDialog extends StatefulWidget {
  const _WasteRecordDialog({this.orderId, this.initialKg, this.initialReason});

  final String? orderId, initialReason;
  final double? initialKg;

  @override
  State<_WasteRecordDialog> createState() => _WasteRecordDialogState();
}

class _WasteRecordDialogState extends State<_WasteRecordDialog> {
  final _form = GlobalKey<FormState>();
  late final _qty = TextEditingController(text: widget.initialKg?.toString());
  late final _reason = TextEditingController(text: widget.initialReason);

  @override
  void dispose() {
    _qty.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Chiqindi qo‘shish'),
        content: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.orderId != null)
                  Text('Buyurtma: ${widget.orderId}')
                else
                  const Text(
                      'Buyurtmaga bog‘liq bo‘lmagan chiqindini kiriting.'),
                TextFormField(
                  controller: _qty,
                  decoration:
                      const InputDecoration(labelText: 'Yangi chiqindi (kg)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) => (wasteKgInput(value ?? '') ?? 0) <= 0
                      ? 'Vazn 0 dan katta bo‘lishi kerak'
                      : null,
                ),
                TextFormField(
                  controller: _reason,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Sabab'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Sababini kiriting' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              Navigator.pop(
                  context, (wasteKgInput(_qty.text)!, _reason.text.trim()));
            },
            child: const Text('Saqlash'),
          ),
        ],
      );
}
