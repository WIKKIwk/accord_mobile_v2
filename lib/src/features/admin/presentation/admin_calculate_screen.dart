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

part 'admin_calculate_screen__AdminCalculateScreenState_methods_01.dart';
part 'admin_calculate_screen__AdminCalculateScreenState_methods_02.dart';
part 'admin_calculate_screen__AdminCalculateScreenState_methods_03.dart';
part 'admin_calculate_screen__AdminCalculateScreenState_methods_04.dart';
part 'admin_calculate_screen_models_part_01.dart';
part 'admin_calculate_screen_widgets_part_02.dart';
part 'admin_calculate_screen_declarations_part_03.dart';
part 'admin_calculate_screen_models_part_04.dart';
part 'admin_calculate_screen_declarations_part_05.dart';

const _calculateOrderTypeOptions = <String>['Paket', 'Rulon'];

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

  bool get _hasFreshCalculation =>
      _result != null && _lastCalculatedSignature == _calculationSignature();

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
