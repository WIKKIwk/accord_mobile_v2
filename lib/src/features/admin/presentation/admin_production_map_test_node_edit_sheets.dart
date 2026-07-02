part of 'admin_production_map_test_screen.dart';

class _NodeEditSheet extends StatefulWidget {
  const _NodeEditSheet({required this.node});

  final ProductionMapNode node;

  @override
  State<_NodeEditSheet> createState() => _NodeEditSheetState();
}

class _RezkaNodeEditSheet extends StatefulWidget {
  const _RezkaNodeEditSheet({required this.node, required this.frameCount});

  final ProductionMapNode node;
  final int frameCount;

  @override
  State<_RezkaNodeEditSheet> createState() => _RezkaNodeEditSheetState();
}

class _RezkaNodeEditSheetState extends State<_RezkaNodeEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _kadrCount;
  late final TextEditingController _labelLength;
  late bool _byFrame;
  late List<int> _frameGroups;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.node.title);
    _kadrCount = TextEditingController(
      text: widget.node.rezkaKadrCount?.toString() ?? '',
    );
    _labelLength = TextEditingController(
      text: widget.node.rezkaLabelLength == null
          ? ''
          : _formatRezkaNumber(widget.node.rezkaLabelLength!),
    );
    _byFrame = widget.node.rezkaFrameGroups.isNotEmpty;
    _frameGroups = widget.node.rezkaFrameGroups.isNotEmpty
        ? List<int>.from(widget.node.rezkaFrameGroups)
        : List<int>.filled(widget.frameCount, 1, growable: true);
  }

  @override
  void dispose() {
    _title.dispose();
    _kadrCount.dispose();
    _labelLength.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              'Rezka sozlash',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            _SheetField(label: 'Nomi', controller: _title),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Buyurtma bo‘yicha'),
                ),
                ButtonSegment(value: true, label: Text('Kadr bo‘yicha')),
              ],
              selected: {_byFrame},
              onSelectionChanged: (selection) {
                setState(() => _byFrame = selection.single);
              },
            ),
            const SizedBox(height: 10),
            if (_byFrame)
              _buildFrameGroups(context)
            else ...[
              _SheetField(
                label: 'Kadr soni',
                controller: _kadrCount,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              _SheetField(
                label: 'Etiketka uzunligi',
                controller: _labelLength,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
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

  Widget _buildFrameGroups(BuildContext context) {
    if (widget.frameCount <= 0) {
      return const Text('Kadr soni topilmadi');
    }
    var cursor = 1;
    final children = <Widget>[];
    for (var index = 0; index < _frameGroups.length; index++) {
      final count = _frameGroups[index];
      final start = cursor;
      final end = cursor + count - 1;
      children.add(
        _RezkaFrameCard(
          label: start == end ? 'Kadr $start' : 'Kadr $start-$end',
          merged: count > 1,
          onSplit: count > 1 ? () => _splitFrameGroup(index) : null,
        ),
      );
      cursor = end + 1;
      if (index < _frameGroups.length - 1) {
        children.add(
          IconButton.filledTonal(
            key: ValueKey('rezka-frame-join-$index'),
            tooltip: 'Jipslash',
            onPressed: () => _joinFrameGroups(index),
            icon: const Icon(Icons.join_inner_rounded),
          ),
        );
      }
    }
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }

  void _joinFrameGroups(int index) {
    if (index < 0 || index >= _frameGroups.length - 1) {
      return;
    }
    setState(() {
      _frameGroups[index] = _frameGroups[index] + _frameGroups[index + 1];
      _frameGroups.removeAt(index + 1);
    });
  }

  void _splitFrameGroup(int index) {
    if (index < 0 || index >= _frameGroups.length || _frameGroups[index] <= 1) {
      return;
    }
    setState(() {
      final count = _frameGroups[index];
      _frameGroups
        ..removeAt(index)
        ..insertAll(index, List<int>.filled(count, 1));
    });
  }

  void _save() {
    final kadrText = _kadrCount.text.trim();
    final labelText = _labelLength.text.trim().replaceAll(',', '.');
    final kadr = kadrText.isEmpty ? null : int.tryParse(kadrText);
    final label = labelText.isEmpty ? null : double.tryParse(labelText);
    if ((kadrText.isNotEmpty && (kadr == null || kadr <= 0)) ||
        (labelText.isNotEmpty && (label == null || label <= 0))) {
      showAdminTopNotice(context, 'Rezka qiymatlarini to‘g‘ri kiriting');
      return;
    }
    final title = _title.text.trim();
    Navigator.of(context).pop(
      ProductionMapNode(
        id: widget.node.id,
        kind: widget.node.kind,
        title: title.isEmpty ? 'Rezka' : title,
        formula: widget.node.formula,
        roleCode: widget.node.roleCode,
        itemCode: widget.node.itemCode,
        qtyFormula: widget.node.qtyFormula,
        fromLocation: widget.node.fromLocation,
        toLocation: widget.node.toLocation,
        alternativeGroupId: widget.node.alternativeGroupId,
        alternativeGroupLabel: widget.node.alternativeGroupLabel,
        alternativeAssignedTitle: widget.node.alternativeAssignedTitle,
        rezkaKadrCount: _byFrame ? widget.frameCount : kadr,
        rezkaLabelLength: _byFrame ? null : label,
        rezkaFrameGroups: _byFrame ? List<int>.from(_frameGroups) : const [],
        x: widget.node.x,
        y: widget.node.y,
      ),
    );
  }
}

class _RezkaFrameCard extends StatelessWidget {
  const _RezkaFrameCard({
    required this.label,
    required this.merged,
    required this.onSplit,
  });

  final String label;
  final bool merged;
  final VoidCallback? onSplit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: merged ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onSplit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: merged ? scheme.onPrimaryContainer : scheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ),
    );
  }
}

class _NodeEditSheetState extends State<_NodeEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _roleCode;
  late final TextEditingController _formulaTarget;
  late final TextEditingController _formulaExpression;

  @override
  void initState() {
    super.initState();
    final formula = widget.node.formula;
    _title = TextEditingController(text: widget.node.title);
    _roleCode = TextEditingController(text: widget.node.roleCode);
    _formulaTarget = TextEditingController(text: formula?.target ?? '');
    _formulaExpression = TextEditingController(text: formula?.expression ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _roleCode.dispose();
    _formulaTarget.dispose();
    _formulaExpression.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              'Node sozlash',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            _SheetField(label: 'Nomi', controller: _title),
            if (widget.node.kind == 'task') ...[
              const SizedBox(height: 10),
              _SheetField(label: 'Vazifa / role code', controller: _roleCode),
            ],
            if (widget.node.kind == 'formula') ...[
              const SizedBox(height: 10),
              _SheetField(label: 'Formula target', controller: _formulaTarget),
              const SizedBox(height: 10),
              _FormulaSheetField(
                label: 'Formula',
                controller: _formulaExpression,
              ),
            ],
            if (widget.node.kind == 'condition') ...[
              const SizedBox(height: 10),
              _FormulaSheetField(
                label: 'Shart',
                controller: _formulaExpression,
              ),
            ],
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

  void _save() {
    final title = _title.text.trim();
    final formulaTarget = _formulaTarget.text.trim();
    final formulaExpression = _formulaExpression.text.trim();
    Navigator.of(context).pop(
      ProductionMapNode(
        id: widget.node.id,
        kind: widget.node.kind,
        title: title.isEmpty ? widget.node.title : title,
        roleCode: _roleCode.text.trim(),
        x: widget.node.x,
        y: widget.node.y,
        formula:
            widget.node.kind == 'formula' || widget.node.kind == 'condition'
                ? ProductionFormula(
                    target: widget.node.kind == 'condition'
                        ? ''
                        : formulaTarget.isEmpty
                            ? 'result'
                            : formulaTarget,
                    expression: formulaExpression.isEmpty
                        ? widget.node.formula?.expression ?? 'order_qty'
                        : formulaExpression,
                  )
                : null,
      ),
    );
  }
}
