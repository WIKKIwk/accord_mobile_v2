import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/app_preview.dart';
import '../../../core/customer/customer_priority.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/hub/refresh_hub.dart';
import '../../../core/notifications/store/werka_runtime_store.dart';
import '../../../core/search/search_activity_store.dart';
import '../../../core/search/search_normalizer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/navigation/native_back_button.dart';
import '../../shared/models/app_models.dart';
import 'dart:math';
import 'widgets/m3_picker_sheet.dart';
import 'widgets/werka_dock.dart';
import 'package:full_screen_back_gesture/cupertino.dart'
    as fullscreen_cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

part 'werka_batch_dispatch_screen__WerkaBatchDispatchScreenState_methods_01.dart';
part 'werka_batch_dispatch_screen_helpers_part_01.dart';
part 'werka_batch_dispatch_screen_widgets_part_02.dart';

class _WerkaBatchDispatchScreenState extends State<WerkaBatchDispatchScreen> {
  final TextEditingController _qtyController = TextEditingController();
  final List<_WerkaBatchDraftLine> _drafts = <_WerkaBatchDraftLine>[];
  final bool _previewMode = AppPreview.batchDispatchDemo;

  CustomerDirectoryEntry? _selectedCustomer;
  SupplierItem? _selectedItem;

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  double get _currentQty => double.tryParse(_qtyController.text.trim()) ?? 0;

  bool get _hasCurrentValidLine =>
      _selectedCustomer != null && _selectedItem != null && _currentQty > 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasSavedLines = _drafts.isNotEmpty;
    final pickerButtonStyle = FilledButton.styleFrom(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      disabledBackgroundColor: scheme.surfaceContainerLow,
      disabledForegroundColor: scheme.onSurfaceVariant,
      elevation: 0,
      minimumSize: const Size.fromHeight(58),
      alignment: Alignment.centerLeft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
    final qtyInputDecoration = InputDecoration(
      hintText: '0',
      suffixText: _selectedItem?.uom,
      filled: true,
      fillColor: scheme.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );

    return AppShell(
      title: l10n.batchDispatchTitle,
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
                l10n.batchDispatchTitle,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              if (_previewMode) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Preview mode',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
              if (hasSavedLines) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        l10n.batchDraftCountLabel(_drafts.length),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Tooltip(
                      message: l10n.batchViewListAction,
                      child: IconButton.filledTonal(
                        onPressed: _openReview,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(40, 40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.list_alt_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Text(l10n.itemLabel, style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      style: pickerButtonStyle,
                      onPressed: _pickItem,
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
                      onPressed: _clearSelectedItem,
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
                      onPressed: _pickCustomer,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedCustomer?.name ?? l10n.selectCustomer,
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
                  if (_selectedCustomer != null) ...[
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Clear customer',
                      onPressed: _clearSelectedCustomer,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ],
              ),
              if (_selectedCustomer != null &&
                  _selectedItem == null &&
                  _selectedCustomer!.phone.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
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
                  onChanged: (_) => setState(() {}),
                  decoration: qtyInputDecoration,
                ),
              ],
              const SizedBox(height: 18),
              if (!hasSavedLines)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _hasCurrentValidLine ? _saveCurrentLine : null,
                    child: Text(l10n.nextItemAction),
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _hasCurrentValidLine ? _saveCurrentLine : null,
                        child: Text(l10n.addAnotherAction),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _hasCurrentValidLine
                            ? () => _openReview(saveCurrentLine: true)
                            : _drafts.length >= 2
                                ? () => _openReview()
                                : null,
                        child: Text(l10n.confirmTitle),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

const List<CustomerDirectoryEntry> _previewCustomers = [
  CustomerDirectoryEntry(
    ref: 'CUST-001',
    name: 'Aziz Market',
    phone: '+998901111111',
  ),
  CustomerDirectoryEntry(
    ref: 'CUST-002',
    name: 'Sardor Do\'kon',
    phone: '+998902222222',
  ),
  CustomerDirectoryEntry(
    ref: 'CUST-003',
    name: 'Dilnoza Shop',
    phone: '+998903333333',
  ),
];

const List<CustomerItemOption> _previewOptions = [
  CustomerItemOption(
    customerRef: 'CUST-001',
    customerName: 'Aziz Market',
    customerPhone: '+998901111111',
    itemCode: 'ITEM-001',
    itemName: 'Un 5kg',
    uom: 'Qop',
    warehouse: 'Stores - CH',
  ),
  CustomerItemOption(
    customerRef: 'CUST-001',
    customerName: 'Aziz Market',
    customerPhone: '+998901111111',
    itemCode: 'ITEM-002',
    itemName: 'Yog\' 1L',
    uom: 'Dona',
    warehouse: 'Stores - CH',
  ),
  CustomerItemOption(
    customerRef: 'CUST-002',
    customerName: 'Sardor Do\'kon',
    customerPhone: '+998902222222',
    itemCode: 'ITEM-003',
    itemName: 'Shakar 5kg',
    uom: 'Qop',
    warehouse: 'Stores - CH',
  ),
  CustomerItemOption(
    customerRef: 'CUST-003',
    customerName: 'Dilnoza Shop',
    customerPhone: '+998903333333',
    itemCode: 'ITEM-004',
    itemName: 'Guruch 1kg',
    uom: 'Dona',
    warehouse: 'Stores - CH',
  ),
  CustomerItemOption(
    customerRef: 'CUST-003',
    customerName: 'Dilnoza Shop',
    customerPhone: '+998903333333',
    itemCode: 'ITEM-005',
    itemName: 'Makaron',
    uom: 'Dona',
    warehouse: 'Stores - CH',
  ),
];
