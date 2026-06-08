import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../state/calculate_order_store.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminCalculateScreen extends StatefulWidget {
  const AdminCalculateScreen({
    super.key,
    this.template,
  });

  final CalculateOrderTemplate? template;

  @override
  State<AdminCalculateScreen> createState() => _AdminCalculateScreenState();
}

class _AdminCalculateScreenState extends State<AdminCalculateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderName = TextEditingController();
  final _orderNumber = TextEditingController();
  final _customer = TextEditingController();
  final _product = TextEditingController();
  final _status = TextEditingController();
  final _color = TextEditingController();
  final _kg = TextEditingController();
  final _widthMm = TextEditingController();
  final _wastePercent = TextEditingController(text: '5');
  final _rollCount = TextEditingController();
  final _firstMaterial = TextEditingController();
  final _firstMicron = TextEditingController();
  final _secondMaterial = TextEditingController();
  final _secondMicron = TextEditingController();
  final _thirdMaterial = TextEditingController();
  final _thirdMicron = TextEditingController();
  final _note = TextEditingController();

  bool _openingRoute = false;
  bool _calculating = false;
  CalculateResponse? _result;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _applyTemplate(widget.template);
  }

  @override
  void dispose() {
    _orderName.dispose();
    _orderNumber.dispose();
    _customer.dispose();
    _product.dispose();
    _status.dispose();
    _color.dispose();
    _kg.dispose();
    _widthMm.dispose();
    _wastePercent.dispose();
    _rollCount.dispose();
    _firstMaterial.dispose();
    _firstMicron.dispose();
    _secondMaterial.dispose();
    _secondMicron.dispose();
    _thirdMaterial.dispose();
    _thirdMicron.dispose();
    _note.dispose();
    super.dispose();
  }

  void _applyTemplate(CalculateOrderTemplate? template) {
    if (template == null) {
      return;
    }
    _orderName.text = template.name;
    _orderNumber.text = template.orderNumber;
    _customer.text = template.customer;
    _product.text = template.product;
    _status.text = template.status;
    _color.text = template.color;
    _kg.clear();
    _widthMm.text = _fmtInput(template.widthMm);
    _wastePercent.text = _fmtInput(template.wastePercent);
    _rollCount.text =
        template.rollCount == null ? '' : _fmtInput(template.rollCount!);
    _firstMaterial.text = template.firstLayerMaterial;
    _firstMicron.text = template.firstLayerMicron;
    _secondMaterial.text = template.secondLayerMaterial;
    _secondMicron.text = template.secondLayerMicron;
    _thirdMaterial.text = template.thirdLayerMaterial;
    _thirdMicron.text = template.thirdLayerMicron;
    _note.text = template.note;
  }

  void _openDrawerRoute(String routeName) {
    if (_openingRoute) {
      return;
    }
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) {
      return;
    }
    _openingRoute = true;
    Navigator.of(context).pushNamedAndRemoveUntil(
      routeName,
      (route) => false,
    );
  }

  Future<void> _openOrders() async {
    await Navigator.of(context).pushNamed(AppRoutes.adminCalculateOrders);
  }

  Future<void> _saveTemplate() async {
    final error = _templateValidationError();
    if (error != null) {
      showAdminTopNotice(context, error);
      return;
    }
    final template = CalculateOrderTemplate(
      id: '',
      name: _orderName.text.trim(),
      savedAt: DateTime.now().toUtc(),
      orderNumber: _orderNumber.text.trim(),
      customer: _customer.text.trim(),
      product: _product.text.trim(),
      status: _status.text.trim(),
      materialDisplay: '',
      color: _color.text.trim(),
      widthMm: _parseRequiredDouble(_widthMm.text),
      wastePercent: _parseRequiredDouble(_wastePercent.text),
      rollCount: _parseOptionalDouble(_rollCount.text),
      firstLayerMaterial: _firstMaterial.text.trim(),
      firstLayerMicron: _firstMicron.text.trim(),
      secondLayerMaterial: _secondMaterial.text.trim(),
      secondLayerMicron: _secondMicron.text.trim(),
      thirdLayerMaterial: _thirdMaterial.text.trim(),
      thirdLayerMicron: _thirdMicron.text.trim(),
      note: _note.text.trim(),
    );
    await CalculateOrderTemplateStore.instance.upsert(template);
    if (!mounted) {
      return;
    }
    showAdminTopNotice(context, 'Zakaz saqlandi');
  }

  String? _templateValidationError() {
    if (_orderName.text.trim().isEmpty) {
      return 'Zakaz nomini yozing';
    }
    final checks = <String?>[
      _requiredText(_product.text),
      _requiredPositiveNumber(_widthMm.text),
      _requiredNonNegativeNumber(_wastePercent.text),
      _requiredText(_firstMaterial.text),
      _requiredPositiveNumber(_firstMicron.text),
      _requiredText(_secondMaterial.text),
      _requiredPositiveNumber(_secondMicron.text),
      _optionalPositiveInteger(_rollCount.text),
    ];
    if (checks.any((error) => error != null)) {
      return 'Zakaz ma’lumotlarini to‘ldiring';
    }
    return null;
  }

  Future<void> _calculate() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      showAdminTopNotice(context, 'Majburiy maydonlarni to‘ldiring');
      return;
    }
    setState(() {
      _calculating = true;
      _error = '';
    });
    try {
      final result = await MobileApi.instance.calculate(
        CalculateRequest(
          orderNumber: _orderNumber.text,
          customer: _customer.text,
          product: _product.text,
          status: _status.text,
          materialDisplay: '',
          color: _color.text,
          kg: _parseRequiredDouble(_kg.text),
          widthMm: _parseRequiredDouble(_widthMm.text),
          wastePercent: _parseRequiredDouble(_wastePercent.text),
          rollCount: _parseOptionalDouble(_rollCount.text),
          firstLayer: CalculateLayerInput(
            material: _firstMaterial.text,
            micron: _firstMicron.text,
          ),
          secondLayer: CalculateLayerInput(
            material: _secondMaterial.text,
            micron: _secondMicron.text,
          ),
          thirdLayer: CalculateLayerInput(
            material: _thirdMaterial.text,
            micron: _thirdMicron.text,
          ),
          note: _note.text,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error is MobileApiException ? error.message : error.toString();
        _result = null;
      });
      showAdminTopNotice(context, 'Hisoblashda xatolik');
    } finally {
      if (mounted) {
        setState(() => _calculating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    return AppShell(
      drawer: AdminNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.adminCalculate,
        onNavigate: _openDrawerRoute,
      ),
      title: 'Calculate',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      actions: [
        AppShellIconAction(
          icon: Icons.list_alt_rounded,
          onTap: _openOrders,
        ),
        AppShellIconAction(
          icon: Icons.save_outlined,
          onTap: _saveTemplate,
        ),
      ],
      bottom: const AdminDock(activeTab: AdminDockTab.home),
      bottomDockFadeStrength: null,
      contentPadding: EdgeInsets.zero,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
          children: [
            _TextInput(
              controller: _orderName,
              label: 'Zakaz nomi',
            ),
            const _SectionHeader(title: 'Buyurtma'),
            _TextInput(
              controller: _orderNumber,
              label: 'Buyurtma raqami',
            ),
            _TextInput(
              controller: _customer,
              label: 'Mijoz',
            ),
            _TextInput(
              controller: _product,
              label: 'Mahsulot',
              required: true,
            ),
            _TextInput(
              controller: _status,
              label: 'Status',
            ),
            _TextInput(
              controller: _color,
              label: 'Rang',
            ),
            const SizedBox(height: 18),
            const _SectionHeader(title: 'Hisob'),
            _NumberInput(
              controller: _kg,
              label: 'KG',
              suffixText: 'kg',
              required: true,
            ),
            _NumberInput(
              controller: _widthMm,
              label: 'Razmer',
              suffixText: 'mm',
              required: true,
            ),
            _NumberInput(
              controller: _wastePercent,
              label: 'Atxod foiz',
              suffixText: '%',
              required: true,
              allowZero: true,
            ),
            _IntegerInput(
              controller: _rollCount,
              label: 'Val soni',
              suffixText: 'ta',
            ),
            const SizedBox(height: 18),
            const _SectionHeader(title: 'Qavatlar'),
            _LayerInputs(
              material: _firstMaterial,
              micron: _firstMicron,
              materialLabel: '1-qavat',
              required: true,
            ),
            _LayerInputs(
              material: _secondMaterial,
              micron: _secondMicron,
              materialLabel: '2-qavat',
              required: true,
            ),
            _LayerInputs(
              material: _thirdMaterial,
              micron: _thirdMicron,
              materialLabel: '3-qavat',
            ),
            const SizedBox(height: 18),
            _TextInput(
              controller: _note,
              label: 'Izoh',
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _calculating ? null : _calculate,
              icon: const Icon(Icons.calculate_outlined),
              label: Text(_calculating ? 'Hisoblanmoqda...' : 'Hisoblash'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ErrorPanel(message: _error),
            ],
            if (_result != null) ...[
              const SizedBox(height: 18),
              _ResultPanel(response: _result!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.response});

  final CalculateResponse response;

  @override
  Widget build(BuildContext context) {
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
          Text(
            'Natija',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < response.results.length; i++) ...[
            _ResultVariant(
              index: i,
              result: response.results[i],
              wastePercent: response.wastePercent,
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
  });

  final int index;
  final CalculateResult result;
  final double wastePercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = index == 0 ? 'Asosiy' : 'Variant ${index + 1}';
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
        _ResultRow(label: 'Koeff', value: _fmt(result.coeffSum)),
        _ResultRow(label: 'Razmer', value: '${_fmt(result.widthSm)} sm'),
        _ResultRow(label: 'Base', value: _fmt(result.baseLength)),
        _ResultRow(
          label: 'Atxod ${_fmt(wastePercent)}%',
          value: _fmt(result.wasteLength),
        ),
        const Divider(height: 18),
        _ResultRow(
          label: 'Yakuniy uzunlik',
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
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _LayerInputs extends StatelessWidget {
  const _LayerInputs({
    required this.material,
    required this.micron,
    required this.materialLabel,
    this.required = false,
  });

  final TextEditingController material;
  final TextEditingController micron;
  final String materialLabel;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _TextInput(
            controller: material,
            label: materialLabel,
            required: required,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _NumberInput(
            controller: micron,
            label: 'Mikron',
            suffixText: 'mkr',
            required: required,
          ),
        ),
      ],
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    this.required = false,
    this.minLines,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
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
        decoration: InputDecoration(labelText: label),
        validator: required ? _requiredText : null,
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
  });

  final TextEditingController controller;
  final String label;
  final String suffixText;
  final bool required;
  final bool allowZero;

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
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffixText,
        ),
        validator: required
            ? (allowZero ? _requiredNonNegativeNumber : _requiredPositiveNumber)
            : (allowZero
                ? _optionalNonNegativeNumber
                : _optionalPositiveNumber),
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
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffixText,
        ),
        validator: _optionalPositiveInteger,
      ),
    );
  }
}

String? _requiredText(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Majburiy';
  }
  return null;
}

String? _requiredPositiveNumber(String? value) {
  final requiredError = _requiredText(value);
  if (requiredError != null) {
    return requiredError;
  }
  return _optionalPositiveNumber(value);
}

String? _requiredNonNegativeNumber(String? value) {
  final requiredError = _requiredText(value);
  if (requiredError != null) {
    return requiredError;
  }
  return _optionalNonNegativeNumber(value);
}

String? _optionalPositiveNumber(String? value) {
  final normalized = value?.trim().replaceAll(',', '.') ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed <= 0) {
    return 'Noto‘g‘ri';
  }
  return null;
}

String? _optionalNonNegativeNumber(String? value) {
  final normalized = value?.trim().replaceAll(',', '.') ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed < 0) {
    return 'Noto‘g‘ri';
  }
  return null;
}

String? _optionalPositiveInteger(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  final parsed = int.tryParse(normalized);
  if (parsed == null || parsed <= 0) {
    return 'Noto‘g‘ri';
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

String _fmt(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}

String _fmtInput(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toString();
}
