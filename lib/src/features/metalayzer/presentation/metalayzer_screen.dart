import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_action_button_styles.dart';
import '../../../core/widgets/display/app_info_row.dart';
import '../../../core/widgets/display/app_status_chip.dart';
import '../../../core/widgets/forms/app_input_decoration.dart';
import '../../../core/widgets/lists/app_segment_surface_card.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/raw_material_scan_dialog.dart';
import 'metalayzer_navigation.dart';

class MetalayzerScreen extends StatefulWidget {
  const MetalayzerScreen({super.key});

  @override
  State<MetalayzerScreen> createState() => _MetalayzerScreenState();
}

class _MetalayzerScreenState extends State<MetalayzerScreen> {
  final _barcode = TextEditingController();
  MetalayzerMaterial? _material;
  String? _error, _inputError, _scope;
  bool _busy = false, _saving = false;
  int _operationId = 0;

  @override
  void initState() {
    super.initState();
    _scope = _currentScope();
    AppSession.instance.revision.addListener(_sessionChanged);
  }

  @override
  void dispose() {
    AppSession.instance.revision.removeListener(_sessionChanged);
    _barcode.dispose();
    super.dispose();
  }

  String? _currentScope() {
    try {
      return MobileApi.instance.metalayzerScope();
    } on StateError {
      return null;
    }
  }

  void _sessionChanged() {
    final scope = _currentScope();
    if (!mounted || scope == _scope) return;
    setState(() {
      _scope = scope;
      _operationId++;
      _barcode.clear();
      _material = null;
      _error = _inputError = null;
      _busy = _saving = false;
    });
  }

  bool _isCurrent(int operation, String scope) {
    if (!mounted || operation != _operationId) return false;
    if (_currentScope() != scope) {
      _sessionChanged();
      return false;
    }
    return true;
  }

  Future<void> _lookup({bool scan = false}) async {
    if (_busy || _scope == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final scope = _scope!;
    final operation = ++_operationId;
    setState(() {
      _busy = true;
      _error = _inputError = null;
    });
    try {
      if (scan) {
        final code = await showRawMaterialScanDialog(context,
            title: 'Xomashyoni skan qiling');
        if (!_isCurrent(operation, scope) || code == null) return;
        _barcode.text = code;
      }
      final barcode = rawMaterialBarcodeFromQr(_barcode.text);
      if (barcode.isEmpty) {
        setState(() => _inputError = 'Xomashyo QR kodini kiriting');
        return;
      }
      _barcode.text = barcode;
      setState(() => _material = null);
      final material = await MobileApi.instance.metalayzerMaterial(barcode);
      if (_isCurrent(operation, scope)) {
        setState(() => _material = material);
      }
    } catch (error) {
      if (_isCurrent(operation, scope)) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (_isCurrent(operation, scope)) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final material = _material;
    if (_busy || _scope == null || material == null || material.isMetalayzer) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final scope = _scope!;
    final operation = ++_operationId;
    setState(() {
      _busy = _saving = true;
      _error = null;
    });
    try {
      final result =
          await MobileApi.instance.metalayzerComplete(material.barcode);
      if (_isCurrent(operation, scope)) setState(() => _material = result);
    } catch (error) {
      if (_isCurrent(operation, scope)) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (_isCurrent(operation, scope)) {
        setState(() => _busy = _saving = false);
      }
    }
  }

  String _message(Object error) => switch (error) {
        MobileApiException() => error.message,
        FormatException() =>
          'Xomashyo ma’lumotlari tasdiqlanmadi. Qayta tekshiring.',
        StateError() =>
          'Akkaunt yoki ruxsatlar o‘zgardi. Sahifani qayta oching.',
        _ =>
          'Serverga ulanib bo‘lmadi. Internet aloqasini tekshirib, qayta urinib ko‘ring.',
      };

  @override
  Widget build(BuildContext context) {
    final material = _material;
    final enabled = !_busy && _scope != null;
    final scanNext = material?.isMetalayzer == true;
    final scanLabel =
        scanNext ? 'Keyingi xomashyoni skan qilish' : 'Xomashyoni skan qilish';
    final scheme = Theme.of(context).colorScheme;
    return AppShell(
      title: 'Metalayzer',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      contentPadding: EdgeInsets.zero,
      appBarBottomLoading: _busy,
      drawer: const MetalayzerDrawer(),
      bottom: const MetalayzerDock(),
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        children: [
          Text('Xomashyoni skan qiling yoki QR kodini kiriting.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (material == null || scanNext)
            FilledButton.icon(
              onPressed: enabled ? () => _lookup(scan: true) : null,
              style: appFilledActionButtonStyle(),
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(scanLabel),
            )
          else
            OutlinedButton.icon(
              onPressed: enabled ? () => _lookup(scan: true) : null,
              style: appOutlinedActionButtonStyle(),
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(scanLabel),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _barcode,
            enabled: enabled,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            enableSuggestions: false,
            decoration: appSurfaceInputDecoration(
              context,
              labelText: 'Xomashyo QR kodi',
              suffixIcon: IconButton(
                tooltip: 'Tekshirish',
                onPressed: enabled ? _lookup : null,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ).copyWith(errorText: _inputError),
            onChanged: (_) => setState(() {
              _material = null;
              _error = _inputError = null;
            }),
            onSubmitted: (_) => _lookup(),
          ),
          if (_error != null || _scope == null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(_error ?? 'Metalayzer akkaunti bilan kiring.',
                  style: TextStyle(color: scheme.error)),
            ),
          ],
          if (material != null) ...[
            const SizedBox(height: 20),
            AppSegmentSurfaceCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        material.itemName.isEmpty
                            ? material.itemCode
                            : material.itemName,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Semantics(
                        liveRegion: true,
                        child: AppStatusChip(
                          label: material.isMetalayzer
                              ? 'Metalayzer bo‘ldi'
                              : 'Metalayzer bo‘lmagan',
                        )),
                    const SizedBox(height: 12),
                    AppInfoRow(
                        label: 'QR kod',
                        value: material.barcode,
                        selectable: true),
                    AppInfoRow(label: 'Ombor', value: material.warehouse),
                    AppInfoRow(
                        label: 'Miqdor',
                        value: formatQuantityWithUnit(
                            material.qty, material.uom,
                            decimalPlaces: 6, trimTrailingZeros: true)),
                  ]),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: enabled && !material.isMetalayzer ? _complete : null,
              style: appFilledActionButtonStyle(),
              icon: _saving
                  ? const AppLoadingIndicator(size: 24, glyphSize: 18)
                  : Icon(material.isMetalayzer
                      ? Icons.check_circle
                      : Icons.check_circle_outline),
              label: const Text('Metalayzer bo‘ldi'),
            ),
          ],
        ],
      ),
    );
  }
}
