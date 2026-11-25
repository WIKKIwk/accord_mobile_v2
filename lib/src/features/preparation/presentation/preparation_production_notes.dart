part of 'preparation_production_screen.dart';

const _selectableNoteRoles = [
  PreparationNoteViewerRole.rezkaMaster,
  PreparationNoteViewerRole.homashyoRezkachi,
  PreparationNoteViewerRole.rezkaWorker,
];

PreparationOutputNote? _latestNote(
    PreparationOutputNote? incoming, PreparationOutputNote? saved) {
  return saved != null && saved.revision > (incoming?.revision ?? 0)
      ? saved
      : incoming;
}

String _noteAudienceLabel(BuildContext context, PreparationNoteAudience? audience) {
  final l10n = AppLocalizations.of(context);
  if (audience == null) return l10n.uiText('Turli rollar tanlangan');
  final roles = audience.roles;
  if (roles == null) return l10n.uiText('Barcha rezka rollari');
  if (roles.isEmpty) return l10n.uiText('Faqat muallif');
  return PreparationNoteViewerRole.values
      .where(roles.contains)
      .map((role) => l10n.uiText(role.label))
      .join(', ');
}

typedef _ProductionNoteTarget = ({String label, PreparationOutputNote? note});

typedef _SaveProductionNotes = Future<Map<String, PreparationOutputNote>>
    Function(Map<String, int> revisions, String? text, {
  PreparationNoteAudience? audience,
});

mixin _ProductionRollNotes<W extends StatefulWidget, T> on _JournalState<W, T> {
  final _selectedRolls = <String, _ProductionNoteTarget>{};
  final _savedRollNotes = <String, PreparationOutputNote>{};

  void clearRollNotes() {
    _selectedRolls.clear();
    _savedRollNotes.clear();
  }

  PreparationOutputNote? _rollNote(PreparationProductionRoll roll) =>
      _latestNote(roll.rollNote, _savedRollNotes[roll.receiptName]);

  _ProductionNoteTarget _rollNoteTarget(PreparationProductionRoll roll) => (
        label: [
          _nonEmpty(roll.itemName, roll.itemCode, ''),
          roll.epc,
        ].where((part) => part.isNotEmpty).join(' • '),
        note: _rollNote(roll),
      );

  void _toggleRoll(PreparationProductionRoll roll) {
    if (!currentAccount || roll.receiptName.isEmpty) return;
    setState(() {
      if (_selectedRolls.containsKey(roll.receiptName)) {
        _selectedRolls.remove(roll.receiptName);
      } else if (_selectedRolls.length < preparationNoteSelectionLimit) {
        _selectedRolls[roll.receiptName] = _rollNoteTarget(roll);
      }
    });
  }

  Future<void> _editRollNotes() async {
    if (!currentAccount || _selectedRolls.isEmpty) return;
    final targets = Map<String, _ProductionNoteTarget>.of(_selectedRolls);
    for (final roll in items.whereType<PreparationProductionRoll>()) {
      if (targets.containsKey(roll.receiptName)) {
        targets[roll.receiptName] = _rollNoteTarget(roll);
      }
    }
    final saved = await _editProductionNote(
      context,
      title: 'Rulon eslatmasi',
      description: '${targets.length} ta rulon tanlandi.',
      targetName: 'rulon',
      targets: targets,
      currentAccount: () => mounted && currentAccount,
      save: MobileApi.instance.savePreparationRollNotes,
      refresh: () => unawaited(load()),
    );
    if (!mounted || !currentAccount || saved == null) return;
    setState(() {
      _savedRollNotes.addAll(saved);
      _selectedRolls.clear();
    });
    unawaited(load(silent: true));
  }

  List<AdminFabMenuAction> get _rollFabActions => [
    AdminFabMenuAction(
      title: 'Eslatma qo‘shish',
      icon: Icons.edit_note_rounded,
      onTap: _editRollNotes,
    ),
    AdminFabMenuAction(
      title: 'Paddonga biriktirish',
      icon: Icons.inventory_2_outlined,
      onTap: _attachRollsToPaddon,
    ),
    AdminFabMenuAction(
      title: 'Tanlovni bekor qilish',
      icon: Icons.close_rounded,
      onTap: () {
        if (mounted && currentAccount) setState(_selectedRolls.clear);
      },
    ),
  ];

  Future<void> _attachRollsToPaddon() async {
    if (!mounted || !currentAccount || _selectedRolls.isEmpty) return;
    final result = await _pickProductionPaddon(
      context,
      receiptNames: _selectedRolls.keys.toList(growable: false),
      currentAccount: () => mounted && currentAccount,
    );
    if (!mounted || !currentAccount || result == null) return;
    setState(() {
      for (final name in result.receiptNames) {
        _selectedRolls.remove(name);
      }
    });
  }

  Widget rollRow(
    PreparationProductionRoll roll,
    M3SegmentVerticalSlot slot, {
    bool showMaterial = false,
    String batchOrderId = '',
    PreparationOutputNote? batchNote,
  }) {
    final selecting = _selectedRolls.isNotEmpty;
    final selected = _selectedRolls.containsKey(roll.receiptName);
    final selectable = currentAccount && roll.receiptName.isNotEmpty;
    return _JournalListRow(
      key: ValueKey('production-roll:${roll.epc}'),
      slot: slot,
      icon: selected
          ? Icons.check_circle_rounded
          : selecting
              ? Icons.radio_button_unchecked_rounded
              : Icons.qr_code_2_rounded,
      title: showMaterial
          ? _nonEmpty(roll.itemName, roll.itemCode, roll.epc)
          : roll.epc,
      titleMaxLines: 2,
      subtitle: [
        if (showMaterial) roll.epc,
        if (showMaterial && roll.orderId.isNotEmpty)
          _orderLabel(roll.orderCode, roll.orderId, roll.orderTitle),
        '${_date(roll.printedAt)} • ${roll.warehouse}',
      ].join('\n'),
      metrics: [
        '${preparationDisplay(roll.netKg)} kg',
        if (roll.lengthM case final value?) '${preparationDisplay(value)} m',
        if (roll.widthMm case final value?) '${preparationDisplay(value)} mm',
        if (roll.micron case final value?) '${preparationDisplay(value)} mkm',
      ].join(' • '),
      onTap: !currentAccount
          ? null
          : selecting
              ? (selectable ? () => _toggleRoll(roll) : null)
              : () => _showRoll(
                  context, roll, _nonEmpty(roll.orderId, batchOrderId, ''),
                  batchNote: _latestNote(roll.batchNote, batchNote),
                  rollNote: _rollNote(roll)),
      onLongPress: selectable && !selecting ? () => _toggleRoll(roll) : null,
    );
  }
}

_ProductionNoteTarget _batchNoteTarget(
  PreparationProductionBatch batch,
  PreparationOutputNote? note,
) =>
    (
      label: [
        batch.displayItem,
        _date(batch.startedAt),
        batch.batchCode.isNotEmpty ? batch.batchCode : batch.id,
      ].where((part) => part.isNotEmpty).join(' • '),
      note: note,
    );

Future<Map<String, PreparationOutputNote>?> _editProductionBatchNotes(
  BuildContext context, {
  required Map<String, _ProductionNoteTarget> targets,
  required bool Function() currentAccount,
  required VoidCallback refresh,
}) =>
    _editProductionNote(
      context,
      title: 'Batch eslatmasi',
      description: targets.length == 1
          ? 'Eslatma shu batchdagi har bir asl rulon kesilguncha amal qiladi.'
          : '${targets.length} ta batch tanlandi. '
              'Eslatma asl rulonlar kesilguncha amal qiladi.',
      targetName: 'batch',
      targets: targets,
      currentAccount: currentAccount,
      save: MobileApi.instance.savePreparationBatchNotes,
      refresh: refresh,
    );

Future<Map<String, PreparationOutputNote>?> _editProductionNote(
  BuildContext context, {
  required String title,
  required String description,
  required String targetName,
  required Map<String, _ProductionNoteTarget> targets,
  required bool Function() currentAccount,
  required _SaveProductionNotes save,
  required VoidCallback refresh,
}) async {
  final saved = await showDialog<Map<String, PreparationOutputNote>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ProductionNoteDialog(
      title: title,
      description: description,
      targetName: targetName,
      targets: targets,
      currentAccount: currentAccount,
      save: save,
      refresh: refresh,
    ),
  );
  if (saved != null && context.mounted && currentAccount()) {
    showAdminTopNotice(
      context,
      AppLocalizations.of(context).uiText('Eslatma saqlandi'),
      tone: AdminTopNoticeTone.success,
    );
  }
  return saved;
}

class _ProductionNoteDialog extends StatefulWidget {
  const _ProductionNoteDialog({
    required this.title,
    required this.description,
    required this.targetName,
    required this.targets,
    required this.currentAccount,
    required this.save,
    required this.refresh,
  });

  final String title, description, targetName;
  final Map<String, _ProductionNoteTarget> targets;
  final bool Function() currentAccount;
  final _SaveProductionNotes save;
  final VoidCallback refresh;

  @override
  State<_ProductionNoteDialog> createState() => _ProductionNoteDialogState();
}

class _ProductionNoteDialogState extends State<_ProductionNoteDialog> {
  late final _existingText =
      widget.targets.values.map((target) => target.note?.text ?? '').toSet();
  late final _existingAudiences = widget.targets.values
      .map((target) => target.note?.audience ?? const PreparationNoteAudience.all())
      .toSet();
  late final _controller = TextEditingController(
    text: _existingText.length == 1 ? _existingText.single : '',
  );
  late PreparationNoteAudience? _audience =
      _existingAudiences.length == 1 ? _existingAudiences.single : null;
  bool _textEdited = false, _audienceExpanded = false, _saving = false, _conflict = false;
  String? _error;

  String get _text => _controller.text.trim();
  int get _length => _text.runes.length;
  String? get _textUpdate =>
      _textEdited && (_existingText.length != 1 || _existingText.single != _text)
          ? _text
          : null;
  PreparationNoteAudience? get _audienceUpdate =>
      _existingAudiences.length == 1 && _existingAudiences.single == _audience
          ? null
          : _audience;
  bool get _canSave =>
      !_saving &&
      !_conflict &&
      widget.currentAccount() &&
      _length <= preparationNoteLimit &&
      !_text.contains('\u0000') &&
      (_textUpdate != null || _audienceUpdate != null);

  @override
  void initState() {
    super.initState();
    AppSession.instance.revision.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (mounted &&
        !widget.currentAccount() &&
        ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  }

  bool _hasExistingText(_ProductionNoteTarget target) =>
      target.note?.text.trim().isNotEmpty == true;

  List<_ProductionNoteTarget> get _overwrittenNotes {
    final text = _textUpdate;
    if (text == null || widget.targets.length < 2) return const [];
    return widget.targets.values
        .where((target) => _hasExistingText(target) && target.note!.text != text)
        .toList(growable: false);
  }

  Future<void> _submit({bool onlyWithoutNotes = false}) async {
    if (!_canSave) return;
    final revisions = {
      for (final entry in widget.targets.entries)
        if (!onlyWithoutNotes || !_hasExistingText(entry.value))
          entry.key: entry.value.note?.revision ?? 0,
    };
    if (revisions.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved =
          await widget.save(revisions, _textUpdate, audience: _audienceUpdate);
      if (mounted && widget.currentAccount()) Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted || !widget.currentAccount()) return;
      final conflict = error is MobileApiException && error.statusCode == 409;
      if (conflict) widget.refresh();
      setState(() {
        _saving = false;
        _conflict = conflict;
        _error =
            error is MobileApiException ? error.message : 'Eslatma saqlanmadi';
      });
    }
  }

  void _setViewer(PreparationNoteViewerRole role, bool selected) {
    final roles = _audience?.roles
            ?.where(_selectableNoteRoles.contains)
            .toSet() ??
        <PreparationNoteViewerRole>{};
    if (selected) {
      roles.add(role);
    } else {
      roles.remove(role);
    }
    setState(() {
      _audience = PreparationNoteAudience.selected(roles);
      _error = null;
    });
  }

  Widget _overwriteWarning(List<_ProductionNoteTarget> overwritten) {
    final scheme = Theme.of(context).colorScheme;
    final operation = _text.isEmpty ? 'o‘chiriladi' : 'almashtiriladi';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        key: const ValueKey('production-note-overwrite-warning'),
        leading: const Icon(Icons.warning_amber_rounded),
        iconColor: scheme.onTertiaryContainer,
        collapsedIconColor: scheme.onTertiaryContainer,
        shape: const Border(),
        collapsedShape: const Border(),
        title: UrduAwareText(
          '${widget.targets.length} ta ${widget.targetName}dan '
          '${overwritten.length} tasining eslatmasi $operation.',
          style: TextStyle(color: scheme.onTertiaryContainer),
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        childrenPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
        children: [
          for (final target in overwritten)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: UrduAwareText(
                target.label,
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overwritten = _overwrittenNotes;
    final canWriteOnlyWithoutNotes = overwritten.isNotEmpty &&
        _text.isNotEmpty &&
        widget.targets.values.any((target) => !_hasExistingText(target));
    final saveLabel = overwritten.isEmpty
        ? 'Saqlash'
        : _text.isEmpty
            ? 'Hammasidan o‘chirish'
            : 'Hammasiga yozish';
    return PopScope(
        canPop: !_saving,
        child: AlertDialog(
          title: UrduAwareText(widget.title),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UrduAwareText(widget.description),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('production-note-input'),
                controller: _controller,
                autofocus: true,
                enabled: !_saving && !_conflict,
                minLines: 2,
                maxLines: 5,
                onChanged: (_) => setState(() {
                  _textEdited = true;
                  _error = null;
                }),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).uiText('Eslatma'),
                  counterText: '$_length / $preparationNoteLimit',
                  errorText: _error ??
                      (_length > preparationNoteLimit
                          ? 'Eslatma 2000 belgidan oshmasligi kerak'
                          : null),
                ),
              ),
              if (overwritten.isNotEmpty) ...[
                const SizedBox(height: 8),
                _overwriteWarning(overwritten),
              ],
              ListTile(
                key: const ValueKey('production-note-audience'),
                contentPadding: EdgeInsets.zero,
                title: const UrduAwareText('Kimga ko‘rinadi?'),
                subtitle: Text(_noteAudienceLabel(context, _audience)),
                trailing: Icon(_audienceExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded),
                onTap: _saving || _conflict ? null : () {
                  FocusScope.of(context).unfocus();
                  setState(() => _audienceExpanded = !_audienceExpanded);
                },
              ),
              if (_audienceExpanded)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final role in _selectableNoteRoles)
                      FilterChip(
                        key: ValueKey('production-note-audience-${role.code}'),
                        label: UrduAwareText(role.label),
                        selected: _audience?.roles?.contains(role) ?? false,
                        onSelected: _saving || _conflict
                            ? null
                            : (value) => _setViewer(role, value),
                      ),
                  ],
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const UrduAwareText('Bekor qilish'),
            ),
            if (canWriteOnlyWithoutNotes)
              TextButton(
                key: const ValueKey('production-note-save-without-notes'),
                onPressed: _canSave ? () => _submit(onlyWithoutNotes: true) : null,
                child: const UrduAwareText('Faqat eslatmasi yo‘qlariga yozish'),
              ),
            FilledButton(
              key: const ValueKey('production-note-save'),
              onPressed: _canSave ? _submit : null,
              child: UrduAwareText(_saving ? 'Saqlanmoqda…' : saveLabel),
            ),
          ],
        ),
      );
  }

  @override
  void dispose() {
    AppSession.instance.revision.removeListener(_sessionChanged);
    _controller.dispose();
    super.dispose();
  }
}
