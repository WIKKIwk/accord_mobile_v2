import 'dart:async';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/search/search_normalizer.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/lists/lists.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_dock.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_navigation_drawer.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../models/production_map_models.dart';
import 'raw_material_scan_dialog.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_summary_card.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';

const double _rawMaterialAssignmentPanelGap = 4;

class AdminRawMaterialAssignmentArgs {
  const AdminRawMaterialAssignmentArgs({required this.initialBarcode});

  final String initialBarcode;
}

class AdminRawMaterialAssignmentScreen extends StatelessWidget {
  const AdminRawMaterialAssignmentScreen({
    super.key,
    this.initialBarcode = '',
  });

  final String initialBarcode;

  @override
  Widget build(BuildContext context) {
    final profile = AppSession.instance.profile;
    final isMaterialTaminotchi = profile?.role == UserRole.materialTaminotchi;
    final hasMaterialGroupScope = !isMaterialTaminotchi ||
        (profile?.assignedItemGroups ?? const <String>[]).isNotEmpty;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 128;
    return AppShell(
      drawer: isMaterialTaminotchi
          ? MaterialTaminotchiNavigationDrawer(
              selectedRouteName: AppRoutes.adminRawMaterialAssignments,
              onNavigate: (routeName) {
                final current = ModalRoute.of(context)?.settings.name;
                if (current == routeName) {
                  return;
                }
                Navigator.of(context).pushReplacementNamed(routeName);
              },
            )
          : AdminNavigationDrawer(
              selectedIndex: 0,
              selectedRouteName: AppRoutes.adminRawMaterialSettings,
              onNavigate: (routeName) =>
                  AdminDrawerNavigation.openRoute(context, routeName),
            ),
      title: isMaterialTaminotchi
          ? 'Homashyo biriktirish'
          : 'Homashyo sozlamalari',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: isMaterialTaminotchi
          ? AppTheme.werkaNativeAppBarTitleStyle(context)
          : null,
      preferNativeTitle: isMaterialTaminotchi,
      bottom: isMaterialTaminotchi
          ? const MaterialTaminotchiDock()
          : const AdminDock(activeTab: AdminDockTab.settings),
      contentPadding: EdgeInsets.zero,
      child: AdminRawMaterialAssignmentPanel(
        bottomPadding: bottomPadding,
        groupScopeReady: hasMaterialGroupScope,
        initialBarcode: initialBarcode,
      ),
    );
  }
}

class AdminRawMaterialAssignmentPanel extends StatefulWidget {
  const AdminRawMaterialAssignmentPanel({
    super.key,
    required this.bottomPadding,
    this.groupScopeReady = true,
    this.initialBarcode = '',
  });

  final double bottomPadding;
  final bool groupScopeReady;
  final String initialBarcode;

  @override
  State<AdminRawMaterialAssignmentPanel> createState() =>
      _AdminRawMaterialAssignmentPanelState();
}

class _AdminRawMaterialAssignmentPanelState
    extends State<AdminRawMaterialAssignmentPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<_RawMaterialAssignmentData> _future;
  List<AdminRawMaterialAssignment> _assignments = const [];
  List<AdminRawMaterialAssignmentCandidate> _manualCandidates = const [];
  String _selectedOrderId = '';
  String _scannedBarcode = '';
  AdminRawMaterialLookup? _scannedMaterial;
  String _scanLookupError = '';
  bool _scanLookupLoading = false;
  bool _saving = false;
  String? _expandedAssignmentKey;
  String _unlinkingAssignmentKey = '';
  String _manualCandidatesOrderId = '';
  String _manualAssigningBarcode = '';
  Object? _manualCandidatesError;
  bool _manualCandidatesLoading = false;
  bool _initialBarcodeHandled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
    _future = widget.groupScopeReady
        ? _load()
        : Future.value(const _RawMaterialAssignmentData.empty());
    _scheduleInitialBarcodeLookup();
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.index == 1 && !_tabController.indexIsChanging) {
      unawaited(_loadManualCandidates());
    }
  }

  @override
  void didUpdateWidget(covariant AdminRawMaterialAssignmentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialBarcode.trim() != widget.initialBarcode.trim()) {
      _initialBarcodeHandled = false;
    }
    if (!oldWidget.groupScopeReady && widget.groupScopeReady) {
      _future = _load();
    }
    _scheduleInitialBarcodeLookup();
  }

  void _scheduleInitialBarcodeLookup() {
    final barcode = widget.initialBarcode.trim();
    if (_initialBarcodeHandled || !widget.groupScopeReady || barcode.isEmpty) {
      return;
    }
    _initialBarcodeHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _lookupScannedBarcode(barcode);
      }
    });
  }

  Future<_RawMaterialAssignmentData> _load() async {
    final results = await Future.wait<Object>([
      MobileApi.instance.adminRawMaterialAssignmentOrders(),
      MobileApi.instance.adminRawMaterialAssignments(),
    ]);
    final orders = results[0] as List<ProductionMapSaved>;
    final assignments = results[1] as List<AdminRawMaterialAssignment>;
    _assignments = assignments;
    if (_selectedOrderId.isEmpty && orders.isNotEmpty) {
      _selectedOrderId = orders.first.map.id.trim();
    }
    return _RawMaterialAssignmentData(
      orders: orders,
      assignments: assignments,
    );
  }

  Future<void> _loadManualCandidates({bool force = false}) async {
    final orderId = _selectedOrderId.trim();
    if (orderId.isEmpty ||
        (_manualCandidatesLoading && _manualCandidatesOrderId == orderId) ||
        (!force &&
            _manualCandidatesOrderId == orderId &&
            _manualCandidatesError == null)) {
      return;
    }
    setState(() {
      _manualCandidatesOrderId = orderId;
      _manualCandidatesLoading = true;
      _manualCandidatesError = null;
      _manualCandidates = const [];
    });
    try {
      final candidates = await MobileApi.instance
          .adminRawMaterialAssignmentCandidates(orderId: orderId);
      if (!mounted || _selectedOrderId.trim() != orderId) {
        return;
      }
      setState(() {
        _manualCandidates = candidates;
        _manualCandidatesError = null;
      });
    } catch (error) {
      if (!mounted || _selectedOrderId.trim() != orderId) {
        return;
      }
      setState(() => _manualCandidatesError = error);
    } finally {
      if (mounted && _selectedOrderId.trim() == orderId) {
        setState(() => _manualCandidatesLoading = false);
      }
    }
  }

  String _selectedOrderLabel(List<ProductionMapSaved> orders) {
    for (final order in orders) {
      if (order.map.id.trim() == _selectedOrderId.trim()) {
        return _orderLabel(order);
      }
    }
    return _selectedOrderId.trim();
  }

  Future<void> _openOrderPicker(List<ProductionMapSaved> orders) async {
    if (_saving || orders.isEmpty) {
      return;
    }
    final picked = await showModalBottomSheet<ProductionMapSaved>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3AsyncPickerSheet<ProductionMapSaved>(
          title: 'Zakaz tanlang',
          hintText: 'Zakaz qidiring',
          pageSize: 50,
          loadPage: (query, offset, limit) async {
            final normalizedQuery = query.trim().toLowerCase();
            final filtered = normalizedQuery.isEmpty
                ? orders
                : orders.where((order) {
                    final map = order.map;
                    return searchMatches(normalizedQuery, [
                      map.id,
                      map.code,
                      map.orderNumber,
                      map.title,
                      map.productCode,
                      _orderLabel(order),
                    ]);
                  }).toList(growable: false);
            return filtered.skip(offset).take(limit).toList(growable: false);
          },
          itemTitle: _orderLabel,
          itemSubtitle: (order) => order.map.id.trim(),
          onSelected: (order) => Navigator.of(context).pop(order),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedOrderId = picked.map.id.trim();
      _manualCandidatesOrderId = '';
      _manualCandidates = const [];
      _manualCandidatesError = null;
    });
    if (_tabController.index == 1) {
      await _loadManualCandidates(force: true);
    }
  }

  Future<void> _scan() async {
    final barcode = await showRawMaterialScanDialog(context);
    if (!mounted || barcode == null || barcode.trim().isEmpty) {
      return;
    }
    await _lookupScannedBarcode(barcode);
  }

  Future<void> _lookupScannedBarcode(String barcode) async {
    final normalized = rawMaterialBarcodeFromQr(barcode);
    if (normalized.isEmpty) {
      return;
    }
    setState(() {
      _scannedBarcode = normalized;
      _scannedMaterial = null;
      _scanLookupError = '';
      _scanLookupLoading = true;
    });
    try {
      final detail = await MobileApi.instance.adminRawMaterialLookup(
        barcode: normalized,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _scannedMaterial = detail;
        _scanLookupError = '';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scanLookupError =
            error is MobileApiException ? error.message : 'Homashyo topilmadi';
      });
    } finally {
      if (mounted) {
        setState(() => _scanLookupLoading = false);
      }
    }
  }

  Future<void> _save() async {
    final orderId = _selectedOrderId.trim();
    final barcode = rawMaterialBarcodeFromQr(_scannedBarcode);
    if (orderId.isEmpty || barcode.isEmpty || _saving) {
      showAdminTopNotice(context, 'Zakaz tanlang va homashyo QR skaner qiling');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await _assignMaterialWithApparatusSelection(
        orderId: orderId,
        barcode: barcode,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _scannedBarcode = '';
        _scannedMaterial = null;
        _scanLookupError = '';
        _assignments = [
          saved,
          for (final item in _assignments)
            if (item.orderId.trim() != saved.orderId.trim() ||
                item.barcode.trim() != saved.barcode.trim())
              item,
        ];
      });
      showAdminTopNotice(context, 'Homashyo zakazga ulandi');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        error is MobileApiException ? error.message : 'Homashyo ulanmadi',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<AdminRawMaterialAssignment> _assignMaterialWithApparatusSelection({
    required String orderId,
    required String barcode,
  }) async {
    try {
      return await MobileApi.instance.adminAssignRawMaterialToOrder(
        orderId: orderId,
        barcode: barcode,
      );
    } on MobileApiException catch (error) {
      if (error.code != 'raw_material_group_ambiguous' ||
          error.apparatusOptions.isEmpty ||
          !mounted) {
        rethrow;
      }
      final apparatus = await _showApparatusChoice(error.apparatusOptions);
      if (apparatus == null || !mounted) {
        throw const MobileApiException(
          code: 'raw_material_assignment_cancelled',
          message: 'Homashyoni ulash bekor qilindi',
        );
      }
      return MobileApi.instance.adminAssignRawMaterialToOrder(
        orderId: orderId,
        barcode: barcode,
        apparatus: apparatus,
      );
    }
  }

  Future<String?> _showApparatusChoice(List<String> options) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final scheme = theme.colorScheme;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          backgroundColor: Colors.transparent,
          child: Card.filled(
            margin: EdgeInsets.zero,
            color: scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Icons.account_tree_rounded,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Qaysi aparatga ulaymiz?',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Bu homashyo bir nechta bosqichga mos keladi. Bittasini tanlang.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  for (final option in options) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(option),
                        icon:
                            const Icon(Icons.precision_manufacturing_outlined),
                        label: Text(option),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Bekor qilish'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openManualCandidate(
    AdminRawMaterialAssignmentCandidate candidate,
  ) async {
    if (_manualAssigningBarcode.isNotEmpty || _saving) {
      return;
    }
    final shouldAssign = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (sheetContext) => _ManualCandidateDetailsSheet(
        candidate: candidate,
        onAssign: () => Navigator.of(sheetContext).pop(true),
      ),
    );
    if (shouldAssign != true || !mounted) {
      return;
    }
    setState(() => _manualAssigningBarcode = candidate.barcode.trim());
    try {
      final apparatusOptions = candidate.apparatusOptions;
      String apparatus;
      if (apparatusOptions.length == 1) {
        apparatus = apparatusOptions.single;
      } else {
        final selected = await _showApparatusChoice(apparatusOptions);
        if (selected == null || !mounted) {
          return;
        }
        apparatus = selected;
      }
      final saved = await MobileApi.instance.adminAssignRawMaterialToOrder(
        orderId: _selectedOrderId,
        barcode: candidate.barcode,
        apparatus: apparatus,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _manualCandidates = [
          for (final item in _manualCandidates)
            if (item.barcode.trim().toUpperCase() !=
                candidate.barcode.trim().toUpperCase())
              item,
        ];
        _assignments = [
          saved,
          for (final item in _assignments)
            if (_assignmentKey(item) != _assignmentKey(saved)) item,
        ];
      });
      showAdminTopNotice(context, 'Homashyo zakazga ulandi');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        error is MobileApiException ? error.message : 'Homashyo ulanmadi',
      );
      await _loadManualCandidates(force: true);
    } finally {
      if (mounted) {
        setState(() => _manualAssigningBarcode = '');
      }
    }
  }

  Future<void> _openManualAssignment(
    AdminRawMaterialAssignment assignment,
  ) async {
    final shouldUnlink = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (sheetContext) => _ManualAssignmentDetailsSheet(
        assignment: assignment,
        unlinking: _unlinkingAssignmentKey == _assignmentKey(assignment),
        onUnlink: () => Navigator.of(sheetContext).pop(true),
      ),
    );
    if (shouldUnlink == true && mounted) {
      await _unlink(assignment);
    }
  }

  Future<void> _unlink(AdminRawMaterialAssignment assignment) async {
    final key = _assignmentKey(assignment);
    if (_saving || _unlinkingAssignmentKey.isNotEmpty) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Homashyoni uzish'),
          content: const Text('Bu homashyoni zakazdan uzasizmi?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Uzish'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _unlinkingAssignmentKey = key);
    try {
      await MobileApi.instance.adminUnlinkRawMaterialAssignment(
        orderId: assignment.orderId,
        barcode: assignment.barcode,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _assignments = [
          for (final item in _assignments)
            if (_assignmentKey(item) != key) item,
        ];
        if (_expandedAssignmentKey == key) {
          _expandedAssignmentKey = null;
        }
      });
      showAdminTopNotice(context, 'Homashyo zakazdan uzildi');
      if (_manualCandidatesOrderId == assignment.orderId.trim()) {
        await _loadManualCandidates(force: true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        error is MobileApiException ? error.message : 'Homashyo uzilmadi',
      );
    } finally {
      if (mounted) {
        setState(() => _unlinkingAssignmentKey = '');
      }
    }
  }

  Widget _buildQrTab(_RawMaterialAssignmentData data) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        _rawMaterialAssignmentPanelGap,
        10,
        _rawMaterialAssignmentPanelGap,
        widget.bottomPadding,
      ),
      children: [
        _AssignmentEditor(
          orders: data.orders,
          selectedOrderLabel: _selectedOrderLabel(data.orders),
          scannedBarcode: _scannedBarcode,
          scannedMaterial: _scannedMaterial,
          scanLookupError: _scanLookupError,
          scanLookupLoading: _scanLookupLoading,
          saving: _saving,
          onPickOrder: () => _openOrderPicker(data.orders),
          onScan: _scan,
          onSave: _save,
        ),
        if (_assignments.isEmpty) ...[
          const SizedBox(height: 10),
          const Center(
            child: Text('Ulangan homashyo topilmadi'),
          ),
        ] else ...[
          const SizedBox(height: 10),
          M3SegmentSpacedColumn(
            padding: EdgeInsets.zero,
            children: [
              for (var index = 0; index < _assignments.length; index++)
                _AssignmentTile(
                  slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                    index,
                    _assignments.length,
                  ),
                  assignment: _assignments[index],
                  expanded: _expandedAssignmentKey ==
                      _assignmentKey(_assignments[index]),
                  unlinking: _unlinkingAssignmentKey ==
                      _assignmentKey(_assignments[index]),
                  onExpandedChanged: (expanded) {
                    setState(() {
                      _expandedAssignmentKey =
                          expanded ? _assignmentKey(_assignments[index]) : null;
                    });
                  },
                  onUnlink: () => _unlink(_assignments[index]),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildManualTab(_RawMaterialAssignmentData data) {
    final linked = _assignments
        .where(
          (assignment) => assignment.orderId.trim() == _selectedOrderId.trim(),
        )
        .toList(growable: false);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        _rawMaterialAssignmentPanelGap,
        10,
        _rawMaterialAssignmentPanelGap,
        widget.bottomPadding,
      ),
      children: [
        AppSegmentSurfaceCard(
          child: _AssignmentOrderPicker(
            orders: data.orders,
            selectedOrderLabel: _selectedOrderLabel(data.orders),
            disabled: _saving || _manualAssigningBarcode.isNotEmpty,
            onPickOrder: () => _openOrderPicker(data.orders),
          ),
        ),
        const _ManualListSectionTitle(title: 'Ulanmagan'),
        if (_manualCandidatesLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: AppLoadingIndicator()),
          )
        else if (_manualCandidatesError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            child: Column(
              children: [
                const Text(
                  'Mos homashyolar yuklanmadi',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _loadManualCandidates(force: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Qayta urinish'),
                ),
              ],
            ),
          )
        else if (_manualCandidates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            child: Text(
              'Bu zakazga ulash mumkin bo‘lgan homashyo topilmadi',
              textAlign: TextAlign.center,
            ),
          )
        else
          M3SegmentSpacedColumn(
            padding: EdgeInsets.zero,
            children: [
              for (var index = 0; index < _manualCandidates.length; index++)
                _ManualCandidateListRow(
                  slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                    index,
                    _manualCandidates.length,
                  ),
                  candidate: _manualCandidates[index],
                  busy: _manualAssigningBarcode.trim().toUpperCase() ==
                      _manualCandidates[index].barcode.trim().toUpperCase(),
                  onTap: () => _openManualCandidate(_manualCandidates[index]),
                ),
            ],
          ),
        const _ManualListSectionTitle(title: 'Ulangan'),
        if (linked.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            child: Text(
              'Bu zakazga hali homashyo ulanmagan',
              textAlign: TextAlign.center,
            ),
          )
        else
          M3SegmentSpacedColumn(
            padding: EdgeInsets.zero,
            children: [
              for (var index = 0; index < linked.length; index++)
                _ManualAssignmentListRow(
                  slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                    index,
                    linked.length,
                  ),
                  assignment: linked[index],
                  busy:
                      _unlinkingAssignmentKey == _assignmentKey(linked[index]),
                  onTap: () => _openManualAssignment(linked[index]),
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.groupScopeReady) {
      return _MaterialGroupScopeMissingState(
        bottomPadding: widget.bottomPadding,
      );
    }
    return FutureBuilder<_RawMaterialAssignmentData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: AppLoadingIndicator());
        }
        if (snapshot.hasError) {
          return AppRetryState(
            onRetry: () async {
              setState(() => _future = _load());
            },
          );
        }
        final data = snapshot.data!;
        return ColoredBox(
          color: AppTheme.shellStart(context),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'QR orqali'),
                  Tab(text: 'Ro‘yxatdan'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQrTab(data),
                    _buildManualTab(data),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RawMaterialAssignmentData {
  const _RawMaterialAssignmentData({
    required this.orders,
    required this.assignments,
  });

  const _RawMaterialAssignmentData.empty()
      : orders = const [],
        assignments = const [];

  final List<ProductionMapSaved> orders;
  final List<AdminRawMaterialAssignment> assignments;
}

class _MaterialGroupScopeMissingState extends StatelessWidget {
  const _MaterialGroupScopeMissingState({required this.bottomPadding});

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ColoredBox(
      color: AppTheme.shellStart(context),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          _rawMaterialAssignmentPanelGap,
          10,
          _rawMaterialAssignmentPanelGap,
          bottomPadding,
        ),
        children: [
          AppSegmentSurfaceCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mahsulot guruhi biriktirilmagan',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Homashyo qabul qilish va zakazga ulash uchun admin avval material guruhini biriktirishi kerak.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentOrderPicker extends StatelessWidget {
  const _AssignmentOrderPicker({
    required this.orders,
    required this.selectedOrderLabel,
    required this.disabled,
    required this.onPickOrder,
  });

  final List<ProductionMapSaved> orders;
  final String selectedOrderLabel;
  final bool disabled;
  final VoidCallback onPickOrder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled || orders.isEmpty ? null : onPickOrder,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: appSurfaceInputDecoration(
          context,
          labelText: 'Zakaz',
        ).copyWith(
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
        ),
        isEmpty: selectedOrderLabel.trim().isEmpty,
        child: Text(
          selectedOrderLabel.trim().isEmpty
              ? (orders.isEmpty ? 'Zakaz topilmadi' : 'Tanlang')
              : selectedOrderLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _AssignmentEditor extends StatelessWidget {
  const _AssignmentEditor({
    required this.orders,
    required this.selectedOrderLabel,
    required this.scannedBarcode,
    required this.scannedMaterial,
    required this.scanLookupError,
    required this.scanLookupLoading,
    required this.saving,
    required this.onPickOrder,
    required this.onScan,
    required this.onSave,
  });

  final List<ProductionMapSaved> orders;
  final String selectedOrderLabel;
  final String scannedBarcode;
  final AdminRawMaterialLookup? scannedMaterial;
  final String scanLookupError;
  final bool scanLookupLoading;
  final bool saving;
  final VoidCallback onPickOrder;
  final VoidCallback onScan;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return AppSegmentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AssignmentOrderPicker(
            orders: orders,
            selectedOrderLabel: selectedOrderLabel,
            disabled: saving,
            onPickOrder: onPickOrder,
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: saving ? null : onScan,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('QR skanerlash'),
          ),
          if (scannedBarcode.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _ScannedRawMaterialCard(
              barcode: scannedBarcode,
              detail: scannedMaterial,
              loading: scanLookupLoading,
              error: scanLookupError,
            ),
          ],
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link_rounded),
            label: const Text('Ulash'),
          ),
        ],
      ),
    );
  }
}

class _ManualListSectionTitle extends StatelessWidget {
  const _ManualListSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ManualCandidateListRow extends StatelessWidget {
  const _ManualCandidateListRow({
    required this.slot,
    required this.candidate,
    required this.busy,
    required this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final AdminRawMaterialAssignmentCandidate candidate;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = candidate.itemName.trim().isEmpty
        ? candidate.itemCode
        : candidate.itemName;
    final subtitle = [
      candidate.barcode.trim(),
      _formatQty(candidate.qty, candidate.uom),
      candidate.warehouse.trim(),
    ].where((item) => item.isNotEmpty).join(' • ');
    return AdminSummaryCard(
      key: ValueKey('raw-material-candidate-${candidate.barcode}'),
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      onTap: busy ? null : onTap,
      backgroundColor: scheme.surfaceContainerLowest,
      fixedHeight: 61,
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      value: '',
      showChevron: false,
      leading: SizedBox.square(
        dimension: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.inventory_2_outlined,
            size: 16,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
      trailing: busy
          ? const AppLoadingIndicator(size: 30, glyphSize: 18)
          : Icon(Icons.add_link_rounded, color: scheme.primary),
      title: title,
      subtitle: subtitle,
      titleMaxLines: 1,
      subtitleMaxLines: 1,
      titleStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
      subtitleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.05,
          ),
      elevation: 1,
    );
  }
}

class _ManualAssignmentListRow extends StatelessWidget {
  const _ManualAssignmentListRow({
    required this.slot,
    required this.assignment,
    required this.busy,
    required this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final AdminRawMaterialAssignment assignment;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = assignment.itemName.trim().isEmpty
        ? assignment.itemCode
        : assignment.itemName;
    final subtitle = [
      assignment.barcode.trim(),
      if (assignment.stockQty > 0)
        _formatQty(assignment.stockQty, assignment.stockUom),
      assignment.stockWarehouse.trim(),
    ].where((item) => item.isNotEmpty).join(' • ');
    return AdminSummaryCard(
      key: ValueKey('manual-raw-material-${_assignmentKey(assignment)}'),
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      onTap: busy ? null : onTap,
      backgroundColor: scheme.surfaceContainerLowest,
      fixedHeight: 61,
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      value: '',
      showChevron: false,
      leading: SizedBox.square(
        dimension: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.link_rounded,
            size: 16,
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
      trailing: busy
          ? const AppLoadingIndicator(size: 30, glyphSize: 18)
          : Icon(Icons.link_rounded, color: scheme.primary),
      title: title,
      subtitle: subtitle,
      titleMaxLines: 1,
      subtitleMaxLines: 1,
      titleStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
      subtitleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.05,
          ),
      elevation: 1,
    );
  }
}

class _ManualCandidateDetailsSheet extends StatelessWidget {
  const _ManualCandidateDetailsSheet({
    required this.candidate,
    required this.onAssign,
  });

  final AdminRawMaterialAssignmentCandidate candidate;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = candidate.itemName.trim().isEmpty
        ? candidate.itemCode
        : candidate.itemName;
    return _ManualMaterialSheetSurface(
      icon: Icons.inventory_2_outlined,
      title: title,
      subtitle: candidate.itemCode,
      details: [
        _MaterialInfoRow(label: 'QR', value: candidate.barcode),
        _MaterialInfoRow(label: 'Ombor', value: candidate.warehouse),
        _MaterialInfoRow(label: 'Guruh', value: candidate.itemGroup),
        _MaterialInfoRow(
          label: 'Miqdor',
          value: _formatQty(candidate.qty, candidate.uom),
        ),
        _MaterialInfoRow(
          label: 'Aparat',
          value: candidate.apparatusOptions.join(', '),
        ),
      ],
      action: FilledButton.icon(
        onPressed: onAssign,
        icon: const Icon(Icons.link_rounded),
        label: const Text('Orderga ulash'),
      ),
      iconColor: scheme.onSecondaryContainer,
      iconBackground: scheme.secondaryContainer,
    );
  }
}

class _ManualAssignmentDetailsSheet extends StatelessWidget {
  const _ManualAssignmentDetailsSheet({
    required this.assignment,
    required this.unlinking,
    required this.onUnlink,
  });

  final AdminRawMaterialAssignment assignment;
  final bool unlinking;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = assignment.itemName.trim().isEmpty
        ? assignment.itemCode
        : assignment.itemName;
    final status = assignment.stockStatus.trim().toLowerCase();
    final canUnlink = status.isEmpty || status == 'available';
    return _ManualMaterialSheetSurface(
      icon: Icons.link_rounded,
      title: title,
      subtitle: assignment.itemCode,
      details: [
        _MaterialInfoRow(label: 'QR', value: assignment.barcode),
        _MaterialInfoRow(label: 'Zakaz', value: assignment.orderId),
        _MaterialInfoRow(label: 'Aparat', value: assignment.apparatus),
        _MaterialInfoRow(label: 'Ombor', value: assignment.stockWarehouse),
        _MaterialInfoRow(label: 'Guruh', value: assignment.itemGroup),
        if (assignment.stockQty > 0)
          _MaterialInfoRow(
            label: 'Miqdor',
            value: _formatQty(assignment.stockQty, assignment.stockUom),
          ),
        _MaterialInfoRow(
          label: 'Status',
          value: _assignmentStockStatusLabel(assignment.stockStatus),
        ),
      ],
      action: OutlinedButton.icon(
        onPressed: canUnlink && !unlinking ? onUnlink : null,
        style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
        icon: unlinking
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.link_off_rounded),
        label: Text(canUnlink ? 'Ulanishni uzish' : 'Uzib bo‘lmaydi'),
      ),
      iconColor: scheme.onPrimaryContainer,
      iconBackground: scheme.primaryContainer,
    );
  }
}

class _ManualMaterialSheetSurface extends StatelessWidget {
  const _ManualMaterialSheetSurface({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.action,
    required this.iconColor,
    required this.iconBackground,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> details;
  final Widget action;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewPaddingOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle.trim().isNotEmpty &&
                          subtitle.trim() != title.trim()) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...details,
            const SizedBox(height: 14),
            action,
          ],
        ),
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.slot,
    required this.assignment,
    required this.expanded,
    required this.unlinking,
    required this.onExpandedChanged,
    required this.onUnlink,
  });

  final M3SegmentVerticalSlot slot;
  final AdminRawMaterialAssignment assignment;
  final bool expanded;
  final bool unlinking;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = [
      assignment.apparatus,
      assignment.itemName,
      assignment.itemGroup,
    ].where((item) => item.trim().isNotEmpty).join(' · ');
    final assignee = _assignmentAssignee(assignment);
    final status = assignment.stockStatus.trim();
    final canUnlink = status.isEmpty || status.toLowerCase() == 'available';

    return AppSegmentSurfaceCard(
      key: ValueKey('raw-material-assignment-${_assignmentKey(assignment)}'),
      slot: slot,
      padding: EdgeInsets.fromLTRB(14, 8, 4, expanded ? 12 : 8),
      onTap: () => onExpandedChanged(!expanded),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: expanded ? 0 : 45),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: 30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.qr_code_2_rounded,
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
                        assignment.orderId.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        assignment.barcode.trim(),
                        maxLines: expanded ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          summary,
                          maxLines: expanded ? 4 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(left: 44, top: 8, right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MaterialInfoRow(
                          label: 'Zakaz',
                          value: assignment.orderId,
                        ),
                        _MaterialInfoRow(
                          label: 'QR',
                          value: assignment.barcode,
                        ),
                        _MaterialInfoRow(
                          label: 'Aparat',
                          value: assignment.apparatus,
                        ),
                        _MaterialInfoRow(
                          label: 'Ombor',
                          value: assignment.stockWarehouse,
                        ),
                        _MaterialInfoRow(
                          label: 'Kod',
                          value: assignment.itemCode,
                        ),
                        _MaterialInfoRow(
                          label: 'Nomi',
                          value: assignment.itemName,
                        ),
                        _MaterialInfoRow(
                          label: 'Guruh',
                          value: assignment.itemGroup,
                        ),
                        _MaterialInfoRow(
                          label: 'Status',
                          value: _assignmentStockStatusLabel(
                            assignment.stockStatus,
                          ),
                        ),
                        _MaterialInfoRow(
                          label: 'Band zakaz',
                          value: assignment.reservedOrderId,
                        ),
                        _MaterialInfoRow(
                          label: 'Kim uladi',
                          value: assignee,
                        ),
                        _MaterialInfoRow(
                          label: 'Vaqt',
                          value: _formatAssignmentTimestamp(
                            assignment.assignedAt,
                          ),
                        ),
                        if (canUnlink) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: unlinking ? null : onUnlink,
                              icon: unlinking
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.link_off_rounded),
                              label: const Text('Uzish'),
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

class _ScannedRawMaterialCard extends StatelessWidget {
  const _ScannedRawMaterialCard({
    required this.barcode,
    required this.detail,
    required this.loading,
    required this.error,
  });

  final String barcode;
  final AdminRawMaterialLookup? detail;
  final bool loading;
  final String error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detail = this.detail;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      size: 16,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Homashyo ma’lumoti',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _MaterialInfoRow(label: 'QR', value: barcode.trim()),
            if (detail != null) ...[
              _MaterialInfoRow(label: 'Ombor', value: detail.warehouse),
              _MaterialInfoRow(label: 'Turi', value: detail.itemGroup),
              _MaterialInfoRow(label: 'Nomi', value: detail.itemName),
              _MaterialInfoRow(
                label: 'Miqdori',
                value: _formatQty(detail.qty, detail.uom),
              ),
              _MaterialInfoRow(label: 'Item code', value: detail.itemCode),
            ],
            if (error.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                error.trim(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MaterialInfoRow extends StatelessWidget {
  const _MaterialInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cleanValue = value.trim();
    if (cleanValue.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              cleanValue,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

String _orderLabel(ProductionMapSaved order) {
  final map = order.map;
  final code = map.code.trim().isNotEmpty
      ? map.code.trim()
      : map.orderNumber.trim().isNotEmpty
          ? map.orderNumber.trim()
          : map.id.trim();
  final title = map.title.trim().isNotEmpty ? map.title.trim() : 'Zakaz';
  return '$code · $title';
}

String _formatQty(double value, String uom) {
  return formatQuantityWithUnit(
    value,
    uom,
    decimalPlaces: 3,
    trimTrailingZeros: true,
  );
}

String _assignmentKey(AdminRawMaterialAssignment assignment) {
  return '${assignment.orderId.trim()}|${assignment.barcode.trim()}';
}

String _assignmentAssignee(AdminRawMaterialAssignment assignment) {
  final name = assignment.assignedByName.trim();
  if (name.isNotEmpty) {
    return name;
  }
  return assignment.assignedByRef.trim();
}

String _assignmentStockStatusLabel(String raw) {
  return switch (raw.trim().toLowerCase()) {
    'available' => 'Mavjud',
    'reserved' => 'Band',
    'consumed' => 'Ishlatilgan',
    '' => '',
    _ => raw.trim(),
  };
}

String _formatAssignmentTimestamp(String raw) {
  return formatParsedLocalDateTimeOrRaw(raw);
}
