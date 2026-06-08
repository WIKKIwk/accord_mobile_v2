import '../../../app/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminCalculateScreen extends StatefulWidget {
  const AdminCalculateScreen({super.key});

  @override
  State<AdminCalculateScreen> createState() => _AdminCalculateScreenState();
}

class _AdminCalculateScreenState extends State<AdminCalculateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderNumber = TextEditingController();
  final _customer = TextEditingController();
  final _product = TextEditingController();
  final _status = TextEditingController();
  final _material = TextEditingController();
  final _color = TextEditingController();
  final _kg = TextEditingController();
  final _widthMm = TextEditingController();
  final _rollCount = TextEditingController();
  final _firstMaterial = TextEditingController();
  final _firstMicron = TextEditingController();
  final _secondMaterial = TextEditingController();
  final _secondMicron = TextEditingController();
  final _thirdMaterial = TextEditingController();
  final _thirdMicron = TextEditingController();
  final _note = TextEditingController();

  bool _openingRoute = false;

  @override
  void dispose() {
    _orderNumber.dispose();
    _customer.dispose();
    _product.dispose();
    _status.dispose();
    _material.dispose();
    _color.dispose();
    _kg.dispose();
    _widthMm.dispose();
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

  void _validateInput() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      showAdminTopNotice(context, 'Majburiy maydonlarni to‘ldiring');
      return;
    }
    showAdminTopNotice(context, 'Maʼlumotlar tayyor');
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
      bottom: const AdminDock(activeTab: AdminDockTab.home),
      bottomDockFadeStrength: null,
      contentPadding: EdgeInsets.zero,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
          children: [
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
              controller: _material,
              label: 'Material yozuvi',
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
            _IntegerInput(
              controller: _rollCount,
              label: 'Rulon soni',
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
              onPressed: _validateInput,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Hisoblash'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
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
  });

  final TextEditingController controller;
  final String label;
  final String suffixText;
  final bool required;

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
        validator: required ? _requiredPositiveNumber : _optionalPositiveNumber,
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
