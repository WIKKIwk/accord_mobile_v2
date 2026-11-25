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

mixin _ProductionRollNotes<W extends StatefulWidget, T> on _JournalState<W, T> {
  final _selectedRolls = <String, PreparationOutputNote?>{};
  final _savedRollNotes = <String, PreparationOutputNote>{};

  void clearRollNotes() {
    _selectedRolls.clear();
    _savedRollNotes.clear();
  }

  PreparationOutputNote? _rollNote(PreparationProductionRoll roll) =>
      _latestNote(roll.rollNote, _savedRollNotes[roll.receiptName]);

  void _toggleRoll(PreparationProductionRoll roll) {
    if (!currentAccount || roll.receiptName.isEmpty) return;
    setState(() {
      if (_selectedRolls.containsKey(roll.receiptName)) {
        _selectedRolls.remove(roll.receiptName);
      } else if (_selectedRolls.length < preparationNoteSelectionLimit) {
        _selectedRolls[roll.receiptName] = _rollNote(roll);
      }
    });
  }

  Future<void> _editRollNotes() async {
    if (!currentAccount || _selectedRolls.isEmpty) return;
    final selected = Map<String, PreparationOutputNote?>.of(_selectedRolls);
    for (final roll in items.whereType<PreparationProductionRoll>()) {
      if (selected.containsKey(roll.receiptName)) {
        selected[roll.receiptName] = _rollNote(roll);
      }
    }
    final revisions =
        selected.map((id, note) => MapEntry(id, note?.revision ?? 0));
    final saved = await _editProductionNote<Map<String, PreparationOutputNote>>(
      context,
      title: 'Rulon eslatmasi',
      description: '${selected.length} ta tanlangan rulonga eslatma qo‘yiladi.',
      existing: selected.values.toList(growable: false),
      currentAccount: () => mounted && currentAccount,
      save: (text, audience) => MobileApi.instance.savePreparationRollNotes(
        revisions, text, audience: audience,
      ),
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

Future<PreparationOutputNote?> _editProductionBatchNote(
  BuildContext context, {
  required String batchId,
  required PreparationOutputNote? note,
  required bool Function() currentAccount,
  required VoidCallback refresh,
}) =>
    _editProductionNote<PreparationOutputNote>(
      context,
      title: 'Batch eslatmasi',
      description:
          'Eslatma shu batchdagi har bir asl rulon kesilguncha amal qiladi.',
      existing: [note],
      currentAccount: currentAccount,
      save: (text, audience) => MobileApi.instance.savePreparationBatchNote(
        batchId, text, note?.revision ?? 0, audience: audience,
      ),
      refresh: refresh,
    );

Future<T?> _editProductionNote<T>(
  BuildContext context, {
  required String title,
  required String description,
  required List<PreparationOutputNote?> existing,
  required bool Function() currentAccount,
  required Future<T> Function(String?, PreparationNoteAudience?) save,
  required VoidCallback refresh,
}) async {
  final saved = await showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ProductionNoteDialog<T>(
      title: title,
      description: description,
      existing: existing,
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

class _ProductionNoteDialog<T> extends StatefulWidget {
  const _ProductionNoteDialog(
      {required this.title,
      required this.description,
      required this.existing,
      required this.currentAccount,
      required this.save,
      required this.refresh});

  final String title, description;
  final List<PreparationOutputNote?> existing;
  final bool Function() currentAccount;
  final Future<T> Function(String?, PreparationNoteAudience?) save;
  final VoidCallback refresh;

  @override
  State<_ProductionNoteDialog<T>> createState() =>
      _ProductionNoteDialogState<T>();
}

class _ProductionNoteDialogState<T> extends State<_ProductionNoteDialog<T>> {
  late final _existingText = widget.existing.map((note) => note?.text ?? '').toSet();
  late final _existingAudiences = widget.existing
      .map((note) => note?.audience ?? const PreparationNoteAudience.all())
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

  Future<void> _submit() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.save(_textUpdate, _audienceUpdate);
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

  @override
  Widget build(BuildContext context) => PopScope(
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
            FilledButton(
              key: const ValueKey('production-note-save'),
              onPressed: _canSave ? _submit : null,
              child: UrduAwareText(_saving ? 'Saqlanmoqda…' : 'Saqlash'),
            ),
          ],
        ),
      );

  @override
  void dispose() {
    AppSession.instance.revision.removeListener(_sessionChanged);
    _controller.dispose();
    super.dispose();
  }
}
