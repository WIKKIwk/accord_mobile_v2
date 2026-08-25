import 'dart:async';
import 'dart:io';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../models/production_map_models.dart';
import '../state/calculate_order_store.dart';
import 'calculate_product_picker_loader.dart';
import '../logic/production_map_pechat_rules.dart';
import 'admin_production_map_test_screen.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class AdminCalculateArgs {
  const AdminCalculateArgs({
    this.template,
    this.trainingMode = false,
    this.trainingApparatus = '',
    this.trainingApparatusId = '',
  });

  final CalculateOrderTemplate? template;
  final bool trainingMode;
  final String trainingApparatus;
  final String trainingApparatusId;
}

const _calculateOrderTypeOptions = <String>['Paket', 'Rulon'];

String _calculateOrderTypeDisplay(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'paket':
      return 'Paket';
    case 'rulo':
    case 'rulon':
      return 'Rulon';
    default:
      return raw.trim();
  }
}

bool _sameCalculateOrderType(String left, String right) {
  return _calculateOrderTypeDisplay(left).toLowerCase() ==
      _calculateOrderTypeDisplay(right).toLowerCase();
}

class AdminCalculateScreen extends StatefulWidget {
  const AdminCalculateScreen({
    super.key,
    this.template,
    this.trainingMode = false,
    this.trainingApparatus = '',
    this.trainingApparatusId = '',
  });

  final CalculateOrderTemplate? template;
  final bool trainingMode;
  final String trainingApparatus;
  final String trainingApparatusId;

  @override
  State<AdminCalculateScreen> createState() => _AdminCalculateScreenState();
}

class _AdminCalculateScreenState extends State<AdminCalculateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _customer = TextEditingController();
  final _product = TextEditingController();
  String _orderType = '';
  final _kg = TextEditingController();
  final _frameProductSizeMm = TextEditingController();
  final _frameCount = TextEditingController();
  final _wastePercent = TextEditingController(text: '5');
  final _rollCount = TextEditingController();
  final List<_LayerControllers> _layers = [_LayerControllers()];
  final _note = TextEditingController();
  List<CalculateMaterial> _materialCatalog = const <CalculateMaterial>[];
  bool _loadingMaterialCatalog = false;

  String _customerRef = '';
  String _itemCode = '';
  String _templateId = '';
  String _orderCode = '';
  String _sourceMapId = '';
  int _productCustomerGeneration = 0;
  bool _calculating = false;
  bool _openingSavedOrder = false;
  bool _openingTrainingOrder = false;
  bool _uploadingImage = false;
  bool _editingAllFields = true;
  bool _applyingTemplate = false;
  bool _calculationListenersAttached = false;
  String _imageId = '';
  String _imageName = '';
  String _imageMime = '';
  String _imageUrl = '';
  String _imageLocalPath = '';
  int _imageSizeBytes = 0;
  CalculateResponse? _result;
  String _lastCalculatedSignature = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _editingAllFields = widget.template == null;
    _applyTemplate(widget.template);
    for (final controller in _calculationInputControllers) {
      controller.addListener(_handleCalculationInputChanged);
    }
    _calculationListenersAttached = true;
    unawaited(_warmQuickOrderTemplates());
    unawaited(_loadMaterialCatalog());
  }

  @override
  void dispose() {
    for (final controller in _calculationInputControllers) {
      controller.removeListener(_handleCalculationInputChanged);
    }
    _calculationListenersAttached = false;
    _customer.dispose();
    _product.dispose();
    _kg.dispose();
    _frameProductSizeMm.dispose();
    _frameCount.dispose();
    _wastePercent.dispose();
    _rollCount.dispose();
    for (final layer in _layers) {
      layer.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  List<TextEditingController> get _calculationInputControllers => [
        _product,
        _kg,
        _frameProductSizeMm,
        _frameCount,
        _wastePercent,
        _rollCount,
        for (final layer in _layers) ...[
          layer.material,
          layer.micron,
        ],
      ];

  List<CalculateLayerInput> get _layerInputs => _layers
      .map(
        (layer) => CalculateLayerInput(
          materialId: layer.materialId,
          material: layer.material.text.trim(),
          micron: layer.micron.text.trim(),
        ),
      )
      .toList(growable: false);

  CalculateLayerInput _legacyLayer(int index) => index < _layers.length
      ? CalculateLayerInput(
          materialId: _layers[index].materialId,
          material: _layers[index].material.text.trim(),
          micron: _layers[index].micron.text.trim(),
        )
      : const CalculateLayerInput();

  void _replaceLayers(List<CalculateLayerInput> layers) {
    if (_calculationListenersAttached) {
      for (final layer in _layers) {
        layer.removeListener(_handleCalculationInputChanged);
      }
    }
    for (final layer in _layers) {
      layer.dispose();
    }
    _layers
      ..clear()
      ..addAll(
        (layers.isEmpty ? const [CalculateLayerInput()] : layers)
            .map(_LayerControllers.fromInput),
      );
    if (_calculationListenersAttached) {
      for (final layer in _layers) {
        layer.addListener(_handleCalculationInputChanged);
      }
    }
  }

  void _addLayer() {
    final layer = _LayerControllers();
    if (_calculationListenersAttached) {
      layer.addListener(_handleCalculationInputChanged);
    }
    setState(() => _layers.add(layer));
  }

  void _removeLayer(int index) {
    if (_layers.length == 1 || index < 0 || index >= _layers.length) {
      return;
    }
    setState(() {
      final layer = _layers.removeAt(index);
      if (_calculationListenersAttached) {
        layer.removeListener(_handleCalculationInputChanged);
      }
      layer.dispose();
    });
  }

  void _handleCalculationInputChanged() {
    if (_applyingTemplate || !mounted) {
      return;
    }
    if (_result == null && _lastCalculatedSignature.isEmpty) {
      return;
    }
    setState(() {});
  }

  void _applyTemplate(CalculateOrderTemplate? template) {
    if (template == null) {
      return;
    }
    _applyingTemplate = true;
    try {
      _templateId = template.id;
      _orderCode = template.code;
      _sourceMapId = template.sourceMapId;
      _customerRef = template.customerRef;
      _customer.text = template.customer;
      _itemCode = template.itemCode;
      _product.text = template.product;
      _orderType = template.status;
      _imageId = template.imageId;
      _imageName = template.imageName;
      _imageMime = template.imageMime;
      _imageSizeBytes = template.imageSizeBytes;
      _imageUrl = template.imageUrl;
      _imageLocalPath = '';
      _kg.clear();
      _frameProductSizeMm.text = _fmtInput(template.frameProductSizeMm);
      _frameCount.text = _fmtInput(template.frameCount);
      _wastePercent.text = _fmtInput(template.wastePercent);
      _rollCount.text =
          template.rollCount == null ? '' : _fmtInput(template.rollCount!);
      _replaceLayers(template.effectiveLayers);
      _note.text = template.note;
      _result = null;
      _lastCalculatedSignature = '';
    } finally {
      _applyingTemplate = false;
    }
  }

  Future<void> _warmQuickOrderTemplates() async {
    if (widget.trainingMode) {
      return;
    }
    try {
      await CalculateOrderTemplateStore.instance.load();
    } catch (_) {
      return;
    }
  }

  Future<void> _loadMaterialCatalog({bool force = false}) async {
    if (_loadingMaterialCatalog || (!force && _materialCatalog.isNotEmpty)) {
      return;
    }
    _loadingMaterialCatalog = true;
    try {
      final materials = await MobileApi.instance.calculateMaterials();
      if (mounted) {
        setState(() => _materialCatalog = materials);
      }
    } catch (_) {
      // The existing text values remain usable for legacy templates.
    } finally {
      _loadingMaterialCatalog = false;
    }
  }

  Future<bool> _ensureMaterialCatalog() async {
    if (_materialCatalog.isNotEmpty) {
      return true;
    }
    await _loadMaterialCatalog(force: true);
    if (_materialCatalog.isNotEmpty) {
      return true;
    }
    if (mounted) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('status.load_failed'),
      );
    }
    return false;
  }

  Future<List<CalculateMaterial>> _loadMaterialPickerPage(
    String query,
    int offset,
    int limit,
  ) async {
    if (!await _ensureMaterialCatalog()) {
      return const <CalculateMaterial>[];
    }
    final normalizedQuery = _normalizeMaterialKey(query);
    final filtered = _materialCatalog.where((material) {
      if (!material.active) {
        return false;
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      return _normalizeMaterialKey(material.name).contains(normalizedQuery);
    }).toList(growable: false);
    if (offset >= filtered.length) {
      return const <CalculateMaterial>[];
    }
    return filtered.skip(offset).take(limit).toList(growable: false);
  }

  Future<void> _openLayerMaterialPicker(int index) async {
    if (index < 0 ||
        index >= _layers.length ||
        !await _ensureMaterialCatalog()) {
      return;
    }
    if (!mounted) {
      return;
    }
    final picked = await showModalBottomSheet<CalculateMaterial>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3AsyncPickerSheet<CalculateMaterial>(
          title: context.l10n.adminText('calculate.layer_material_title'),
          hintText: context.l10n.adminText('calculate.layer_material_search'),
          pageSize: 50,
          cacheKey: 'calculate:materials',
          loadPage: _loadMaterialPickerPage,
          itemTitle: (item) => item.name,
          itemSubtitle: (item) => context.l10n.adminText(
            'calculate.variant_count',
            values: {'count': item.variants.length},
          ),
          itemKey: (item) => item.id,
          onSelected: (item) => Navigator.of(context).pop(item),
        );
      },
    );
    if (picked == null || !mounted || index >= _layers.length) {
      return;
    }
    final layer = _layers[index];
    setState(() {
      layer.materialId = picked.id;
      layer.material.text = picked.name;
    });
  }

  Future<void> _openMaterialCatalogManager() async {
    await Navigator.of(context).pushNamed(AppRoutes.adminCalculateMaterials);
    if (!mounted) return;
    M3AsyncPickerSheet.clearMemoryCache();
    await _loadMaterialCatalog(force: true);
  }

  void _openDrawerRoute(String routeName) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) {
      return;
    }
    AdminDrawerNavigation.openRoute(context, routeName);
  }

  Future<void> _openOrders() async {
    await Navigator.of(context).pushNamed(AppRoutes.adminCalculateOrders);
  }

  Future<void> _openProductionMap() async {
    if (!_hasFreshCalculation) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('calculate.calculate_first'),
      );
      return;
    }
    final error = _templateValidationError();
    if (error != null) {
      showAdminTopNotice(context, error);
      return;
    }
    if (!mounted) {
      return;
    }
    final orderContext = _buildProductionMapOrderContext();
    final sourceMapId = _sourceMapId.trim();
    ProductionMapDefinition? savedMap;
    if (sourceMapId.isNotEmpty) {
      try {
        final source = await MobileApi.instance.adminProductionMap(sourceMapId);
        final cleanSourceMap = source.map.withoutAlternativeAssignments();
        savedMap = cleanSourceMap.copyWith(
          title: _resolvedOrderName(),
          productCode: _itemCode.trim().isNotEmpty
              ? _itemCode.trim()
              : cleanSourceMap.productCode,
          rollCount: _parseOptionalDouble(_rollCount.text),
          widthMm: _derivedWidthMm(),
        );
      } catch (error) {
        if (_isProductionMapMissing(error)) {
          await _handleMissingSourceMap();
          return;
        }
        if (mounted) {
          showAdminTopNotice(
            context,
            context.l10n.adminText('calculate.quick_map_load_failed'),
          );
        }
        return;
      }
    }
    if (!mounted) {
      return;
    }
    final saved = await Navigator.of(context).pushNamed(
      AppRoutes.adminProductionMapTest,
      arguments: ProductionMapTestArgs(
        orderContext: orderContext,
        savedMap: savedMap,
        templateOnly: sourceMapId.isNotEmpty,
      ),
    );
    if (!mounted || saved is! CalculateOrderTemplate) {
      return;
    }
    setState(() {
      _applyTemplate(saved);
      _editingAllFields = false;
    });
  }

  Future<void> _viewProductionMap() async {
    final sourceMapId = _sourceMapId.trim();
    if (sourceMapId.isEmpty) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('calculate.quick_map_unlinked'),
      );
      return;
    }
    try {
      final source = await MobileApi.instance.adminProductionMap(sourceMapId);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushNamed(
        AppRoutes.adminProductionMapTest,
        arguments: ProductionMapTestArgs(
          orderContext: _buildProductionMapOrderContext(),
          savedMap: source.map.withoutAlternativeAssignments(),
          readOnly: true,
        ),
      );
    } catch (error) {
      if (mounted) {
        if (_isProductionMapMissing(error)) {
          await _handleMissingSourceMap();
        } else {
          showAdminTopNotice(
            context,
            context.l10n.adminText('calculate.quick_map_load_failed'),
          );
        }
      }
    }
  }

  ProductionMapOrderContext _buildProductionMapOrderContext() {
    return ProductionMapOrderContext(
      templateId: _templateId,
      orderCode: _orderCode,
      orderName: _resolvedOrderName(),
      productName: _product.text,
      itemCode: _itemCode,
      rollCount: _parseOptionalDouble(_rollCount.text),
      widthMm: _derivedWidthMm(),
      apparatus: widget.trainingMode ? widget.trainingApparatus.trim() : '',
      apparatusId: widget.trainingMode ? widget.trainingApparatusId.trim() : '',
      templateDraft: _buildTemplateDraft(),
    );
  }

  Future<void> _openOrderFromSavedMap() async {
    if (_openingSavedOrder) {
      return;
    }
    if (!_hasFreshCalculation) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('calculate.calculate_first'),
      );
      return;
    }
    final sourceMapId = _sourceMapId.trim();
    if (sourceMapId.isEmpty) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('calculate.quick_map_unlinked'),
      );
      return;
    }
    final error = _templateValidationError();
    if (error != null) {
      showAdminTopNotice(context, error);
      return;
    }
    final confirmed = await showProductionMapOrderConfirmationSheet(context);
    if (!mounted || !confirmed) {
      return;
    }
    setState(() => _openingSavedOrder = true);
    try {
      final source = await MobileApi.instance.adminProductionMap(sourceMapId);
      final sourceMap = source.map.withoutAlternativeAssignments();
      final kg = _parseRequiredDouble(_kg.text);
      final savedQuickTemplate = await CalculateOrderTemplateStore.instance
          .upsert(_buildTemplateDraft().copyWith(kg: 0, orderNumber: ''));
      final baseLength = _result != null && _result!.results.isNotEmpty
          ? _result!.results.first.baseLength
          : null;
      final clonedMap = sourceMap.copyWith(
        id: 'zakaz-draft-${DateTime.now().microsecondsSinceEpoch}',
        title: _resolvedOrderName(),
        code: '',
        orderNumber: '',
        productCode: _itemCode.trim().isNotEmpty
            ? _itemCode.trim()
            : sourceMap.productCode,
        rollCount: _parseOptionalDouble(_rollCount.text),
        widthMm: _derivedWidthMm(),
        orderKg: kg,
        baseLength: baseLength,
      );
      final draft = savedQuickTemplate.copyWith(
        id: '',
        code: '',
        orderNumber: '',
        kg: kg,
        sourceMapId: sourceMapId,
      );
      final result = await MobileApi.instance.adminSaveProductionMapWithOrder(
        map: clonedMap,
        template: draft,
      );
      if (!mounted) {
        return;
      }
      final savedTemplate = result.template;
      if (savedTemplate != null) {
        CalculateOrderTemplateStore.instance.remember(savedTemplate);
      }
      final normalizedOrder = result.saved.map.orderNumber.trim();
      _templateId = savedQuickTemplate.id;
      _orderCode = savedQuickTemplate.code;
      _sourceMapId = savedQuickTemplate.sourceMapId;
      showAdminTopNotice(
        context,
        context.l10n.adminText(
          'calculate.order_opened',
          values: {'order': normalizedOrder},
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isProductionMapMissing(error)) {
        await _handleMissingSourceMap();
        return;
      }
      showAdminTopNotice(
        context,
        error is MobileApiException
            ? error.message
            : context.l10n.adminText('calculate.order_open_failed'),
      );
    } finally {
      if (mounted) {
        setState(() => _openingSavedOrder = false);
      }
    }
  }

  Future<void> _openTrainingOrder() async {
    if (_openingTrainingOrder || !widget.trainingMode) {
      return;
    }
    if (widget.trainingApparatus.trim().isEmpty) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('calculate.training_order_open_hint'),
      );
      return;
    }
    if (!_hasFreshCalculation) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('calculate.calculate_first'),
      );
      return;
    }
    final error = _templateValidationError();
    if (error != null) {
      showAdminTopNotice(context, error);
      return;
    }
    final confirmed = await showProductionMapOrderConfirmationSheet(context);
    if (!mounted || !confirmed) {
      return;
    }
    setState(() => _openingTrainingOrder = true);
    try {
      final orderContext = _buildProductionMapOrderContext();
      final calculation = _result;
      final saved =
          await MobileApi.instance.adminSaveTrainingProductionMapWithOrder(
        map: ProductionMapDefinition(
          id: 'zakaz-draft-${DateTime.now().microsecondsSinceEpoch}',
          productCode: _firstNonEmpty([
            _itemCode,
            _product.text,
            _resolvedOrderName(),
          ]),
          title: _resolvedOrderName(),
          customerName: _customer.text.trim(),
          rollCount: _parseOptionalDouble(_rollCount.text),
          widthMm: _derivedWidthMm(),
          orderKg: _parseRequiredDouble(_kg.text),
          baseLength: calculation != null && calculation.results.isNotEmpty
              ? calculation.results.first.baseLength
              : null,
          nodes: productionMapOrderFlowNodes(orderContext),
          edges: productionMapOrderFlowEdges(orderContext),
        ),
        template: _buildTemplateDraft(),
      );
      if (!mounted) {
        return;
      }
      final savedTemplate = saved.template;
      if (!widget.trainingMode && savedTemplate != null) {
        CalculateOrderTemplateStore.instance.remember(savedTemplate);
      }
      showAdminTopNotice(
        context,
        context.l10n.adminText(
          'calculate.training_order_opened',
          values: {'order': saved.saved.map.orderNumber},
        ),
        icon: Icons.check_circle_outline,
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? error.message
              : context.l10n.adminText('calculate.training_order_failed'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _openingTrainingOrder = false);
      }
    }
  }

  bool _isProductionMapMissing(Object error) {
    return error is MobileApiException && error.code == 'map_not_found';
  }

  Future<void> _handleMissingSourceMap() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _sourceMapId = '';
      _editingAllFields = true;
    });
    try {
      final saved = await CalculateOrderTemplateStore.instance.upsert(
        _buildTemplateDraft().copyWith(
          kg: 0,
          orderNumber: '',
          sourceMapId: '',
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _templateId = saved.id;
        _orderCode = saved.code;
        _sourceMapId = saved.sourceMapId;
        _editingAllFields = true;
      });
    } catch (_) {
      // The screen can still recover locally and let the user relink the map.
    }
    if (mounted) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('calculate.quick_map_missing'),
      );
    }
  }

  bool _hasExistingQuickOrderForProduct(SupplierItem product) {
    final productKeys = {
      product.code,
      product.name,
    }.map(_normalizeProductMapKey).where((key) => key.isNotEmpty).toSet();
    if (productKeys.isEmpty) {
      return false;
    }
    final currentTemplateId = _templateId.trim();
    final templates = CalculateOrderTemplateStore.instance.templates;
    return templates.any((template) {
      if (currentTemplateId.isNotEmpty &&
          template.id.trim() == currentTemplateId) {
        return false;
      }
      final templateKeys = {
        template.itemCode,
        template.product,
        template.name,
        template.code,
      }.map(_normalizeProductMapKey).where((key) => key.isNotEmpty);
      return templateKeys.any(productKeys.contains);
    });
  }

  Future<bool?> _confirmQuickOrderRecreate() {
    return showDialog<bool>(
      context: context,
      builder: (context) => const _QuickOrderRecreateDialog(),
    );
  }

  CalculateOrderTemplate _buildTemplateDraft() {
    final layers = _layerInputs;
    final firstLayer = _legacyLayer(0);
    final secondLayer = _legacyLayer(1);
    final thirdLayer = _legacyLayer(2);
    return CalculateOrderTemplate(
      id: _templateId,
      code: _orderCode,
      name: _resolvedOrderName(),
      savedAt: DateTime.now().toUtc(),
      orderNumber: '',
      customerRef: _customerRef,
      customer: _customer.text.trim(),
      itemCode: _itemCode,
      product: _product.text.trim(),
      status: _orderType.trim(),
      materialDisplay: '',
      color: '',
      imageId: _imageId,
      imageName: _imageName,
      imageMime: _imageMime,
      imageSizeBytes: _imageSizeBytes,
      imageUrl: _imageUrl,
      frameProductSizeMm: _parseRequiredDouble(_frameProductSizeMm.text),
      frameCount: _parseRequiredDouble(_frameCount.text),
      edgeAllowanceMm: kCalculateEdgeAllowanceMm,
      widthMm: _derivedWidthMm(),
      wastePercent: _parseRequiredDouble(_wastePercent.text),
      rollCount: _parseOptionalDouble(_rollCount.text),
      layers: layers,
      firstLayerMaterial: firstLayer.material,
      firstLayerMicron: firstLayer.micron,
      secondLayerMaterial: secondLayer.material,
      secondLayerMicron: secondLayer.micron,
      thirdLayerMaterial: thirdLayer.material,
      thirdLayerMicron: thirdLayer.micron,
      note: _note.text.trim(),
      kg: _kg.text.trim().isEmpty ? 0 : _parseRequiredDouble(_kg.text),
      sourceMapId: _sourceMapId,
    );
  }

  Future<void> _openCustomerPicker() async {
    final picked = await showModalBottomSheet<CustomerDirectoryEntry>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3AsyncPickerSheet<CustomerDirectoryEntry>(
          title: context.l10n.adminText('calculate.customer_select'),
          hintText: context.l10n.adminText('calculate.customer_search'),
          pageSize: 50,
          cacheKey: 'calculate:customers',
          loadPage: (query, offset, limit) {
            return MobileApi.instance.adminCustomers(
              query: query,
              offset: offset,
              limit: limit,
            );
          },
          itemTitle: (item) => item.name.trim().isEmpty ? item.ref : item.name,
          itemSubtitle: (item) {
            final phone = item.phone.trim();
            return phone.isEmpty ? item.ref : '${item.ref} • $phone';
          },
          onSelected: (item) => Navigator.of(context).pop(item),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _productCustomerGeneration++;
      _customerRef = picked.ref;
      _customer.text =
          picked.name.trim().isEmpty ? picked.ref : picked.name.trim();
      _itemCode = '';
      _product.clear();
    });
  }

  Future<void> _openOrderTypePicker() async {
    final current = _orderType.trim();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final l10n = sheetContext.l10n;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.adminText('calculate.order_type_input'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                for (final option in _calculateOrderTypeOptions)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(option),
                    trailing: _sameCalculateOrderType(current, option)
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () => Navigator.of(sheetContext).pop(option),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _orderType = picked;
    });
  }

  Future<void> _openProductPicker() async {
    final pickerCustomerName = _customer.text.trim();
    final picked = await showModalBottomSheet<SupplierItem>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3AsyncPickerSheet<CalculateProductPickerOption>(
          title: context.l10n.adminText('calculate.product_select'),
          hintText: context.l10n.adminText('calculate.product_search'),
          pageSize: 80,
          cacheKey: _customerRef.trim().isEmpty
              ? 'calculate:finished-items:v2:customer-names'
              : 'calculate:customer-finished-items:v2:${_customerRef.trim()}',
          loadPage: (query, offset, limit) {
            return loadCalculateProductPickerOptionsPage(
              customerRef: _customerRef,
              customerName: pickerCustomerName,
              query: query,
              offset: offset,
              limit: limit,
              customerDetail: MobileApi.instance.adminCustomerDetail,
              allItems: MobileApi.instance.adminItemsPage,
            );
          },
          itemTitle: (option) => option.item.name.trim().isEmpty
              ? option.item.code
              : option.item.name,
          itemSubtitle: (option) => option.customerName,
          itemKey: (option) => option.item.code,
          onSelected: (option) => Navigator.of(context).pop(option.item),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    if (_hasExistingQuickOrderForProduct(picked)) {
      if (!mounted) {
        return;
      }
      final recreate = await _confirmQuickOrderRecreate();
      if (!mounted || recreate != true) {
        return;
      }
    }
    if (!mounted) {
      return;
    }
    final shouldAutoSelectCustomer =
        _customerRef.trim().isEmpty && _customer.text.trim().isEmpty;
    final generation = _productCustomerGeneration + 1;
    setState(() {
      _productCustomerGeneration = generation;
      _itemCode = picked.code;
      _product.text =
          picked.name.trim().isEmpty ? picked.code : picked.name.trim();
    });
    if (shouldAutoSelectCustomer) {
      unawaited(_autoSelectCustomerForProduct(picked, generation));
    }
  }

  Future<void> _autoSelectCustomerForProduct(
    SupplierItem product,
    int generation,
  ) async {
    try {
      final customer = await loadCalculateProductCustomer(
        itemCode: product.code,
        itemDetail: MobileApi.instance.adminItemDetail,
      );
      if (!mounted ||
          generation != _productCustomerGeneration ||
          customer == null ||
          _customerRef.trim().isNotEmpty ||
          _customer.text.trim().isNotEmpty) {
        return;
      }
      setState(() {
        _customerRef = customer.ref;
        _customer.text =
            customer.name.trim().isEmpty ? customer.ref : customer.name.trim();
      });
    } catch (_) {
      return;
    }
  }

  String _firstNonEmpty(Iterable<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return 'zakaz';
  }

  String _resolvedOrderName() {
    final product = _product.text.trim();
    return product.isEmpty ? 'Zakaz' : product;
  }

  double _derivedWidthMm() {
    return _parseRequiredDouble(_frameProductSizeMm.text) *
            _parseRequiredDouble(_frameCount.text) +
        kCalculateEdgeAllowanceMm;
  }

  String? _templateValidationError() {
    final checks = <String?>[
      _requiredText(_product.text),
      _requiredPositiveNumber(_frameProductSizeMm.text),
      _requiredPositiveNumber(_frameCount.text),
      _requiredNonNegativeNumber(_wastePercent.text),
      for (final layer in _layers) ...[
        _requiredText(layer.material.text),
        _requiredPositiveNumber(layer.micron.text),
      ],
      _optionalPositiveInteger(_rollCount.text),
    ];
    if (checks.any((error) => error != null)) {
      return context.l10n.adminText('calculate.order_details_required');
    }
    return null;
  }

  Future<void> _calculate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_product.text.trim().isEmpty) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('calculate.product_select'),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('calculate.required_fields'),
      );
      return;
    }
    setState(() {
      _calculating = true;
      _error = '';
    });
    try {
      final result = await MobileApi.instance.calculate(
        CalculateRequest(
          orderNumber: '',
          customer: _customer.text,
          product: _product.text,
          status: _orderType,
          materialDisplay: '',
          color: '',
          kg: _parseRequiredDouble(_kg.text),
          frameProductSizeMm: _parseRequiredDouble(_frameProductSizeMm.text),
          frameCount: _parseRequiredDouble(_frameCount.text),
          edgeAllowanceMm: kCalculateEdgeAllowanceMm,
          wastePercent: _parseRequiredDouble(_wastePercent.text),
          rollCount: _parseOptionalDouble(_rollCount.text),
          layers: _layerInputs,
          note: _note.text,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _lastCalculatedSignature = _calculationSignature();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error is MobileApiException ? error.message : error.toString();
        _result = null;
        _lastCalculatedSignature = '';
      });
      showAdminTopNotice(
        context,
        context.l10n.adminText('calculate.calculate_error'),
      );
    } finally {
      if (mounted) {
        setState(() => _calculating = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 84,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _uploadingImage = true;
      _imageLocalPath = picked.path;
      _error = '';
    });
    try {
      final image = await (widget.trainingMode
          ? MobileApi.instance.uploadTrainingCalculateOrderImage(
              bytes: await picked.readAsBytes(),
              filename: picked.name,
            )
          : MobileApi.instance.uploadCalculateOrderImage(
              bytes: await picked.readAsBytes(),
              filename: picked.name,
            ));
      if (!mounted) {
        return;
      }
      setState(() {
        _imageId = image.imageId;
        _imageName = image.imageName;
        _imageMime = image.imageMime;
        _imageSizeBytes = image.imageSizeBytes;
        _imageUrl = image.imageUrl;
        _imageLocalPath = '';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _imageLocalPath = '';
        _error = error is MobileApiException ? error.message : error.toString();
      });
      showAdminTopNotice(
        context,
        context.l10n.adminText('calculate.image_upload_failed'),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  void _clearImage() {
    setState(() {
      _imageId = '';
      _imageName = '';
      _imageMime = '';
      _imageSizeBytes = 0;
      _imageUrl = '';
      _imageLocalPath = '';
    });
  }

  void _enableFullEdit() {
    setState(() {
      _editingAllFields = true;
    });
  }

  List<Widget> _fullEditChildren(AppLocalizations l10n) {
    return [
      _SectionHeader(title: l10n.adminText('calculate.order_section')),
      _PickerInput(
        label: l10n.adminText('label.customer'),
        value: _customer.text,
        subtitle: _customerRef,
        onTap: _openCustomerPicker,
      ),
      _PickerInput(
        label: l10n.adminText('calculate.product_select'),
        value: _product.text,
        subtitle: _itemCode,
        required: true,
        onTap: _openProductPicker,
      ),
      _PickerInput(
        label: l10n.adminText('calculate.order_type_input'),
        value: _calculateOrderTypeDisplay(_orderType),
        onTap: _openOrderTypePicker,
      ),
      _ImageUploadInput(
        localPath: _imageLocalPath,
        imageUrl: _imageUrl,
        imageName: _imageName,
        imageSizeBytes: _imageSizeBytes,
        uploading: _uploadingImage,
        onPick: _pickImage,
        onClear: _clearImage,
      ),
      const SizedBox(height: 18),
      _SectionHeader(title: l10n.adminText('calculate.accounting_section')),
      _NumberInput(
        controller: _kg,
        label: l10n.adminText('calculate.kg_input'),
        suffixText: 'kg',
        required: true,
      ),
      _NumberInput(
        controller: _frameProductSizeMm,
        label: l10n.adminText('calculate.frame_size'),
        suffixText: 'mm',
        required: true,
      ),
      _NumberInput(
        controller: _frameCount,
        label: l10n.adminText('calculate.frame_count'),
        suffixText: l10n.adminText('calculate.pieces_suffix'),
        required: true,
      ),
      _NumberInput(
        controller: _wastePercent,
        label: l10n.adminText('calculate.waste_percent'),
        suffixText: '%',
        required: true,
        allowZero: true,
      ),
      _IntegerInput(
        controller: _rollCount,
        label: l10n.adminText('calculate.roll_count'),
        suffixText: l10n.adminText('calculate.pieces_suffix'),
      ),
      const SizedBox(height: 18),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        children: [
          _SectionHeader(title: l10n.adminText('calculate.layers_section')),
          TextButton.icon(
            onPressed: _openMaterialCatalogManager,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: Text(l10n.adminText('calculate.material_manager')),
          ),
        ],
      ),
      for (var index = 0; index < _layers.length; index++)
        _LayerInputs(
          material: _layers[index].material,
          micron: _layers[index].micron,
          materialLabel: l10n.adminText(
            'calculate.layer_label',
            values: {'number': index + 1},
          ),
          micronKey: ValueKey('calculate-layer-micron-$index'),
          onMaterialTap: () => _openLayerMaterialPicker(index),
          onRemove: index == 0 ? null : () => _removeLayer(index),
        ),
      OutlinedButton.icon(
        onPressed: _addLayer,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.adminText('calculate.add_layer')),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      const SizedBox(height: 18),
      _TextInput(
        controller: _note,
        label: l10n.adminText('calculate.note'),
        minLines: 3,
        maxLines: 5,
      ),
      ..._calculateActionChildren(l10n),
    ];
  }

  List<Widget> _compactTemplateChildren(AppLocalizations l10n) {
    return [
      _SavedTemplateSummary(
        title: _resolvedOrderName(),
        customer: _customer.text,
        customerRef: _customerRef,
        product: _product.text,
        itemCode: _itemCode,
        status: _calculateOrderTypeDisplay(_orderType),
        imageUrl: _imageUrl,
        imageName: _imageName,
        imageSizeBytes: _imageSizeBytes,
        frameProductSizeMm: _frameProductSizeMm.text,
        frameCount: _frameCount.text,
        widthMm: _fmtInput(_derivedWidthMm()),
        rollCount: _rollCount.text,
        layers: _layerInputs,
        note: _note.text,
      ),
      const SizedBox(height: 18),
      _SectionHeader(title: l10n.adminText('calculate.accounting_section')),
      _NumberInput(
        controller: _kg,
        label: l10n.adminText('calculate.kg_input'),
        suffixText: 'kg',
        required: true,
      ),
      _NumberInput(
        controller: _wastePercent,
        label: l10n.adminText('calculate.waste_percent'),
        suffixText: '%',
        required: true,
        allowZero: true,
      ),
      ..._calculateActionChildren(l10n),
    ];
  }

  List<Widget> _calculateActionChildren(AppLocalizations l10n) {
    final freshResult = _hasFreshCalculation ? _result : null;
    return [
      const SizedBox(height: 22),
      FilledButton.icon(
        onPressed: _calculating ? null : _calculate,
        icon: const Icon(Icons.calculate_outlined),
        label: Text(
          _calculating
              ? l10n.adminText('calculate.calculating')
              : l10n.adminText('calculate.calculate'),
        ),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
      if (_error.isNotEmpty) ...[
        const SizedBox(height: 16),
        _ErrorPanel(message: _error),
      ],
      if (freshResult != null) ...[
        const SizedBox(height: 18),
        _ResultPanel(
          response: freshResult,
          rollCount: _parseOptionalDouble(_rollCount.text),
          widthMm: _derivedWidthMm(),
          onViewMap: _sourceMapId.trim().isEmpty ? null : _viewProductionMap,
        ),
        if (widget.trainingMode) ...[
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _openingTrainingOrder ? null : _openTrainingOrder,
            icon: Icon(
              _openingTrainingOrder
                  ? Icons.hourglass_top_rounded
                  : Icons.school_outlined,
            ),
            label: Text(
              _openingTrainingOrder
                  ? l10n.adminText('calculate.training_order_opening')
                  : l10n.adminText('calculate.training_order_open'),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
        if (_sourceMapId.trim().isNotEmpty) ...[
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _openingSavedOrder ? null : _openOrderFromSavedMap,
            icon: Icon(
              _openingSavedOrder
                  ? Icons.hourglass_top_rounded
                  : Icons.playlist_add_check_rounded,
            ),
            label: Text(
              _openingSavedOrder
                  ? l10n.adminText('calculate.opening')
                  : l10n.adminText('calculate.order_open'),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
        if (_editingAllFields && !widget.trainingMode) ...[
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _openProductionMap,
            icon: const Icon(Icons.account_tree_outlined),
            label: Text(l10n.adminText('calculate.map_attach')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ],
    ];
  }

  bool get _hasFreshCalculation =>
      _result != null && _lastCalculatedSignature == _calculationSignature();

  String _calculationSignature() {
    return [
      _product.text.trim(),
      _kg.text.trim(),
      _frameProductSizeMm.text.trim(),
      _frameCount.text.trim(),
      _wastePercent.text.trim(),
      _rollCount.text.trim(),
      for (final layer in _layers) ...[
        layer.material.text.trim(),
        layer.micron.text.trim(),
      ],
    ].join('\u001f');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    final children = _editingAllFields
        ? _fullEditChildren(l10n)
        : _compactTemplateChildren(l10n);
    final resolvedName = _resolvedOrderName().trim();
    final pageTitle = resolvedName.isEmpty || resolvedName == 'Zakaz'
        ? l10n.adminText('calculate.create_title')
        : resolvedName;
    return AppShell(
      drawer: AdminNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.adminCalculate,
        onNavigate: _openDrawerRoute,
      ),
      title: widget.trainingMode
          ? l10n.adminText('calculate.training_title')
          : pageTitle,
      subtitle:
          widget.trainingMode ? l10n.adminText('calculate.test_mode') : '',
      nativeTopBar: true,
      resizeToAvoidBottomInset: false,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: AppShellIconAction(
            icon: Icons.list_alt_rounded,
            size: 38,
            onTap: _openOrders,
          ),
        ),
        if (!_editingAllFields)
          AppShellIconAction(icon: Icons.edit_outlined, onTap: _enableFullEdit),
      ],
      bottom: const AdminDock(activeTab: AdminDockTab.home),
      bottomDockFadeStrength: null,
      contentPadding: EdgeInsets.zero,
      child: ColoredBox(
        color: AppTheme.shellStart(context),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                4,
                12,
                4,
                bottomPadding + MediaQuery.viewInsetsOf(context).bottom,
              ),
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickOrderRecreateDialog extends StatelessWidget {
  const _QuickOrderRecreateDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.adminText('calculate.quick_order_exists'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.adminText('calculate.recreate_question'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 26),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: scheme.errorContainer.withValues(alpha: 0.42),
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(false),
                            child: Center(
                              child: Text(
                                l10n.adminText('calculate.no'),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: scheme.error,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(width: 1, color: scheme.surfaceContainerHigh),
                      Expanded(
                        child: Material(
                          color: scheme.primary,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(true),
                            child: Center(
                              child: Text(
                                l10n.adminText('calculate.yes'),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedTemplateSummary extends StatelessWidget {
  const _SavedTemplateSummary({
    required this.title,
    required this.customer,
    required this.customerRef,
    required this.product,
    required this.itemCode,
    required this.status,
    required this.imageUrl,
    required this.imageName,
    required this.imageSizeBytes,
    required this.frameProductSizeMm,
    required this.frameCount,
    required this.widthMm,
    required this.rollCount,
    required this.layers,
    required this.note,
  });

  final String title;
  final String customer;
  final String customerRef;
  final String product;
  final String itemCode;
  final String status;
  final String imageUrl;
  final String imageName;
  final int imageSizeBytes;
  final String frameProductSizeMm;
  final String frameCount;
  final String widthMm;
  final String rollCount;
  final List<CalculateLayerInput> layers;
  final String note;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final piecesSuffix = l10n.adminText('calculate.pieces_suffix');
    final micronSuffix = l10n.adminText('calculate.micron_suffix');
    final imageTitle = imageName.trim().isEmpty
        ? l10n.adminText('calculate.image_selected')
        : imageName.trim();
    final resolvedTitle = title.trim().isEmpty
        ? l10n.adminText('calculate.order_create_default')
        : title.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              resolvedTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (imageUrl.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showCalculateImageDialog(context, imageUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 2.35,
                    child: _ImagePreview(localPath: '', imageUrl: imageUrl),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                imageTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (imageSizeBytes > 0)
                Text(
                  _formatBytes(imageSizeBytes),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
            const SizedBox(height: 14),
            _ChecklistSection(
              title: l10n.adminText('calculate.order_section'),
              rows: [
                _ChecklistRowData(
                  l10n.adminText('label.customer'),
                  customer,
                  subtitle: customerRef,
                ),
                _ChecklistRowData(
                  l10n.adminText('label.item'),
                  product,
                  subtitle: itemCode,
                ),
                _ChecklistRowData(
                  l10n.adminText('calculate.order_type_input'),
                  status,
                ),
              ],
            ),
            const _ReceiptDivider(),
            _ChecklistSection(
              title: l10n.adminText('calculate.parameters'),
              rows: [
                _ChecklistRowData(
                  l10n.adminText('calculate.size'),
                  widthMm,
                  suffix: 'mm',
                ),
                _ChecklistRowData(
                  l10n.adminText('calculate.frame_size'),
                  frameProductSizeMm,
                  suffix: 'mm',
                ),
                _ChecklistRowData(
                  l10n.adminText('calculate.frame_count'),
                  frameCount,
                  suffix: piecesSuffix,
                ),
                _ChecklistRowData(
                  l10n.adminText('calculate.roll_count'),
                  rollCount,
                  suffix: piecesSuffix,
                ),
              ],
            ),
            const _ReceiptDivider(),
            _ChecklistSection(
              title: l10n.adminText('calculate.layers_section'),
              rows: [
                for (var index = 0; index < layers.length; index++)
                  _ChecklistRowData(
                    l10n.adminText(
                      'calculate.layer_label',
                      values: {'number': index + 1},
                    ),
                    _layerValue(
                      layers[index].material,
                      layers[index].micron,
                      micronSuffix,
                    ),
                  ),
              ],
            ),
            if (note.trim().isNotEmpty) ...[
              const _ReceiptDivider(),
              _ChecklistSection(
                title: l10n.adminText('calculate.note'),
                rows: [_ChecklistRowData('', note)],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

void _showCalculateImageDialog(BuildContext context, String imageUrl) {
  final token = _sessionToken();
  showDialog<void>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return Dialog.fullscreen(
        backgroundColor: scheme.surfaceContainerLowest,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      MobileApi.instance.calculateOrderImageUrl(imageUrl),
                      headers: token.isEmpty
                          ? null
                          : {'Authorization': 'Bearer $token'},
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          _ImagePlaceholder(color: scheme.primary),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ChecklistSection extends StatelessWidget {
  const _ChecklistSection({required this.title, required this.rows});

  final String title;
  final List<_ChecklistRowData> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visibleRows = rows.where((row) => row.hasValue).toList();
    if (visibleRows.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < visibleRows.length; i++)
          _ChecklistRow(data: visibleRows[i]),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.data});

  final _ChecklistRowData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = data.formattedValue;
    final subtitle = data.displaySubtitle;
    final hasLabel = data.label.trim().isNotEmpty;

    if (!hasLabel) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              data.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
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
    );
  }
}

class _ChecklistRowData {
  const _ChecklistRowData(
    this.label,
    this.value, {
    this.subtitle = '',
    this.suffix = '',
  });

  final String label;
  final String value;
  final String subtitle;
  final String suffix;

  bool get hasValue => value.trim().isNotEmpty || subtitle.trim().isNotEmpty;

  String get formattedValue {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return subtitle.trim();
    }
    final unit = suffix.trim();
    return unit.isEmpty ? trimmed : '$trimmed $unit';
  }

  String get displaySubtitle {
    final trimmed = subtitle.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return _sameChecklistText(trimmed, formattedValue) ? '' : trimmed;
  }
}

bool _sameChecklistText(String left, String right) {
  return left.trim().toLowerCase() == right.trim().toLowerCase();
}

String _layerValue(String material, String micron, String micronSuffix) {
  final materialText = material.trim();
  final micronText = micron.trim();
  final suffix = micronSuffix.trim();
  if (materialText.isEmpty) {
    return micronText.isEmpty ? '' : '$micronText $suffix';
  }
  if (micronText.isEmpty) {
    return materialText;
  }
  return '$materialText • $micronText $suffix';
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.response,
    required this.rollCount,
    required this.widthMm,
    this.onViewMap,
  });

  final CalculateResponse response;
  final double? rollCount;
  final double widthMm;
  final VoidCallback? onViewMap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.adminText('calculate.result_title'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onViewMap != null)
                TextButton.icon(
                  onPressed: onViewMap,
                  icon: const Icon(Icons.account_tree_outlined, size: 18),
                  label: Text(l10n.adminText('calculate.view_map')),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (response.results.isNotEmpty) ...[
            _ResultRow(
              label: l10n.adminText('calculate.finished_gsm'),
              value: '${_fmt(response.results.first.totalGsm)} g/m²',
              emphasized: true,
            ),
            const Divider(height: 18),
          ],
          _ResultMultilineRow(
            label: l10n.adminText('calculate.print'),
            value: productionMapPechatCompatibilitySummary(
              rollCount: rollCount,
              widthMm: widthMm,
            ),
          ),
          const Divider(height: 18),
          for (var i = 0; i < response.results.length; i++) ...[
            _ResultVariant(
              index: i,
              result: response.results[i],
              wastePercent: response.wastePercent,
              rubberSizeMm: response.rubberSizeMm,
              minMoldSizeMm: response.minMoldSizeMm,
            ),
            if (i != response.results.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ResultVariant extends StatelessWidget {
  const _ResultVariant({
    required this.index,
    required this.result,
    required this.wastePercent,
    required this.rubberSizeMm,
    required this.minMoldSizeMm,
  });

  final int index;
  final CalculateResult result;
  final double wastePercent;
  final int rubberSizeMm;
  final double minMoldSizeMm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final title = index == 0
        ? l10n.adminText('calculate.primary')
        : l10n.adminText(
            'calculate.variant',
            values: {'number': index + 1},
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        _ResultRow(
          label: l10n.adminText('calculate.coeff'),
          value: _fmt(result.coeffSum),
        ),
        _ResultRow(
          label: l10n.adminText('calculate.size'),
          value: '${_fmt(result.widthSm * 10)} mm',
        ),
        _ResultRow(
          label: l10n.adminText('calculate.minimum_mold'),
          value: '${_fmt(minMoldSizeMm)} mm',
        ),
        _ResultRow(
          label: l10n.adminText('calculate.rubber_size'),
          value: '$rubberSizeMm mm',
        ),
        _ResultRow(
          label: l10n.adminText('calculate.base'),
          value: _fmt(result.baseLength),
        ),
        _ResultRow(
          label: l10n.adminText(
            'calculate.waste_with_percent',
            values: {'percent': _fmt(wastePercent)},
          ),
          value: _fmt(result.wasteLength),
        ),
        const Divider(height: 18),
        _ResultRow(
          label: l10n.adminText('calculate.final_length'),
          value: _fmt(result.roundedLength),
          emphasized: true,
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasized
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _ResultMultilineRow extends StatelessWidget {
  const _ResultMultilineRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: style?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onErrorContainer,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _PickerInput extends StatelessWidget {
  const _PickerInput({
    required this.label,
    required this.value,
    required this.onTap,
    this.subtitle = '',
    this.required = false,
  });

  final String label;
  final String value;
  final String subtitle;
  final bool required;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayValue = value.trim();
    final displaySubtitle = subtitle.trim();
    final empty = displayValue.isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: required && empty ? scheme.error : scheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: required && empty
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      empty ? label : displayValue,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color:
                            empty ? scheme.onSurfaceVariant : scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (displaySubtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        displaySubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageUploadInput extends StatelessWidget {
  const _ImageUploadInput({
    required this.localPath,
    required this.imageUrl,
    required this.imageName,
    required this.imageSizeBytes,
    required this.uploading,
    required this.onPick,
    required this.onClear,
  });

  final String localPath;
  final String imageUrl;
  final String imageName;
  final int imageSizeBytes;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasImage = localPath.trim().isNotEmpty || imageUrl.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: uploading ? null : onPick,
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: _ImagePreview(
                    localPath: localPath,
                    imageUrl: imageUrl,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.adminText('calculate.image_label'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasImage
                          ? (imageName.trim().isEmpty
                              ? l10n.adminText('calculate.image_selected')
                              : imageName.trim())
                          : l10n.adminText('calculate.image_pick'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (imageSizeBytes > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatBytes(imageSizeBytes),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (uploading) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(minHeight: 3),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (hasImage)
                IconButton(
                  onPressed: uploading ? null : onClear,
                  icon: const Icon(Icons.close_rounded),
                )
              else
                Icon(Icons.upload_file_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.localPath, required this.imageUrl});

  final String localPath;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (localPath.trim().isNotEmpty) {
      if (kIsWeb) {
        return Image.network(
          localPath,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _ImagePlaceholder(color: scheme.primary),
        );
      }
      return Image.file(File(localPath), fit: BoxFit.cover);
    }
    if (imageUrl.trim().isNotEmpty) {
      final token = _sessionToken();
      return Image.network(
        MobileApi.instance.calculateOrderImageUrl(imageUrl),
        headers: token.isEmpty ? null : {'Authorization': 'Bearer $token'},
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _ImagePlaceholder(color: scheme.primary),
      );
    }
    return _ImagePlaceholder(color: scheme.onSurfaceVariant);
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.image_outlined, color: color),
    );
  }
}

String _sessionToken() {
  try {
    return MobileApi.instance.requireToken();
  } catch (_) {
    return '';
  }
}

class _LayerInputs extends StatelessWidget {
  const _LayerInputs({
    required this.material,
    required this.micron,
    required this.materialLabel,
    required this.micronKey,
    required this.onMaterialTap,
    this.onRemove,
  });

  final TextEditingController material;
  final TextEditingController micron;
  final String materialLabel;
  final Key micronKey;
  final VoidCallback onMaterialTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _PickerInput(
            label: materialLabel,
            value: material.text,
            required: true,
            onTap: onMaterialTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: TextFormField(
            key: micronKey,
            controller: micron,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.next,
            decoration: appSurfaceInputDecoration(
              context,
              labelText: l10n.adminText('calculate.micron'),
              suffixText: l10n.adminText('calculate.micron_suffix'),
            ),
            validator: (value) => _requiredPositiveNumber(value, l10n),
          ),
        ),
        if (onRemove != null) ...[
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: IconButton(
              onPressed: onRemove,
              tooltip: l10n.adminText('calculate.remove_layer'),
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
          ),
        ],
      ],
    );
  }
}

class _LayerControllers {
  _LayerControllers({
    String materialId = '',
    String material = '',
    String micron = '',
  })  : materialId = materialId,
        material = TextEditingController(text: material),
        micron = TextEditingController(text: micron);

  factory _LayerControllers.fromInput(CalculateLayerInput input) {
    return _LayerControllers(
      materialId: input.materialId,
      material: input.material,
      micron: input.micron,
    );
  }

  String materialId;
  final TextEditingController material;
  final TextEditingController micron;

  void addListener(VoidCallback listener) {
    material.addListener(listener);
    micron.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    material.removeListener(listener);
    micron.removeListener(listener);
  }

  void dispose() {
    material.dispose();
    micron.dispose();
  }
}

class _CalculateMaterialManager extends StatefulWidget {
  const _CalculateMaterialManager({required this.materials});

  final List<CalculateMaterial> materials;

  @override
  State<_CalculateMaterialManager> createState() =>
      _CalculateMaterialManagerState();
}

class _CalculateMaterialManagerState extends State<_CalculateMaterialManager> {
  late List<CalculateMaterial> _materials;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _materials = List<CalculateMaterial>.of(widget.materials);
  }

  Future<void> _edit([CalculateMaterial? material]) async {
    final l10n = context.l10n;
    final draft = await showModalBottomSheet<CalculateMaterial>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _CalculateMaterialEditor(material: material),
    );
    if (draft == null || !mounted) {
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await MobileApi.instance.upsertCalculateMaterial(draft);
      final index = _materials.indexWhere((item) => item.id == saved.id);
      setState(() {
        if (index >= 0) {
          _materials[index] = saved;
        } else {
          _materials.add(saved);
        }
        _materials.sort((left, right) => left.name.compareTo(right.name));
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_materialSaveError(l10n, error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.adminText('calculate.material_manager'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.adminText('calculate.manager_description'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : () => _edit(),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.adminText('calculate.material_add')),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _materials.isEmpty
                  ? Center(
                      child: Text(l10n.adminText('calculate.material_empty')),
                    )
                  : ListView.separated(
                      itemCount: _materials.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final material = _materials[index];
                        final micronText = material.variants
                            .map((variant) => '${variant.micron}')
                            .join(', ');
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          enabled: !_saving,
                          onTap: () => _edit(material),
                          title: Text(
                            material.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            material.active
                                ? l10n.adminText(
                                    'calculate.active_micron_suffix',
                                    values: {'microns': micronText},
                                  )
                                : l10n.adminText(
                                    'calculate.inactive_micron_suffix',
                                    values: {'microns': micronText},
                                  ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalculateMaterialEditor extends StatefulWidget {
  const _CalculateMaterialEditor({this.material});

  final CalculateMaterial? material;

  @override
  State<_CalculateMaterialEditor> createState() =>
      _CalculateMaterialEditorState();
}

class _CalculateMaterialEditorState extends State<_CalculateMaterialEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late bool _active;
  late List<_CalculateMaterialVariantControllers> _variants;
  String _variantError = '';

  @override
  void initState() {
    super.initState();
    final material = widget.material;
    _name = TextEditingController(text: material?.name ?? '');
    _active = material?.active ?? true;
    _variants = material?.variants
            .map(_CalculateMaterialVariantControllers.fromVariant)
            .toList() ??
        [_CalculateMaterialVariantControllers()];
  }

  @override
  void dispose() {
    _name.dispose();
    for (final variant in _variants) {
      variant.dispose();
    }
    super.dispose();
  }

  void _addVariant() {
    setState(() => _variants.add(_CalculateMaterialVariantControllers()));
  }

  void _removeVariant(int index) {
    if (_variants.length == 1) {
      return;
    }
    setState(() {
      final variant = _variants.removeAt(index);
      variant.dispose();
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final variants = <CalculateMaterialVariant>[];
    final seenMicrons = <int>{};
    for (final variant in _variants) {
      final micron = int.tryParse(variant.micron.text.trim());
      final coefficient = double.tryParse(
        variant.coefficient.text.trim().replaceAll(',', '.'),
      );
      if (micron == null || coefficient == null || !seenMicrons.add(micron)) {
        setState(
          () => _variantError = context.l10n.adminText(
            'calculate.duplicate_micron',
          ),
        );
        return;
      }
      variants.add(
        CalculateMaterialVariant(
          micron: micron,
          coefficient: coefficient,
          firstLayerCoefficient: variant.firstLayerCoefficient,
        ),
      );
    }
    Navigator.of(context).pop(
      CalculateMaterial(
        id: widget.material?.id ?? '',
        name: _name.text.trim(),
        active: _active,
        variants: variants,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.material == null
                          ? l10n.adminText('calculate.material_add')
                          : l10n.adminText('calculate.material_edit'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              TextFormField(
                controller: _name,
                decoration: appSurfaceInputDecoration(
                  context,
                  labelText: l10n.adminText('calculate.material_name'),
                ),
                validator: (value) => _requiredText(value, l10n),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (value) => setState(() => _active = value),
                title: Text(l10n.adminText('calculate.show_in_picker')),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.adminText('calculate.micron_coefficient'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              for (var index = 0; index < _variants.length; index++) ...[
                if (index > 0) const SizedBox(height: 10),
                _MaterialVariantEditorRow(
                  variant: _variants[index],
                  onRemove: _variants.length == 1
                      ? null
                      : () => _removeVariant(index),
                ),
              ],
              if (_variantError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _variantError,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _addVariant,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.adminText('calculate.add_micron')),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _save,
                child: Text(l10n.adminText('action.save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialVariantEditorRow extends StatelessWidget {
  const _MaterialVariantEditorRow({required this.variant, this.onRemove});

  final _CalculateMaterialVariantControllers variant;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: variant.micron,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: appSurfaceInputDecoration(
              context,
              labelText: l10n.adminText('calculate.micron'),
            ),
            validator: (value) {
              final micron = int.tryParse(value?.trim() ?? '');
              return micron == null || micron <= 0
                  ? l10n.adminText('calculate.invalid')
                  : null;
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: variant.coefficient,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: appSurfaceInputDecoration(
              context,
              labelText: l10n.adminText('calculate.coefficient'),
            ),
            validator: (value) {
              final coefficient = double.tryParse(
                value?.trim().replaceAll(',', '.') ?? '',
              );
              return coefficient == null || coefficient <= 0
                  ? l10n.adminText('calculate.invalid')
                  : null;
            },
          ),
        ),
        if (onRemove != null)
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
      ],
    );
  }
}

class _CalculateMaterialVariantControllers {
  _CalculateMaterialVariantControllers({
    String micron = '',
    String coefficient = '',
    this.firstLayerCoefficient,
  })  : micron = TextEditingController(text: micron),
        coefficient = TextEditingController(text: coefficient);

  factory _CalculateMaterialVariantControllers.fromVariant(
    CalculateMaterialVariant variant,
  ) {
    return _CalculateMaterialVariantControllers(
      micron: variant.micron.toString(),
      coefficient: _fmtInput(variant.coefficient),
      firstLayerCoefficient: variant.firstLayerCoefficient,
    );
  }

  final TextEditingController micron;
  final TextEditingController coefficient;
  final double? firstLayerCoefficient;

  void dispose() {
    micron.dispose();
    coefficient.dispose();
  }
}

String _materialSaveError(AppLocalizations l10n, Object error) {
  if (error is MobileApiException) {
    return error.message;
  }
  return l10n.adminText('calculate.material_save_failed');
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    this.validator,
    this.minLines,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final int? minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        textInputAction:
            maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
        decoration: appSurfaceInputDecoration(context, labelText: label),
        validator: validator,
      ),
    );
  }
}

class _NumberInput extends StatelessWidget {
  const _NumberInput({
    required this.controller,
    required this.label,
    required this.suffixText,
    this.required = false,
    this.allowZero = false,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String suffixText;
  final bool required;
  final bool allowZero;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        textInputAction: TextInputAction.next,
        decoration: appSurfaceInputDecoration(
          context,
          labelText: label,
          suffixText: suffixText,
        ),
        validator: validator ??
            (required
                ? (value) => allowZero
                    ? _requiredNonNegativeNumber(value, context.l10n)
                    : _requiredPositiveNumber(value, context.l10n)
                : (value) => allowZero
                    ? _optionalNonNegativeNumber(value, context.l10n)
                    : _optionalPositiveNumber(value, context.l10n)),
      ),
    );
  }
}

class _IntegerInput extends StatelessWidget {
  const _IntegerInput({
    required this.controller,
    required this.label,
    required this.suffixText,
  });

  final TextEditingController controller;
  final String label;
  final String suffixText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textInputAction: TextInputAction.next,
        decoration: appSurfaceInputDecoration(
          context,
          labelText: label,
          suffixText: suffixText,
        ),
        validator: (value) => _optionalPositiveInteger(value, context.l10n),
      ),
    );
  }
}

String? _requiredText(String? value, [AppLocalizations? l10n]) {
  if (value == null || value.trim().isEmpty) {
    return l10n?.adminText('calculate.required') ?? 'Majburiy';
  }
  return null;
}

String? _requiredPositiveNumber(String? value, [AppLocalizations? l10n]) {
  final requiredError = _requiredText(value, l10n);
  if (requiredError != null) {
    return requiredError;
  }
  return _optionalPositiveNumber(value, l10n);
}

String? _requiredNonNegativeNumber(String? value, [AppLocalizations? l10n]) {
  final requiredError = _requiredText(value, l10n);
  if (requiredError != null) {
    return requiredError;
  }
  return _optionalNonNegativeNumber(value, l10n);
}

String? _optionalPositiveNumber(String? value, [AppLocalizations? l10n]) {
  final normalized = value?.trim().replaceAll(',', '.') ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed <= 0) {
    return l10n?.adminText('calculate.invalid') ?? 'Noto‘g‘ri';
  }
  return null;
}

String? _optionalNonNegativeNumber(String? value, [AppLocalizations? l10n]) {
  final normalized = value?.trim().replaceAll(',', '.') ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed < 0) {
    return l10n?.adminText('calculate.invalid') ?? 'Noto‘g‘ri';
  }
  return null;
}

String? _optionalPositiveInteger(String? value, [AppLocalizations? l10n]) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  final parsed = int.tryParse(normalized);
  if (parsed == null || parsed <= 0) {
    return l10n?.adminText('calculate.invalid') ?? 'Noto‘g‘ri';
  }
  return null;
}

double _parseRequiredDouble(String value) {
  return double.parse(value.trim().replaceAll(',', '.'));
}

double? _parseOptionalDouble(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) {
    return null;
  }
  return double.parse(normalized);
}

String _formatBytes(int value) {
  if (value >= 1024 * 1024) {
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (value >= 1024) {
    return '${(value / 1024).toStringAsFixed(1)} KB';
  }
  return '$value B';
}

String _fmt(double value) => formatQuantity(value);

String _fmtInput(double value) => formatRawQuantity(value);

String _normalizeProductMapKey(String value) {
  return value.trim().toLowerCase();
}

String _normalizeMaterialKey(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
