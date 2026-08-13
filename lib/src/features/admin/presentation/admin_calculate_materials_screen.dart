import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/shell/app_shell.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_create_hub_sheet.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminCalculateMaterialsScreen extends StatefulWidget {
  const AdminCalculateMaterialsScreen({super.key});

  @override
  State<AdminCalculateMaterialsScreen> createState() =>
      _AdminCalculateMaterialsScreenState();
}

class _AdminCalculateMaterialsScreenState
    extends State<AdminCalculateMaterialsScreen> {
  List<CalculateMaterial> _materials = const [];
  bool _loading = true;
  bool _saving = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }
    try {
      final materials = await MobileApi.instance.calculateMaterials();
      if (!mounted) return;
      setState(() {
        _materials = List.of(materials)
          ..sort((left, right) => left.name.compareTo(right.name));
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _materialError(error, context.l10n);
      });
    }
  }

  Future<void> _edit([CalculateMaterial? material]) async {
    final draft = await showModalBottomSheet<CalculateMaterial>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _CalculateMaterialEditor(material: material),
    );
    if (draft == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final saved = await MobileApi.instance.upsertCalculateMaterial(draft);
      if (!mounted) return;
      setState(() {
        final index = _materials.indexWhere((item) => item.id == saved.id);
        if (index < 0) {
          _materials = [..._materials, saved];
        } else {
          _materials = [..._materials]..[index] = saved;
        }
        _materials.sort((left, right) => left.name.compareTo(right.name));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.adminText('material.saved')),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_materialError(error, context.l10n))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openDrawerRoute(String routeName) {
    AdminDrawerNavigation.openRoute(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppShell(
      drawer: AdminNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.adminCalculateMaterials,
        onNavigate: _openDrawerRoute,
      ),
      title: context.l10n.adminText('material.title'),
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: AdminDock(
        activeTab: AdminDockTab.home,
        primaryFabActions: [
          AdminFabMenuAction(
            title: context.l10n.adminText('material.add'),
            icon: Icons.add_box_outlined,
            enabled: !_saving,
            onTap: () => _edit(),
          ),
        ],
      ),
      bottomDockFadeStrength: null,
      contentPadding: EdgeInsets.zero,
      child: ColoredBox(
        color: scheme.surfaceContainerLow,
        child: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.l10n.adminText('action.retry')),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        MediaQuery.paddingOf(context).bottom + 160,
      ),
      children: [
        Text(
          context.l10n.adminText('material.description'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        if (_materials.isEmpty)
          Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(context.l10n.adminText('material.empty')),
            ),
          )
        else
          for (final material in _materials)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  enabled: !_saving,
                  onTap: () => _edit(material),
                  title: Text(
                    material.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(_materialSubtitle(material, context.l10n)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ),
      ],
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
  late final TextEditingController _density;
  late bool _active;
  late List<_VariantControllers> _variants;
  String _variantError = '';

  @override
  void initState() {
    super.initState();
    final material = widget.material;
    _name = TextEditingController(text: material?.name ?? '');
    _density = TextEditingController(
      text: material == null || material.densityGCm3 <= 0
          ? ''
          : _numberText(material.densityGCm3),
    );
    _active = material?.active ?? true;
    _variants =
        material?.variants.map(_VariantControllers.fromVariant).toList() ??
            [_VariantControllers()];
  }

  @override
  void dispose() {
    _name.dispose();
    _density.dispose();
    for (final variant in _variants) {
      variant.dispose();
    }
    super.dispose();
  }

  void _addVariant() => setState(() => _variants.add(_VariantControllers()));

  void _removeVariant(int index) {
    if (_variants.length == 1) return;
    setState(() => _variants.removeAt(index).dispose());
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final density = _decimal(_density.text) ?? 0;
    final variants = <CalculateMaterialVariant>[];
    final seenMicrons = <int>{};
    for (final variant in _variants) {
      final micron = int.tryParse(variant.micron.text.trim());
      final actualGsm = _optionalDecimal(variant.actualGsm.text);
      if (micron == null || micron <= 0 || !seenMicrons.add(micron)) {
        setState(
          () => _variantError = context.l10n.adminText(
            'material.validation_microns',
          ),
        );
        return;
      }
      if (density <= 0 && actualGsm == null) {
        setState(
          () => _variantError =
              context.l10n.adminText('material.validation_actual_gsm'),
        );
        return;
      }
      final gsm = actualGsm ?? micron * density;
      variants.add(
        CalculateMaterialVariant(
          micron: micron,
          coefficient: gsm * 0.06,
          actualGsm: actualGsm,
        ),
      );
    }
    variants.sort((left, right) => left.micron.compareTo(right.micron));
    Navigator.of(context).pop(
      CalculateMaterial(
        id: widget.material?.id ?? '',
        name: _name.text.trim(),
        active: _active,
        densityGCm3: density,
        variants: variants,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                          ? context.l10n.adminText('material.add')
                          : context.l10n.adminText('material.edit'),
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
                  labelText: context.l10n.adminText('material.name'),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? context.l10n.adminText(
                        'material.validation_required',
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _density,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_decimalFormatter],
                decoration: appSurfaceInputDecoration(
                  context,
                  labelText: context.l10n.adminText('material.density'),
                  suffixText: 'g/cm³',
                  hintText: context.l10n.adminText('material.density_hint'),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final density = _decimal(value);
                  return density == null || density <= 0
                      ? context.l10n.adminText('material.validation_invalid')
                      : null;
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (value) => setState(() => _active = value),
                title: Text(
                  context.l10n.adminText('material.show_in_picker'),
                ),
              ),
              Text(
                context.l10n.adminText('material.microns'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.adminText('material.actual_gsm_note'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),
              for (var index = 0; index < _variants.length; index++) ...[
                if (index > 0) const SizedBox(height: 10),
                _VariantRow(
                  variant: _variants[index],
                  onRemove: _variants.length == 1
                      ? null
                      : () => _removeVariant(index),
                ),
              ],
              if (_variantError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _variantError,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _addVariant,
                icon: const Icon(Icons.add_rounded),
                label: Text(context.l10n.adminText('material.add_micron')),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _save,
                child: Text(context.l10n.adminText('action.save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantRow extends StatelessWidget {
  const _VariantRow({required this.variant, this.onRemove});

  final _VariantControllers variant;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
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
              labelText: context.l10n.adminText('material.micron'),
            ),
            validator: (value) {
              final micron = int.tryParse(value?.trim() ?? '');
              return micron == null || micron <= 0
                  ? context.l10n.adminText('material.validation_invalid')
                  : null;
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: variant.actualGsm,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimalFormatter],
            decoration: appSurfaceInputDecoration(
              context,
              labelText: context.l10n.adminText('material.actual_gsm'),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final gsm = _decimal(value);
              return gsm == null || gsm <= 0
                  ? context.l10n.adminText('material.validation_invalid')
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

class _VariantControllers {
  _VariantControllers({String micron = '', String actualGsm = ''})
      : micron = TextEditingController(text: micron),
        actualGsm = TextEditingController(text: actualGsm);

  factory _VariantControllers.fromVariant(CalculateMaterialVariant variant) {
    return _VariantControllers(
      micron: variant.micron.toString(),
      actualGsm:
          variant.actualGsm == null ? '' : _numberText(variant.actualGsm!),
    );
  }

  final TextEditingController micron;
  final TextEditingController actualGsm;

  void dispose() {
    micron.dispose();
    actualGsm.dispose();
  }
}

final _decimalFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'));

double? _decimal(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));

double? _optionalDecimal(String value) {
  if (value.trim().isEmpty) return null;
  return _decimal(value);
}

String _numberText(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '');
}

String _materialSubtitle(
  CalculateMaterial material,
  AppLocalizations l10n,
) {
  final density = material.densityGCm3 > 0
      ? '${_numberText(material.densityGCm3)} g/cm³'
      : l10n.adminText('material.actual_gsm_short');
  final microns = material.variants.map((item) => item.micron).join(', ');
  final inactive =
      material.active ? '' : ' • ${l10n.adminText('material.inactive_suffix')}';
  return '$density • $microns mkr$inactive';
}

String _materialError(Object error, AppLocalizations l10n) {
  if (error is MobileApiException) return error.message;
  return l10n.adminText('status.save_failed');
}
