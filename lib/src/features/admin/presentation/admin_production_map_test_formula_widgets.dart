part of 'admin_production_map_test_screen.dart';

const _formulaVariables = [
  _FormulaVariable(label: 'Buyurtma miqdori', token: 'order_qty'),
  _FormulaVariable(label: 'CPP kg', token: 'cpp_kg'),
  _FormulaVariable(label: 'Natija kg', token: 'result_kg'),
];

String _formulaDisplayText(String expression) {
  var text = expression;
  for (final variable in _formulaVariables) {
    text = text.replaceAllMapped(
      RegExp('\\b${RegExp.escape(variable.token)}\\b'),
      (_) => variable.label,
    );
  }
  return text;
}

String _formulaInternalText(String expression) {
  var text = expression;
  for (final variable in _formulaVariables) {
    text = text.replaceAll(
      RegExp(variable.label, caseSensitive: false),
      variable.token,
    );
  }
  return text;
}

class _FormulaVariable {
  const _FormulaVariable({required this.label, required this.token});

  final String label;
  final String token;
}

class _FormulaAutocompleteController extends TextEditingController {
  _FormulaAutocompleteController({required String text}) : super(text: text);

  _FormulaVariable? get suggestion {
    final prefix = _currentSegment().trim().toLowerCase();
    if (prefix.length < 2) {
      return null;
    }
    for (final variable in _formulaVariables) {
      if (variable.label.toLowerCase().startsWith(prefix) ||
          variable.token.toLowerCase().startsWith(prefix)) {
        return variable;
      }
    }
    return null;
  }

  String get ghostCompletion {
    final active = suggestion;
    if (active == null) {
      return '';
    }
    final cursor = _cursor;
    if (cursor != text.length) {
      return '';
    }
    final prefix = _currentSegment().trim();
    if (prefix.isEmpty) {
      return '';
    }
    if (active.label.toLowerCase().startsWith(prefix.toLowerCase())) {
      return active.label.substring(prefix.length);
    }
    if (active.token.toLowerCase().startsWith(prefix.toLowerCase())) {
      return active.label;
    }
    return '';
  }

  int get _cursor {
    final selection = this.selection;
    return selection.isValid ? selection.baseOffset : text.length;
  }

  int segmentStart() {
    var start = _cursor.clamp(0, text.length);
    while (start > 0 && !'+-*/()<>!=&|,'.contains(text[start - 1])) {
      start--;
    }
    return start;
  }

  String _currentSegment() {
    final cursor = _cursor.clamp(0, text.length);
    return text.substring(segmentStart(), cursor);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final ghost = ghostCompletion;
    if (ghost.isEmpty) {
      return TextSpan(style: baseStyle, text: text);
    }
    return TextSpan(
      style: baseStyle,
      children: [
        TextSpan(text: text),
        TextSpan(
          text: ghost,
          style: baseStyle.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.42),
          ),
        ),
      ],
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _FormulaSheetField extends StatefulWidget {
  const _FormulaSheetField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  State<_FormulaSheetField> createState() => _FormulaSheetFieldState();
}

class _FormulaSheetFieldState extends State<_FormulaSheetField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(covariant _FormulaSheetField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller.removeListener(_sync);
    widget.controller.addListener(_sync);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openEditor() async {
    final edited = await showModalBottomSheet<String>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (context) => _FormulaEditorSheet(
        title: widget.label,
        expression: widget.controller.text,
      ),
    );
    if (edited == null || !mounted) {
      return;
    }
    widget.controller.text = edited;
  }

  @override
  Widget build(BuildContext context) {
    final display = _formulaDisplayText(widget.controller.text);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _openEditor,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: const Icon(Icons.open_in_full_rounded),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          display.isEmpty ? ' ' : display,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _FormulaEditorSheet extends StatefulWidget {
  const _FormulaEditorSheet({required this.title, required this.expression});

  final String title;
  final String expression;

  @override
  State<_FormulaEditorSheet> createState() => _FormulaEditorSheetState();
}

class _FormulaEditorSheetState extends State<_FormulaEditorSheet> {
  late final _FormulaAutocompleteController _expression;
  final FocusNode _expressionFocusNode = FocusNode();
  _FormulaVariable? _suggestion;

  @override
  void initState() {
    super.initState();
    _expression = _FormulaAutocompleteController(
      text: _formulaDisplayText(widget.expression),
    );
    _expression.addListener(_updateSuggestion);
    _updateSuggestion();
  }

  @override
  void dispose() {
    _expression.dispose();
    _expressionFocusNode.dispose();
    super.dispose();
  }

  void _updateSuggestion() {
    final next = _expression.suggestion;
    if (next == _suggestion) {
      return;
    }
    setState(() => _suggestion = next);
  }

  void _insertVariable(
    _FormulaVariable variable, {
    bool addTrailingSpace = false,
  }) {
    final selection = _expression.selection;
    final text = _expression.text;
    final cursor = selection.isValid ? selection.baseOffset : text.length;
    final start = _expression.segmentStart();
    final before = text.substring(0, start);
    final after = text.substring(cursor.clamp(0, text.length));
    final insertText = addTrailingSpace ? '${variable.label} ' : variable.label;
    final nextText = '$before$insertText$after';
    final nextOffset = before.length + insertText.length;
    _expression.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
  }

  void _keepFormulaFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _expressionFocusNode.requestFocus();
      }
    });
  }

  void _save() {
    Navigator.of(context).pop(_formulaInternalText(_expression.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyLarge ??
        const TextStyle(fontSize: 16, height: 1.35);
    return _DismissibleBottomSheetFrame(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const SizedBox(width: 44, height: 4),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '${widget.title} yozish',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _expression,
              focusNode: _expressionFocusNode,
              autofocus: true,
              minLines: 5,
              maxLines: 8,
              style: textStyle,
              textInputAction: TextInputAction.done,
              onEditingComplete: () {},
              onSubmitted: (_) {
                final active = _suggestion;
                if (active != null && _expression.ghostCompletion.isNotEmpty) {
                  _insertVariable(active, addTrailingSpace: true);
                }
                _keepFormulaFocus();
              },
              decoration: InputDecoration(
                labelText: widget.title,
                alignLabelWithHint: true,
                contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final variable in _formulaVariables)
                  InputChip(
                    label: Text(variable.label),
                    onPressed: () => _insertVariable(variable),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _PlainActionButton(
              label: 'Saqlash',
              icon: Icons.check_rounded,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }
}
