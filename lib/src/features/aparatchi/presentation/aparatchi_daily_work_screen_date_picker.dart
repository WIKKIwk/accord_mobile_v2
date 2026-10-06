part of 'aparatchi_daily_work_screen.dart';

class _DailyWorkDatePickerDialog extends StatefulWidget {
  const _DailyWorkDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_DailyWorkDatePickerDialog> createState() =>
      _DailyWorkDatePickerDialogState();
}

class _DailyWorkDatePickerDialogState
    extends State<_DailyWorkDatePickerDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  bool _inputMode = false;
  bool _validateInput = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  void _onDateChanged(DateTime date) {
    setState(() => _selectedDate = date);
  }

  void _toggleEntryMode() {
    if (_inputMode) {
      _formKey.currentState?.save();
    }
    setState(() {
      _inputMode = !_inputMode;
      _validateInput = false;
    });
  }

  void _confirm() {
    if (_inputMode) {
      final form = _formKey.currentState!;
      if (!form.validate()) {
        setState(() => _validateInput = true);
        return;
      }
      form.save();
    }
    Navigator.of(context).pop(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    final pickerTheme = DatePickerTheme.of(context);
    final defaults = DatePickerTheme.defaults(context);
    final localizations = MaterialLocalizations.of(context);
    final actionStyles = m3ConfirmDialogActionStyles(context: context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: pickerTheme.backgroundColor ?? defaults.backgroundColor,
      shape: pickerTheme.shape ?? defaults.shape,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.productionText(
                              'worker.daily.choose_date.title',
                            ),
                            style: pickerTheme.headerHelpStyle ??
                                defaults.headerHelpStyle,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  localizations.formatMediumDate(_selectedDate),
                                  style: (pickerTheme.headerHeadlineStyle ??
                                          defaults.headerHeadlineStyle)
                                      ?.copyWith(
                                    color: pickerTheme.headerForegroundColor ??
                                        defaults.headerForegroundColor,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _toggleEntryMode,
                                tooltip: _inputMode
                                    ? localizations.calendarModeButtonLabel
                                    : localizations.inputDateModeButtonLabel,
                                icon: Icon(
                                  _inputMode
                                      ? Icons.calendar_today
                                      : Icons.edit_outlined,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: pickerTheme.dividerColor ?? defaults.dividerColor,
                    ),
                    if (_inputMode)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: _validateInput
                              ? AutovalidateMode.always
                              : AutovalidateMode.disabled,
                          child: InputDatePickerFormField(
                            initialDate: _selectedDate,
                            firstDate: widget.firstDate,
                            lastDate: widget.lastDate,
                            autofocus: true,
                            onDateSubmitted: _onDateChanged,
                            onDateSaved: _onDateChanged,
                          ),
                        ),
                      )
                    else
                      CalendarDatePicker(
                        initialDate: _selectedDate,
                        firstDate: widget.firstDate,
                        lastDate: widget.lastDate,
                        onDateChanged: _onDateChanged,
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: actionStyles.cancel,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          context.l10n.productionText('worker.action.cancel'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: actionStyles.confirm,
                        onPressed: _confirm,
                        child: Text(
                          context.l10n.productionText('worker.action.select'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
