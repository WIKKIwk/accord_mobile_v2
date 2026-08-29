import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/widgets/forms/forms.dart';
import '../../../admin/presentation/widgets/admin_surface_tab_bar.dart';
import '../../models/returned_paint_models.dart';
import '../../state/returned_paint_draft_store.dart';

part 'returned_paint_sheet__ReturnedPaintSheetState_methods_01.dart';
part 'returned_paint_sheet__ReturnedPaintSheetState_methods_02.dart';
part 'returned_paint_sheet_helpers_part_01.dart';
part 'returned_paint_sheet_helpers_part_02.dart';

const _returnedPaintColors = <_ReturnedPaintOption>[
  _ReturnedPaintOption(
    label: 'Mix',
    color: Color(0xFF8A6A4A),
    foreground: Colors.white,
    fieldLabels: <String>[],
  ),
  _ReturnedPaintOption(
    label: 'Pantone',
    color: Color(0xFF8E6BBE),
    foreground: Colors.white,
    fieldLabels: <String>[],
  ),
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
  'Spirt',
];

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
                              onPressed: _chooseAndPickImage,
                              icon: const Icon(
                                  Icons.add_photo_alternate_outlined),
                            ),
                  ],
                ),
                if (widget.draft.image case final image?) ...[
                  const SizedBox(height: 8),
                  ReturnedPaintImageView(
                    image: image,
                    onTap: () => showReturnedPaintImagePreview(
                      context,
                      image,
                    ),
                  ),
                  if (widget.allowImageEditing) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _uploadingImage || _removingImage
                                ? null
                                : _chooseAndPickImage,
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
