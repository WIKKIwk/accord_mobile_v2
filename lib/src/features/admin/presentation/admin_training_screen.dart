import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/native_usb_printer.dart';
import '../../../core/print_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../admin/logic/production_map_pechat_rules.dart';
import '../../admin/models/production_map_models.dart';
import '../../shared/models/app_models.dart';
import 'progress_printer_picker.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_shell.dart';
import 'widgets/admin_top_notice.dart';

int _trainingBarcodeSequence = 0;
const double _adminTrainingPanelGap = 4;

class AdminTrainingScreen extends StatefulWidget {
  const AdminTrainingScreen({super.key});

  @override
  State<AdminTrainingScreen> createState() => _AdminTrainingScreenState();
}

class _AdminTrainingScreenState extends State<AdminTrainingScreen> {
  List<AdminApparatus> _apparatus = const [];
  List<CalculateMaterial> _materials = const [];
  List<ProductionMapSaved> _orders = const [];
  List<AdminRawMaterialAssignment> _assignments = const [];
  bool _loading = true;
  String? _error;
  String? _savingId;
  String? _linkingId;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<Object>([
        MobileApi.instance.adminApparatus(limit: 10000),
        MobileApi.instance.calculateMaterials(),
        MobileApi.instance.adminProductionMaps(),
        MobileApi.instance.adminRawMaterialAssignments(),
      ]);
      if (!mounted) {
        return;
      }
      final apparatus = [...results[0] as List<AdminApparatus>]..sort(
          (left, right) => left.name.toLowerCase().compareTo(
                right.name.toLowerCase(),
              ),
        );
      final materials = [...results[1] as List<CalculateMaterial>]..sort(
          (left, right) => left.name.toLowerCase().compareTo(
                right.name.toLowerCase(),
              ),
        );
      final orders = (results[2] as List<ProductionMapSaved>)
          .where(
            (order) =>
                order.map.id.trim().startsWith('zakaz-') ||
                order.map.orderNumber.trim().isNotEmpty,
          )
          .toList()
        ..sort(
          (left, right) => _trainingOrderLabel(left).toLowerCase().compareTo(
                _trainingOrderLabel(right).toLowerCase(),
              ),
        );
      setState(() {
        _apparatus = apparatus;
        _materials = materials;
        _orders = orders;
        _assignments = [
          ...results[3] as List<AdminRawMaterialAssignment>,
        ];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Training ma’lumotlari yuklanmadi';
      });
    }
  }

  Future<void> _setTrainingEnabled(
    AdminApparatus apparatus,
    bool enabled,
  ) async {
    if (_savingId != null) {
      return;
    }
    setState(() => _savingId = apparatus.id);
    try {
      final saved = await MobileApi.instance.adminCreateApparatus(
        apparatus.name,
        id: apparatus.id,
        family: apparatus.family,
        kind: apparatus.kind,
        capabilities: apparatus.capabilities,
        capabilityProfiles: apparatus.capabilityProfiles,
        colorStations: apparatus.colorStations,
        trainingEnabled: enabled,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _apparatus = [
          for (final item in _apparatus)
            if (item.id == saved.id) saved else item,
        ];
      });
      showAdminTopNotice(
        context,
        enabled ? 'Training rejimi yoqildi' : 'Training rejimi o‘chirildi',
      );
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, 'Training rejimi saqlanmadi');
      }
    } finally {
      if (mounted) {
        setState(() => _savingId = null);
      }
    }
  }

  Future<void> _linkMaterial(AdminApparatus apparatus) async {
    if (_linkingId != null) {
      return;
    }
    setState(() => _linkingId = apparatus.id);
    try {
      final draft = await showModalBottomSheet<_TrainingMaterialLinkDraft>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => _TrainingMaterialLinkSheet(
          apparatus: apparatus,
          materials: [
            for (final material in _materials)
              if (material.active && material.name.trim().isNotEmpty) material,
          ],
          orders: _orders,
        ),
      );
      if (draft == null || !mounted) {
        return;
      }
      final printer = await pickProgressPrinter(context);
      if (!mounted) {
        return;
      }
      if (printer == null) {
        showAdminTopNotice(context, 'Printer tanlanmadi');
        return;
      }
      final barcode = _nextTrainingBarcode();
      final itemCode = draft.material.id.trim().isEmpty
          ? 'TRAINING-MATERIAL'
          : draft.material.id.trim();
      final itemName = '${draft.material.name.trim()} / ${draft.micron} mikron';
      final request = UsbRpsPrintRequest(
        epc: barcode,
        itemCode: itemCode,
        itemName: itemName,
        apparatus: apparatus.name,
        warehouse: 'Training: ${apparatus.name}',
        printer: printer.printer.trim().isEmpty ? 'godex' : printer.printer,
        printMode:
            printer.printMode.trim().isEmpty ? 'label' : printer.printMode,
        grossQty: 1,
        unit: 'kg',
        labelKind: 'material_product',
      );
      await _printTrainingLabel(printer, request);
      final assignment = await MobileApi.instance.adminLinkTrainingRawMaterial(
        orderId: draft.order.map.id,
        apparatus: apparatus.name,
        materialId: draft.material.id,
        materialName: draft.material.name,
        micron: draft.micron,
        barcode: barcode,
      );
      if (!mounted) {
        return;
      }
      setState(() => _assignments = [..._assignments, assignment]);
      showAdminTopNotice(
        context,
        'QR chop etildi va ${apparatus.name} oldidagi orderga ulandi',
        icon: Icons.link_rounded,
      );
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? error.message
              : 'Training homashyosi ulanmagan yoki chop etilmadi',
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _linkingId = null);
      }
    }
  }

  Future<void> _printTrainingLabel(
    ProgressPrinterOption printer,
    UsbRpsPrintRequest request,
  ) async {
    if (printer.transport.isLocal) {
      final result = await PrintService.printRps(
        request,
        printerProfile: printer.offlinePrinter,
        bluetoothPrinter: printer.bluetoothPrinter,
        transport: printer.transport,
      );
      if (!result.ok) {
        throw StateError('Printer training QR kodini chop etmadi');
      }
      return;
    }
    final server = printer.server;
    if (server == null) {
      throw StateError('Printer serveri topilmadi');
    }
    final response = await http
        .post(
          Uri.parse('${server.endpoint.baseUrl}/v1/mobile/driver/print'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(request.toJson()),
        )
        .timeout(const Duration(seconds: 15));
    final payload = jsonDecode(response.body);
    final ok = payload is Map && payload['ok'] == true;
    if (response.statusCode < 200 || response.statusCode > 299 || !ok) {
      final detail = payload is Map
          ? (payload['detail'] ?? payload['error'])?.toString().trim() ?? ''
          : '';
      throw StateError(
        detail.isEmpty ? 'Printer training QR kodini chop etmadi' : detail,
      );
    }
  }

  List<AdminRawMaterialAssignment> _assignmentsFor(
    AdminApparatus apparatus,
  ) {
    return [
      for (final assignment in _assignments)
        if (productionMapWarehouseTitlesMatch(
          assignment.apparatus,
          apparatus.name,
        ))
          assignment,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 112;
    return AdminShell(
      title: 'Training',
      selectedRouteName: AppRoutes.adminTraining,
      activeTab: AdminDockTab.home,
      child: ColoredBox(
        color: AppTheme.shellStart(context),
        child: _loading
            ? const Center(child: AppLoadingIndicator())
            : _error != null
                ? AppRetryState(onRetry: _load)
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      _adminTrainingPanelGap,
                      16,
                      _adminTrainingPanelGap,
                      bottomPadding,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .tertiaryContainer
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.school_outlined),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Training apparat bo‘yicha yoqiladi. Aparatni ochib, '
                                  'rejimni almashtiring yoki zanjir orqali test '
                                  'homashyosini orderga ulang.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_apparatus.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('Aparatlar topilmadi')),
                        )
                      else
                        M3SegmentSpacedColumn(
                          children: [
                            for (var index = 0;
                                index < _apparatus.length;
                                index += 1)
                              _TrainingApparatusTile(
                                apparatus: _apparatus[index],
                                assignments: _assignmentsFor(_apparatus[index]),
                                expanded: _expandedId == _apparatus[index].id,
                                saving: _savingId == _apparatus[index].id,
                                linking: _linkingId == _apparatus[index].id,
                                onExpandedChanged: (expanded) {
                                  setState(() {
                                    _expandedId =
                                        expanded ? _apparatus[index].id : null;
                                  });
                                },
                                onTrainingChanged: (enabled) =>
                                    _setTrainingEnabled(
                                  _apparatus[index],
                                  enabled,
                                ),
                                onLinkMaterial: () =>
                                    _linkMaterial(_apparatus[index]),
                                slot: M3SegmentedListGeometry
                                    .standaloneListSlotForIndex(
                                  index,
                                  _apparatus.length,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _TrainingApparatusTile extends StatelessWidget {
  const _TrainingApparatusTile({
    required this.apparatus,
    required this.assignments,
    required this.expanded,
    required this.saving,
    required this.linking,
    required this.onExpandedChanged,
    required this.onTrainingChanged,
    required this.onLinkMaterial,
    required this.slot,
  });

  final AdminApparatus apparatus;
  final List<AdminRawMaterialAssignment> assignments;
  final bool expanded;
  final bool saving;
  final bool linking;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<bool> onTrainingChanged;
  final VoidCallback onLinkMaterial;
  final M3SegmentVerticalSlot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );
    final summary = assignments.isEmpty
        ? (apparatus.trainingEnabled ? 'Training rejimi' : 'Production rejimi')
        : '${apparatus.trainingEnabled ? 'Training rejimi' : 'Production rejimi'} · '
            '${assignments.length} ta test homashyo';
    return Material(
      key: ValueKey('admin-training-apparatus-card-${apparatus.id}'),
      color: scheme.surfaceContainerLowest,
      elevation: 4,
      shadowColor: scheme.shadow.withValues(alpha: 0.24),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onExpandedChanged(!expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: expanded ? 0 : 45),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 30,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.precision_manufacturing_outlined,
                          size: 16,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            apparatus.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: ValueKey(
                        'admin-training-details-${apparatus.id}',
                      ),
                      tooltip: expanded ? 'Yopish' : 'Ochish',
                      onPressed: () => onExpandedChanged(!expanded),
                      icon: AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(58, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.school_outlined, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                apparatus.trainingEnabled
                                    ? 'Training rejimi yoqilgan'
                                    : 'Production rejimi yoqilgan',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (saving)
                              const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              Switch.adaptive(
                                value: apparatus.trainingEnabled,
                                onChanged: onTrainingChanged,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: apparatus.trainingEnabled && !linking
                                ? onLinkMaterial
                                : null,
                            icon: linking
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.link_rounded),
                            label: const Text('Homashyo ulash'),
                          ),
                        ),
                        if (assignments.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          for (final assignment in assignments)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.qr_code_2_rounded,
                                size: 20,
                              ),
                              title: Text(
                                assignment.itemName.isEmpty
                                    ? assignment.barcode
                                    : assignment.itemName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${assignment.barcode} · ${_trainingOrderShortLabel(assignment.orderId)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _TrainingMaterialLinkDraft {
  const _TrainingMaterialLinkDraft({
    required this.material,
    required this.micron,
    required this.order,
  });

  final CalculateMaterial material;
  final int micron;
  final ProductionMapSaved order;
}

class _TrainingMaterialLinkSheet extends StatefulWidget {
  const _TrainingMaterialLinkSheet({
    required this.apparatus,
    required this.materials,
    required this.orders,
  });

  final AdminApparatus apparatus;
  final List<CalculateMaterial> materials;
  final List<ProductionMapSaved> orders;

  @override
  State<_TrainingMaterialLinkSheet> createState() =>
      _TrainingMaterialLinkSheetState();
}

class _TrainingMaterialLinkSheetState
    extends State<_TrainingMaterialLinkSheet> {
  late final TextEditingController _micronController;
  CalculateMaterial? _material;
  ProductionMapSaved? _order;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _micronController = TextEditingController();
    _material = widget.materials.isEmpty ? null : widget.materials.first;
    _order = widget.orders.length == 1 ? widget.orders.first : null;
  }

  @override
  void dispose() {
    _micronController.dispose();
    super.dispose();
  }

  void _submit() {
    final micron = int.tryParse(_micronController.text.trim());
    if (_material == null || _order == null || micron == null || micron <= 0) {
      setState(() {
        _validationMessage = 'Homashyo, order va musbat micronni kiriting';
      });
      return;
    }
    Navigator.of(context).pop(
      _TrainingMaterialLinkDraft(
        material: _material!,
        micron: micron,
        order: _order!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Training homashyosini ulash',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text('Aparat: ${widget.apparatus.name}'),
              const SizedBox(height: 18),
              if (widget.materials.isEmpty)
                const _TrainingSheetNotice(
                  icon: Icons.inventory_2_outlined,
                  text: 'Mikron materiallari sahifasida faol homashyo yo‘q.',
                )
              else
                DropdownButtonFormField<CalculateMaterial>(
                  initialValue: _material,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Homashyo nomi',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  items: [
                    for (final material in widget.materials)
                      DropdownMenuItem<CalculateMaterial>(
                        value: material,
                        child: Text(
                          material.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _material = value),
                ),
              const SizedBox(height: 12),
              if (widget.orders.isEmpty)
                const _TrainingSheetNotice(
                  icon: Icons.receipt_long_outlined,
                  text:
                      'Avval training uchun order oching yoki mavjud orderni tanlang.',
                )
              else
                DropdownButtonFormField<ProductionMapSaved>(
                  initialValue: _order,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Order',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                  items: [
                    for (final order in widget.orders)
                      DropdownMenuItem<ProductionMapSaved>(
                        value: order,
                        child: Text(
                          _trainingOrderLabel(order),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _order = value),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _micronController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Mikron',
                  hintText: 'Masalan, 50',
                  prefixIcon: Icon(Icons.straighten_outlined),
                  suffixText: 'µm',
                ),
              ),
              const SizedBox(height: 12),
              const _TrainingSheetNotice(
                icon: Icons.print_outlined,
                text: 'Chop etilgach, shu QR test orderga va aparat oldidagi '
                    'joylashuvga ulanadi.',
              ),
              if (_validationMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _validationMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed:
                    widget.materials.isNotEmpty && widget.orders.isNotEmpty
                        ? _submit
                        : null,
                icon: const Icon(Icons.print_rounded),
                label: const Text('Mikronni yozib chop etish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainingSheetNotice extends StatelessWidget {
  const _TrainingSheetNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

String _nextTrainingBarcode() {
  _trainingBarcodeSequence += 1;
  return 'TRN-${DateTime.now().toUtc().millisecondsSinceEpoch}-$_trainingBarcodeSequence';
}

String _trainingOrderLabel(ProductionMapSaved saved) {
  final map = saved.map;
  final values = [map.title, map.orderNumber, map.customerName]
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  return values.isEmpty ? map.id : values.join(' · ');
}

String _trainingOrderShortLabel(String orderId) {
  final normalized = orderId.trim();
  if (normalized.length <= 22) {
    return normalized;
  }
  return '${normalized.substring(0, 10)}…${normalized.substring(normalized.length - 8)}';
}
