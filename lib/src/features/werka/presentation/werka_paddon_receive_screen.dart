import 'dart:async';

import 'package:flutter/material.dart';
import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/raw_material_scan_dialog.dart';
import '../../aparatchi/presentation/aparatchi_paddon_detail_screen.dart';
import '../../shared/models/app_models.dart';
import 'widgets/werka_dock.dart';
import '../../../core/localization/urdu_aware_text.dart';

class WerkaPaddonReceiveScreen extends StatefulWidget {
  const WerkaPaddonReceiveScreen(
      {super.key,
      this.initialCode,
      this.initialPreview,
      this.loadPreview,
      this.receive,
      this.loadApparatusNames});
  final String? initialCode;
  final WerkaPaddonPreview? initialPreview;
  final Future<WerkaPaddonPreview> Function(String)? loadPreview;
  final Future<Map<String, dynamic>> Function(WerkaPaddonPreview, String)?
      receive;
  final Future<Map<String, String>> Function()? loadApparatusNames;
  @override
  State<WerkaPaddonReceiveScreen> createState() =>
      _WerkaPaddonReceiveScreenState();
}

class _WerkaPaddonReceiveScreenState extends State<WerkaPaddonReceiveScreen> {
  WerkaPaddonPreview? _preview;
  Map<String, dynamic>? _receipt;
  String? _warehouse;
  String _error = '', _code = '';
  bool _busy = false, _mustReload = false, _confirming = false;
  Map<String, String> _apparatusNames = const {};
  static final _apparatusIdPattern = RegExp(
    r'apparatus:[^\s,;•()\[\]{}]+',
    caseSensitive: false,
  );
  @override
  void initState() {
    super.initState();
    if (widget.loadApparatusNames != null) unawaited(_loadApparatusNames());
    if (widget.initialPreview != null) {
      _code = widget.initialCode ?? widget.initialPreview!.snapshot.paddon.code;
      _applyPreview(widget.initialPreview!);
    } else if (widget.initialCode != null) {
      _load(widget.initialCode!);
    }
  }

  Future<void> _loadApparatusNames() async {
    try {
      final names = widget.loadApparatusNames != null
          ? await widget.loadApparatusNames!()
          : const <String, String>{};
      if (!mounted) return;
      setState(() {
        _apparatusNames = {
          for (final entry in names.entries)
            if (entry.value.trim().isNotEmpty &&
                !_apparatusIdPattern.hasMatch(entry.value))
              entry.key.trim(): entry.value.trim(),
        };
      });
    } catch (_) {
      // Catalog access is optional; pallet actions use the original preview.
    }
  }

  String _displayLabel(String value) {
    final l10n = context.l10n;
    final unavailable = l10n.isUrdu
        ? 'مشین کا نام دستیاب نہیں'
        : l10n.isUzbek
            ? 'Apparat nomi mavjud emas'
            : l10n.isRussian
                ? 'Название аппарата недоступно'
                : 'Machine name unavailable';
    return value.replaceAllMapped(_apparatusIdPattern,
        (match) => _apparatusNames[match.group(0)!] ?? unavailable);
  }

  Future<void> _load(String raw) async {
    if (_busy) return;
    final code = raw.trim();
    if (code.isEmpty) {
      setState(() => _error = context.l10n.isUrdu
          ? 'QR کوڈ اسکین کریں یا درج کریں۔'
          : 'QR kodni skanerlang yoki kiriting.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
      _code = code;
    });
    try {
      final preview = await (widget.loadPreview ??
          MobileApi.instance.werkaPaddonPreview)(code);
      if (!mounted) return;
      setState(() {
        _applyPreview(preview);
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _message(error);
          _mustReload = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyPreview(WerkaPaddonPreview preview) {
    _preview = preview;
    _receipt = preview.receipt;
    _mustReload = false;
    _apparatusNames = {..._apparatusNames, ...preview.apparatusNames};
    _warehouse = preview.warehouses.contains(_warehouse)
        ? _warehouse
        : preview.warehouses.length == 1
            ? preview.warehouses.single
            : null;
  }

  String _message(Object error, {bool receiving = false}) {
    if (error is MobileApiException) {
      return switch (error.code) {
        'forbidden' =>
          'Bu amalga yoki omborga ruxsat yo‘q. Sizga ombor biriktirilganini tekshiring.',
        'paddon_not_found' => 'Paddon topilmadi. QR kodni tekshiring.',
        'paddon_receipt_conflict' =>
          'Paddon tarkibi yoki rulon ma’lumoti o‘zgargan. Qayta tekshiring.',
        'paddon_already_received' =>
          'Paddon avval kirim qilingan. Qayta tekshiring.',
        'progress_batch_not_accepted' =>
          'Paddonda kirimga tayyor bo‘lmagan yoki avval qabul qilingan rulon bor.',
        'paddon_invalid_input' =>
          'Paddon bo‘sh yoki kirim ma’lumotlari yetarli emas.',
        _ => 'Kirimni tekshirib bo‘lmadi. Qayta tekshiring.',
      };
    }
    return receiving
        ? 'Server javobi olinmadi. Kirim bajarilgan bo‘lishi mumkin. Qayta tekshiring.'
        : 'Server javobi olinmadi. Qayta tekshiring.';
  }

  AdminPaddonSnapshot _sharedSnapshot(WerkaPaddonPreview preview) {
    final receivedPaddon = _receipt?['paddon'];
    if (receivedPaddon is! Map) return preview.snapshot;
    return AdminPaddonSnapshot(
      paddon: AdminPaddon.fromJson(receivedPaddon.cast<String, dynamic>()),
      items: preview.snapshot.items,
    );
  }

  Future<AdminPaddonSnapshot> _refreshSharedSnapshot() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final preview = await (widget.loadPreview ??
          MobileApi.instance.werkaPaddonPreview)(_code);
      if (!mounted) return preview.snapshot;
      setState(() => _applyPreview(preview));
      return _sharedSnapshot(preview);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _message(error);
          _mustReload = true;
        });
      }
      rethrow;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() async {
    final preview = _preview;
    final warehouse = _warehouse;
    if (_busy ||
        _mustReload ||
        preview == null ||
        warehouse == null ||
        _receipt != null ||
        !preview.canReceive ||
        preview.snapshotToken.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _confirming = true;
    });
    final confirmed = await showM3ConfirmDialog(
        context: context,
        title: 'Paddonni kirim qilish',
        message:
            '${preview.snapshot.paddon.code} paddonidagi ${preview.snapshot.items.length} ta rulon «${_displayLabel(warehouse)}» omboriga qabul qilinadi.',
        cancelLabel: 'Bekor qilish',
        confirmLabel: 'Kirim qilish',
        confirmButtonKey: const ValueKey('werka-paddon-confirm'));
    if (!mounted) return;
    setState(() {
      _confirming = false;
      _busy = confirmed == true;
    });
    if (confirmed != true) return;
    try {
      final receipt = await (widget.receive ??
          MobileApi.instance.werkaReceivePaddon)(preview, warehouse);
      if (mounted) {
        setState(() {
          _receipt = receipt;
          _error = '';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _message(error, receiving: true);
          _mustReload = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildReceiptActions(
    BuildContext context,
    Future<void> Function() refresh,
  ) {
    final preview = _preview!;
    final receipt = _receipt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_busy && !_confirming) const LinearProgressIndicator(),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error,
              key: const ValueKey('werka-paddon-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (receipt != null)
          Card.filled(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const UrduAwareText(
                    'Omborga kirim qilingan',
                    key: ValueKey('werka-paddon-received'),
                  ),
                  UrduAwareText(
                    'Ombor: ${_displayLabel('${receipt['warehouse']}')}',
                  ),
                  UrduAwareText(
                    'Qabul qildi: ${receipt['accepted_by_display_name']}',
                  ),
                  if (receipt['accepted_at_unix'] is num)
                    UrduAwareText(
                      'Vaqt: ${formatUnixSecondsLocalDateTime((receipt['accepted_at_unix'] as num).toInt())}',
                    ),
                ],
              ),
            ),
          )
        else ...[
          if (!preview.canReceive)
            const Padding(
              padding: EdgeInsets.all(12),
              child: UrduAwareText(
                'Kirim mumkin emas: paddon bo‘sh yoki tarkibida tayyor bo‘lmagan / qabul qilingan rulon bor.',
              ),
            ),
          DropdownButtonFormField<String>(
            key: ValueKey('werka-paddon-warehouse-$_warehouse'),
            initialValue: _warehouse,
            decoration: InputDecoration(
              labelText: localizeUrduUiText('Qabul qiluvchi ombor'),
            ),
            items: preview.warehouses
                .map((w) => DropdownMenuItem(
                      value: w,
                      child: Text(_displayLabel(w)),
                    ))
                .toList(),
            onChanged:
                _busy ? null : (value) => setState(() => _warehouse = value),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('werka-paddon-receive'),
            onPressed: _busy ||
                    _mustReload ||
                    !preview.canReceive ||
                    preview.snapshotToken.isEmpty ||
                    _warehouse == null
                ? null
                : _accept,
            icon: const Icon(Icons.inventory_2_outlined),
            label: const UrduAwareText('Omborga kirim qilish'),
          ),
        ],
        TextButton(
          onPressed: _busy ? null : () => unawaited(refresh()),
          child: const UrduAwareText('Qayta tekshirish'),
        ),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => Navigator.of(context).pushReplacementNamed(
                    AppRoutes.werkaStockEntryQrScan,
                  ),
          icon: const Icon(Icons.qr_code_scanner),
          label: const UrduAwareText('Keyingi QR kodni skanerlash'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return PopScope(
      canPop: !_busy,
      child: preview != null
          ? AparatchiPaddonDetailScreen(
              key: ValueKey(preview.snapshot.paddon.code),
              code: preview.snapshot.paddon.code,
              snapshot: _sharedSnapshot(preview),
              loader: _refreshSharedSnapshot,
              apparatus: [
                for (final entry in _apparatusNames.entries)
                  AdminApparatus(
                    id: entry.key,
                    name: entry.value,
                    operation: '',
                    technology: '',
                    sourceRevision: 1,
                  ),
              ],
              manageItems: false,
              busy: _busy,
              bottom: _busy
                  ? const SizedBox.shrink()
                  : const WerkaDock(activeTab: null, showPrimaryFab: false),
              footerBuilder: _buildReceiptActions,
            )
          : AppShell(
              title: 'Paddon kirimi',
              subtitle: '',
              nativeTopBar: true,
              bottom: _busy
                  ? null
                  : const WerkaDock(activeTab: null, showPrimaryFab: false),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 140),
                children: [
                  if (_busy && !_confirming) const LinearProgressIndicator(),
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error,
                        key: const ValueKey('werka-paddon-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ProductionQuickScannerPanel(
                    key: const ValueKey('werka-paddon-scanner'),
                    onCodeDetected: _load,
                    statusText: 'Paddon QR kodini skanerlang',
                    busy: _busy,
                  ),
                  if (_mustReload)
                    TextButton(
                      onPressed: _busy ? null : () => _load(_code),
                      child: const UrduAwareText('Qayta tekshirish'),
                    ),
                ],
              ),
            ),
    );
  }
}
