import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/display/app_info_row.dart';
import '../../../core/widgets/forms/app_input_decoration.dart';
import '../../../core/widgets/lists/app_segment_surface_card.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import 'waste_bin_details.dart';
import 'waste_navigation.dart';

const wasteNoWarehouseMessage =
    'Chiqindi ombori biriktirilmagan. Administrator sizga ombor biriktirishi kerak.';

class WasteWarehousesScreen extends StatefulWidget {
  const WasteWarehousesScreen({super.key});

  @override
  State<WasteWarehousesScreen> createState() => _WasteWarehousesScreenState();
}

class _WasteWarehousesScreenState extends State<WasteWarehousesScreen> {
  Future<List<WasteWarehouse>>? _warehouses;
  bool _wasCurrent = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isCurrent = ModalRoute.isCurrentOf(context) ?? true;
    if (_warehouses == null || (isCurrent && !_wasCurrent)) {
      _warehouses = MobileApi.instance.wasteWarehouses();
    }
    _wasCurrent = isCurrent;
  }

  Future<void> _refresh() async {
    final request = MobileApi.instance.wasteWarehouses();
    setState(() => _warehouses = request);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<WasteWarehouse>>(
        future: _warehouses,
        builder: (context, snapshot) {
          final waiting = snapshot.connectionState != ConnectionState.done;
          final warehouses = snapshot.data;
          return AppShell(
            title: 'Chiqindi omborlari',
            subtitle: '',
            nativeTopBar: true,
            nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
            drawer: const WasteDrawer(activeTab: WasteDockTab.warehouses),
            bottom: const WasteDock(activeTab: WasteDockTab.warehouses),
            appBarBottomLoading: waiting,
            actions: [
              IconButton(
                tooltip: 'Yangilash',
                onPressed: waiting ? null : _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
            child: snapshot.hasError
                ? AppRetryState(
                    onRetry: _refresh,
                    message: wasteErrorText(snapshot.error!),
                  )
                : warehouses == null
                    ? const Center(child: AppLoadingIndicator())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(2, 8, 0, 16),
                        children: [
                          if (warehouses.isEmpty)
                            const AppSegmentSurfaceCard(
                              child: Text(wasteNoWarehouseMessage),
                            ),
                          for (final warehouse in warehouses) ...[
                            AppSegmentSurfaceCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(warehouse.warehouse,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 8),
                                  AppInfoRow(
                                    label: 'Qoldiq',
                                    value: wasteKgLabel(warehouse.onHandKg),
                                  ),
                                  AppInfoRow(
                                    label: 'Qabullar',
                                    value: warehouse.receiptCount.toString(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
          );
        },
      );
}

class WasteWarehouseField extends StatelessWidget {
  const WasteWarehouseField({
    super.key,
    required this.warehouses,
    required this.selectedId,
    required this.onChanged,
  });

  final List<WasteWarehouse> warehouses;
  final String? selectedId;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: selectedId,
        isExpanded: true,
        decoration: appSurfaceInputDecoration(
          context,
          labelText: 'Qabul ombori',
          prefixIcon: const Icon(Icons.warehouse_outlined),
        ),
        items: [
          for (final warehouse in warehouses)
            DropdownMenuItem(
              value: warehouse.id,
              child: Text(warehouse.warehouse, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      );
}
