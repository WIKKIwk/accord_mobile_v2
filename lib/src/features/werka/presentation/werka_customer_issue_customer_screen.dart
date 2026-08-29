import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/customer/customer_priority.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/hub/refresh_hub.dart';
import '../../../core/notifications/store/werka_runtime_store.dart';
import '../../../core/search/search_activity_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/navigation/native_back_button.dart';
import '../../shared/models/app_models.dart';
import 'werka_customer_issue_prefill.dart';
import 'werka_success_screen.dart';
import 'widgets/m3_picker_sheet.dart';
import 'widgets/werka_dock.dart';

import 'package:flutter/material.dart';

part 'werka_customer_issue_customer_screen__WerkaCustomerIssueCustomerScreenState_methods_01.dart';
part 'werka_customer_issue_customer_screen_widgets_part_01.dart';

class _WerkaCustomerIssueCustomerScreenState
    extends State<WerkaCustomerIssueCustomerScreen> {
  final TextEditingController _qtyController = TextEditingController(text: '1');

  CustomerDirectoryEntry? _selectedCustomer;
  SupplierItem? _selectedItem;
  bool _submitting = false;
  bool _qrPrefillActive = false;
  bool _prefillCustomerLoading = false;
  int _prefillCustomerGeneration = 0;

  @override
  void initState() {
    super.initState();
    if (widget.prefill != null) {
      final prefill = widget.prefill!;
      _qrPrefillActive = prefill.hasSource;
      if (prefill.hasCustomer) {
        _selectedCustomer = CustomerDirectoryEntry(
          ref: prefill.customerRef,
          name: prefill.customerName,
          phone: '',
        );
      }
      _selectedItem = SupplierItem(
        code: prefill.itemCode,
        name: prefill.itemName.trim().isEmpty
            ? prefill.itemCode
            : prefill.itemName,
        uom: prefill.uom,
        warehouse: prefill.warehouse,
      );
      _qtyController.text = _formatQty(prefill.qty);
      if (_selectedCustomer == null) {
        _prefillCustomerLoading = true;
        _loadPreferredCustomerForPrefill();
      }
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canSubmit =
        _selectedCustomer != null && _selectedItem != null && !_submitting;
    final customerLabel = _selectedCustomer?.name ??
        (_prefillCustomerLoading
            ? 'Customer tanlanmoqda...'
            : l10n.selectCustomer);
    final source = widget.prefill;
    final pickerButtonStyle = FilledButton.styleFrom(
      backgroundColor: scheme.surfaceContainerHighest,
      foregroundColor: scheme.onSurface,
      disabledBackgroundColor: scheme.surfaceContainerLow,
      disabledForegroundColor: scheme.onSurfaceVariant,
      elevation: 0,
      minimumSize: const Size.fromHeight(58),
      alignment: Alignment.centerLeft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 18),
    );
    final qtyInputDecoration = InputDecoration(
      hintText: '0',
      suffixText: _selectedItem?.uom,
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide.none,
      ),
    );

    return AppShell(
      title: l10n.customerIssueTitle,
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      leading: NativeBackButtonSlot(
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      bottom: const WerkaDock(activeTab: null),
      contentPadding: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.customerIssueTitle,
                style: theme.textTheme.headlineMedium,
              ),
              if (_qrPrefillActive && source != null && source.hasSource) ...[
                const SizedBox(height: 12),
                _QrPrefillBanner(prefill: source),
              ],
              const SizedBox(height: 18),
              Text(l10n.itemLabel, style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      style: pickerButtonStyle,
                      onPressed: _submitting ? null : _pickItem,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedItem?.name ?? l10n.selectItem,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedItem != null) ...[
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Clear item',
                      onPressed: _submitting ? null : _clearSelectedItem,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Text(l10n.customerLabel, style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      style: pickerButtonStyle,
                      onPressed: _submitting ? null : _pickCustomer,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              customerLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_prefillCustomerLoading)
                            const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedCustomer != null) ...[
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Clear customer',
                      onPressed: _submitting ? null : _clearSelectedCustomer,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ],
              ),
              if (_selectedCustomer != null &&
                  _selectedItem == null &&
                  _selectedCustomer!.phone.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  _selectedCustomer!.phone,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (_selectedItem != null) ...[
                const SizedBox(height: 14),
                Text(l10n.amountLabel, style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
                TextField(
                  controller: _qtyController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: qtyInputDecoration,
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canSubmit ? _submit : null,
                  child: Text(_submitting ? l10n.pinSaving : l10n.confirmTitle),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
