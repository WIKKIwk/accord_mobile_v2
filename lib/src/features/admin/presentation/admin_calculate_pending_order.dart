part of 'admin_calculate_screen.dart';

extension _PendingOrderCompletionForm on _AdminCalculateScreenState {
  List<Widget> _pendingOrderChildren(AppLocalizations l10n) {
    final source = widget.template!;
    return [
      _SectionHeader(
          title: '№${source.orderNumber} · Order ochishni tugallash'),
      const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
              'Telegramdan kiritilgan ma’lumotlar saqlanadi. Qolgan maydonlarni to‘ldiring.')),
      _NumberInput(
          controller: _wastePercent,
          label: l10n.adminText('calculate.waste_percent'),
          suffixText: '%',
          required: true,
          allowZero: true),
      if (source.rollCount == null)
        _IntegerInput(
            controller: _rollCount,
            label: l10n.adminText('calculate.roll_count'),
            suffixText: l10n.adminText('calculate.pieces_suffix')),
      if (source.color.trim().isEmpty)
        _TextInput(controller: _color, label: 'Rang (ixtiyoriy)'),
      if (source.note.trim().isEmpty)
        _TextInput(
            controller: _note,
            label: l10n.adminText('calculate.note'),
            minLines: 3,
            maxLines: 5),
      if (source.printValSizeMm == null) ..._printValChildren(l10n),
      const SizedBox(height: 20),
      if (_error.isNotEmpty) _ErrorPanel(message: _error),
      FilledButton(
        onPressed: _calculating
            ? null
            : () async {
                await _calculate();
                if (mounted && _hasFreshCalculation) await _openProductionMap();
              },
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(_calculating ? 'Hisoblanmoqda…' : 'Davom etish'),
      ),
    ];
  }
}
