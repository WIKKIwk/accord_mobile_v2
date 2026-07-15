import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/widgets/forms/forms.dart';
import '../../../admin/presentation/widgets/admin_surface_tab_bar.dart';
import '../../models/returned_paint_models.dart';
import '../../state/returned_paint_draft_store.dart';

typedef ReturnedPaintSaveCallback = Future<void> Function(
  List<ReturnedPaintItemInput> items,
);

class _ReturnedPaintOption {
  const _ReturnedPaintOption({
    required this.label,
    required this.color,
    required this.foreground,
    this.fieldLabels,
  });

  final String label;
  final Color color;
  final Color foreground;
  final List<String>? fieldLabels;
}

const _returnedPaintColors = <_ReturnedPaintOption>[
  _ReturnedPaintOption(
    label: 'Oq',
    color: Color(0xFFF8F7F2),
    foreground: Color(0xFF332C26),
  ),
  _ReturnedPaintOption(
    label: 'Sariq',
    color: Color(0xFFFFD54F),
    foreground: Color(0xFF3B2A00),
  ),
  _ReturnedPaintOption(
    label: 'Qizil',
    color: Color(0xFFE53935),
    foreground: Colors.white,
  ),
  _ReturnedPaintOption(
    label: 'Ko‘k',
    color: Color(0xFF1E88E5),
    foreground: Colors.white,
  ),
  _ReturnedPaintOption(
    label: 'Tilla',
    color: Color(0xFFD4A72C),
    foreground: Color(0xFF332100),
  ),
  _ReturnedPaintOption(
    label: 'Kumush',
    color: Color(0xFFC7CDD3),
    foreground: Color(0xFF273038),
  ),
  _ReturnedPaintOption(
    label: 'Qora',
    color: Color(0xFF202124),
    foreground: Colors.white,
  ),
  _ReturnedPaintOption(
    label: 'Varnish',
    color: Color(0xFF5A321F),
    foreground: Colors.white,
  ),
];

const _returnedPaintLacquers = <_ReturnedPaintOption>[
  _ReturnedPaintOption(
    label: 'Lak',
    color: Color(0xFFB7BCC2),
    foreground: Color(0xFF273038),
    fieldLabels: <String>['OPV lak', 'MAT lak'],
  ),
];

const _returnedPaintSolvents = <_ReturnedPaintOption>[
  _ReturnedPaintOption(
    label: 'Spirtlar',
    color: Color(0xFFE4B77A),
    foreground: Color(0xFF3E2815),
    fieldLabels: <String>[
      'Aralashmalar',
      'Etil',
      'Metoxil',
      'Rasvavitel',
      'Izopropel',
    ],
  ),
];

const _returnedPaintFieldLabels = <String>[
  'Mix',
  '1w Oq',
  '7w Oq',
  'Qora',
  'Sariq',
  'Qizil',
  'Ko‘k',
  'Varnish',
  'Spirt',
];

List<ReturnedPaintItemInput> returnedPaintItemsFromDraft(
  ReturnedPaintDraft draft,
) {
  final items = <ReturnedPaintItemInput>[];

  void collect(
    int usageIndex,
    String category,
    List<_ReturnedPaintOption> options,
  ) {
    for (final option in options) {
      final stateKey =
          '${usageIndex == 0 ? 'rasxot' : 'astatka'}:${option.label}';
      final baseFields = option.fieldLabels ?? _returnedPaintFieldLabels;
      final fields = option.fieldLabels == null
          ? draft.fieldLabelsFor(stateKey, baseFields)
          : baseFields;
      final rawValues = draft.valuesFor(stateKey, fields.length);
      final values = <String, String>{};
      for (var index = 0; index < fields.length; index++) {
        final raw = rawValues[index].trim();
        if (raw.isEmpty) continue;
        final normalized = raw.replaceAll(',', '.');
        final value = double.tryParse(normalized);
        if (value != null && value.isFinite && value >= 0) {
          values[fields[index]] = normalized;
        }
      }
      if (values.isNotEmpty) {
        items.add(
          ReturnedPaintItemInput(
            usage: usageIndex == 0 ? 'rasxot' : 'astatka',
            category: category,
            name: option.label,
            values: values,
          ),
        );
      }
    }
  }

  for (var usageIndex = 0; usageIndex < 2; usageIndex++) {
    collect(usageIndex, 'colors', _returnedPaintColors);
    collect(usageIndex, 'lacquers', _returnedPaintLacquers);
    collect(usageIndex, 'solvents', _returnedPaintSolvents);
  }
  return items;
}

int returnedPaintFilledFieldCount(
  Iterable<ReturnedPaintItemInput> items,
) =>
    items.fold<int>(0, (count, item) => count + item.values.length);

bool returnedPaintReportCanClose({
  required Iterable<ReturnedPaintItemInput> items,
  required String imageId,
}) {
  final fieldCount = returnedPaintFilledFieldCount(items);
  return fieldCount >= 3 || (fieldCount == 0 && imageId.trim().isNotEmpty);
}

bool returnedPaintDraftHasInvalidValues(ReturnedPaintDraft draft) {
  for (var usageIndex = 0; usageIndex < 2; usageIndex++) {
    for (final option in [
      ..._returnedPaintColors,
      ..._returnedPaintLacquers,
      ..._returnedPaintSolvents,
    ]) {
      final stateKey =
          '${usageIndex == 0 ? 'rasxot' : 'astatka'}:${option.label}';
      final baseFields = option.fieldLabels ?? _returnedPaintFieldLabels;
      final fields = option.fieldLabels == null
          ? draft.fieldLabelsFor(stateKey, baseFields)
          : baseFields;
      for (final raw in draft.valuesFor(stateKey, fields.length)) {
        if (raw.trim().isNotEmpty && !_isValidReturnedPaintNumber(raw)) {
          return true;
        }
      }
    }
  }
  return false;
}

class ReturnedPaintSheet extends StatefulWidget {
  const ReturnedPaintSheet({
    super.key,
    required this.draft,
    required this.orderId,
    required this.apparatus,
    this.allowImageEditing = false,
    this.onSave,
    this.saveLabel = 'Saqlash',
  });

  final ReturnedPaintDraft draft;
  final String orderId;
  final String apparatus;
  final bool allowImageEditing;
  final ReturnedPaintSaveCallback? onSave;
  final String saveLabel;

  @override
  State<ReturnedPaintSheet> createState() => _ReturnedPaintSheetState();
}

class _ReturnedPaintSheetState extends State<ReturnedPaintSheet>
    with TickerProviderStateMixin {
  static const double _fieldHeight = 56;

  final ImagePicker _imagePicker = ImagePicker();
  late final TabController _usageController;
  String? _selectedPaint;
  int? _selectedUsageIndex;
  List<String>? _selectedFieldLabels;
  final Map<String, List<TextEditingController>> _fieldControllersByPaint = {};
  bool _uploadingImage = false;
  bool _removingImage = false;
  bool _saving = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _usageController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.draft.selectedUsageIndex == 1 ? 1 : 0,
    )..addListener(() {
        widget.draft.selectedUsageIndex = _usageController.index;
      });
  }

  @override
  void dispose() {
    _usageController.dispose();
    for (final controllers in _fieldControllersByPaint.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Color _fieldBorderColor(String label) {
    return switch (label) {
      'Mix' => const Color(0xFF8A6A4A),
      '1w Oq' || '7w Oq' => const Color(0xFFC9B9AA),
      'Qora' => const Color(0xFF202124),
      'Sariq' => const Color(0xFFE0B52D),
      'Qizil' => const Color(0xFFE53935),
      'Ko‘k' => const Color(0xFF1E88E5),
      'Varnish' => const Color(0xFF5A321F),
      'Spirt' => const Color(0xFF6AAED6),
      'Pantone+' => const Color(0xFF8E6BBE),
      _ => Theme.of(context).colorScheme.outlineVariant,
    };
  }

  InputDecoration _paintFieldDecoration(String label) {
    final base = appSurfaceInputDecoration(context, labelText: label);
    final color = _fieldBorderColor(label);
    return base.copyWith(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: 1.8),
      ),
    );
  }

  String _paintStateKey(String paint, int usageIndex) =>
      '${usageIndex == 0 ? 'rasxot' : 'astatka'}:$paint';

  List<String> _resolvedFields(
    _ReturnedPaintOption option,
    int usageIndex,
  ) {
    final fields = option.fieldLabels ?? _returnedPaintFieldLabels;
    return option.fieldLabels == null
        ? widget.draft.fieldLabelsFor(
            _paintStateKey(option.label, usageIndex),
            fields,
          )
        : fields;
  }

  List<TextEditingController> _controllersForPaint(
    String paint,
    List<String> fieldLabels,
    int usageIndex,
  ) {
    final stateKey = _paintStateKey(paint, usageIndex);
    final existing = _fieldControllersByPaint[stateKey];
    if (existing != null && existing.length == fieldLabels.length) {
      return existing;
    }
    for (final controller in existing ?? const <TextEditingController>[]) {
      controller.dispose();
    }
    final values = widget.draft.valuesFor(stateKey, fieldLabels.length);
    final controllers = [
      for (var index = 0; index < fieldLabels.length; index++)
        TextEditingController(text: values[index]),
    ];
    _fieldControllersByPaint[stateKey] = controllers;
    return controllers;
  }

  Widget? _completionIndicator(
    _ReturnedPaintOption option,
    int usageIndex,
  ) {
    final fields = _resolvedFields(option, usageIndex);
    final values = widget.draft.valuesFor(
      _paintStateKey(option.label, usageIndex),
      fields.length,
    );
    final filled = values.map((value) => value.trim().isNotEmpty).toList();
    if (filled.every((value) => !value)) return null;
    return Icon(
      filled.every((value) => value) ? Icons.check_rounded : Icons.star_rounded,
      size: filled.every((value) => value) ? 17 : 16,
      color: option.foreground,
    );
  }

  void _updateFieldValue({
    required String paint,
    required int index,
    required String value,
    required int usageIndex,
  }) {
    final stateKey = _paintStateKey(paint, usageIndex);
    final baseFields = _selectedFieldLabels ?? _returnedPaintFieldLabels;
    final fields = baseFields.contains('1w Oq')
        ? widget.draft.fieldLabelsFor(stateKey, baseFields)
        : baseFields;
    widget.draft.setValue(stateKey, index, value, fields.length);
    setState(() => _error = '');
  }

  void _addPantoneField(String paint, int usageIndex) {
    widget.draft.addPantoneField(_paintStateKey(paint, usageIndex));
    setState(() {});
  }

  Future<void> _pickImage() async {
    if (_uploadingImage || _removingImage) return;
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 84,
    );
    if (picked == null) return;
    setState(() {
      _uploadingImage = true;
      _error = '';
    });
    final previous = widget.draft.image;
    try {
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        throw const MobileApiException(
          code: 'returned_paint_image_empty',
          message: 'Tanlangan rasm bo‘sh',
        );
      }
      if (bytes.length > 6 * 1024 * 1024) {
        throw const MobileApiException(
          code: 'returned_paint_image_too_large',
          message: 'Rasm hajmi 6 MB dan oshmasligi kerak',
        );
      }
      final image = await MobileApi.instance.uploadReturnedPaintImage(
        orderId: widget.orderId,
        apparatus: widget.apparatus,
        bytes: bytes,
        filename: picked.name,
        mime: _imageMime(picked),
      );
      widget.draft.setImage(image);
      if (previous != null && previous.imageId != image.imageId) {
        try {
          await MobileApi.instance.deleteReturnedPaintImage(previous.imageId);
        } catch (_) {
          // The new order-bound image is already saved; an unattached old image
          // must not roll the user's replacement back.
        }
      }
    } catch (error) {
      if (mounted) _error = _errorText(error, 'Rasm yuklanmadi');
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _removeImage() async {
    final image = widget.draft.image;
    if (image == null || _uploadingImage || _removingImage) return;
    setState(() {
      _removingImage = true;
      _error = '';
    });
    try {
      await MobileApi.instance.deleteReturnedPaintImage(image.imageId);
      widget.draft.setImage(null);
    } catch (error) {
      if (mounted) _error = _errorText(error, 'Rasm olib tashlanmadi');
    } finally {
      if (mounted) setState(() => _removingImage = false);
    }
  }

  Future<void> _save() async {
    final callback = widget.onSave;
    if (callback == null || _saving) return;
    if (returnedPaintDraftHasInvalidValues(widget.draft)) {
      setState(() {
        _error = 'Qaytarilgan bo‘yoq qiymatlarini to‘g‘ri raqamda kiriting.';
      });
      return;
    }
    final items = returnedPaintItemsFromDraft(widget.draft);
    if (returnedPaintFilledFieldCount(items) < 3) {
      setState(() {
        _error = 'Kamida 3 ta qaytarilgan bo‘yoq maydonini to‘ldiring.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await callback(items);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _errorText(error, 'Qaytarilgan bo‘yoq saqlanmadi');
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _paintFields(
    String paint,
    List<String> fieldLabels,
    int usageIndex,
  ) {
    final stateKey = _paintStateKey(paint, usageIndex);
    final hasPantoneButton = fieldLabels.contains('1w Oq');
    final resolvedFields = hasPantoneButton
        ? widget.draft.fieldLabelsFor(stateKey, fieldLabels)
        : fieldLabels;
    final controllers = _controllersForPaint(
      paint,
      resolvedFields,
      usageIndex,
    );
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: resolvedFields.length + (hasPantoneButton ? 1 : 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: _fieldHeight,
      ),
      itemBuilder: (context, index) {
        if (hasPantoneButton && index == resolvedFields.length) {
          return OutlinedButton(
            onPressed: () => _addPantoneField(paint, usageIndex),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFF8E6BBE),
              foregroundColor: Colors.white,
              side: BorderSide(
                color: _fieldBorderColor('Pantone+'),
                width: 1.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Pantone+'),
          );
        }
        return TextFormField(
          controller: controllers[index],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            _returnedPaintNumberFormatter(),
          ],
          decoration: _paintFieldDecoration(resolvedFields[index]),
          onChanged: (value) => _updateFieldValue(
            paint: paint,
            index: index,
            value: value,
            usageIndex: usageIndex,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    Widget category(
      String title,
      List<_ReturnedPaintOption> options,
      int usageIndex,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel(context, title),
          GridView.builder(
            itemCount: options.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisExtent: 64,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final option = options[index];
              return Tooltip(
                message: option.label,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final radius = BorderRadius.circular(
                      constraints.maxHeight / 2,
                    );
                    return Material(
                      color: option.color,
                      elevation: 7,
                      shadowColor: Colors.black45,
                      borderRadius: radius,
                      child: InkWell(
                        borderRadius: radius,
                        onTap: () {
                          setState(() {
                            _selectedPaint = option.label;
                            _selectedUsageIndex = usageIndex;
                            _selectedFieldLabels =
                                option.fieldLabels ?? _returnedPaintFieldLabels;
                          });
                        },
                        child: Stack(
                          children: [
                            Center(
                              child: Text(
                                option.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: option.foreground,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (_completionIndicator(option, usageIndex)
                                case final indicator?)
                              Positioned(top: 8, right: 12, child: indicator),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 14),
        ],
      );
    }

    Widget palettePage(int usageIndex) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          category('Ranglar', _returnedPaintColors, usageIndex),
          category('Laklar', _returnedPaintLacquers, usageIndex),
          category(
            'Erituvchilar / spirtli suyuqliklar',
            _returnedPaintSolvents,
            usageIndex,
          ),
        ],
      );
    }

    final busy = _uploadingImage || _removingImage || _saving;
    return PopScope(
      canPop: !busy,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Orqaga',
                      onPressed: busy
                          ? null
                          : () {
                              if (_selectedPaint != null) {
                                setState(() {
                                  _selectedPaint = null;
                                  _selectedUsageIndex = null;
                                  _selectedFieldLabels = null;
                                });
                                return;
                              }
                              Navigator.of(context).pop();
                            },
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Text(
                        'Qaytarilgan bo‘yoq',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (widget.allowImageEditing)
                      _uploadingImage
                          ? const SizedBox.square(
                              dimension: 42,
                              child: Padding(
                                padding: EdgeInsets.all(10),
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              tooltip: widget.draft.image == null
                                  ? 'Rasm qo‘shish'
                                  : 'Rasmni almashtirish',
                              onPressed: _pickImage,
                              icon: const Icon(
                                  Icons.add_photo_alternate_outlined),
                            ),
                  ],
                ),
                if (widget.draft.image case final image?) ...[
                  const SizedBox(height: 8),
                  ReturnedPaintImageView(image: image),
                  if (widget.allowImageEditing) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _uploadingImage || _removingImage
                                ? null
                                : _pickImage,
                            icon: const Icon(Icons.sync_rounded),
                            label: const Text('Almashtirish'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _uploadingImage || _removingImage
                                ? null
                                : _removeImage,
                            icon: _removingImage
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.delete_outline_rounded),
                            label: const Text('Olib tashlash'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ReturnedPaintErrorMessage(message: _error),
                ],
                const SizedBox(height: 14),
                if (_selectedPaint == null) ...[
                  AdminSurfaceTabBar(
                    controller: _usageController,
                    tabs: const [
                      Tab(height: 38, text: 'Rasxot'),
                      Tab(height: 38, text: 'Astatka'),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  reverseDuration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    reverseDuration: const Duration(milliseconds: 140),
                    child: _selectedPaint == null
                        ? SizedBox(
                            key: const ValueKey('returned-paint-palette'),
                            height: 640,
                            child: TabBarView(
                              controller: _usageController,
                              children: [palettePage(0), palettePage(1)],
                            ),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('returned-paint-fields'),
                            child: _paintFields(
                              _selectedPaint!,
                              _selectedFieldLabels ?? _returnedPaintFieldLabels,
                              _selectedUsageIndex ?? _usageController.index,
                            ),
                          ),
                  ),
                ),
                Divider(color: scheme.outlineVariant),
                if (widget.onSave != null) ...[
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.saveLabel),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReturnedPaintImageView extends StatelessWidget {
  const ReturnedPaintImageView({
    super.key,
    required this.image,
  });

  final ReturnedPaintImage image;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = MobileApi.instance.returnedPaintImageUrl(image.imageUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: url.isEmpty
              ? Icon(
                  Icons.image_outlined,
                  size: 42,
                  color: scheme.onSurfaceVariant,
                )
              : Image.network(
                  url,
                  headers: MobileApi.instance.returnedPaintImageHeaders(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 42,
                      color: scheme.error,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ReturnedPaintErrorMessage extends StatelessWidget {
  const _ReturnedPaintErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 18, color: scheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _sectionLabel(BuildContext context, String label) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 8),
    child: Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

String _imageMime(XFile file) {
  final mime = file.mimeType?.trim().toLowerCase() ?? '';
  if (const {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif',
  }.contains(mime)) {
    return mime;
  }
  final name = file.name.toLowerCase();
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.webp')) return 'image/webp';
  if (name.endsWith('.heic')) return 'image/heic';
  if (name.endsWith('.heif')) return 'image/heif';
  return 'image/jpeg';
}

TextInputFormatter _returnedPaintNumberFormatter() {
  final pattern = RegExp(r'^(?:\d+(?:[.,]\d*)?)?$');
  return TextInputFormatter.withFunction(
    (oldValue, newValue) =>
        pattern.hasMatch(newValue.text) ? newValue : oldValue,
  );
}

bool _isValidReturnedPaintNumber(String raw) {
  final value = raw.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d+(?:\.\d*)?$').hasMatch(value)) return false;
  final parts = value.split('.');
  final integer = parts.first.replaceFirst(RegExp(r'^0+'), '');
  final fraction =
      parts.length == 2 ? parts[1].replaceFirst(RegExp(r'0+$'), '') : '';
  if (fraction.length > 11 || integer.length > 18) return false;
  return integer != '999999999999999999' || fraction.isEmpty;
}

String _errorText(Object error, String fallback) =>
    error is MobileApiException ? error.message : fallback;
