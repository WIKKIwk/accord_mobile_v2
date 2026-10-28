part of 'admin_calculate_screen.dart';

extension _CalculateCombo on _AdminCalculateScreenState {
  bool get _needsComboIdentity =>
      _multipleProducts &&
      !widget.trainingMode &&
      (widget.openedOrder == null || _combo != null);

  bool get _hasCurrentCombo {
    if (_combo == null || _comboScope != currentSessionReadScope()) {
      return false;
    }
    try {
      return _comboLayoutSignature ==
          productionComboLayoutSignature(_buildTemplateDraft());
    } on FormatException {
      return false;
    }
  }

  Future<bool> _persistCalculatedCombo({
    required CalculateOrderTemplate draft,
    required String calculationSignature,
    required String scope,
  }) async {
    if (!_needsComboIdentity || _hasCurrentCombo) return true;
    var name = _combo?.name;
    if (name == null || name.trim().isEmpty) {
      name = await showDialog<String>(
        context: context,
        builder: (_) => const _ComboNameDialog(),
      );
    }
    if (!mounted ||
        scope != currentSessionReadScope() ||
        calculationSignature != _calculationSignature() ||
        name == null) {
      return false;
    }
    final previous = _combo;
    final saved = await MobileApi.instance.adminSaveProductionCombo(
      name: name,
      template: draft,
      comboId: previous?.id,
    );
    if (!mounted ||
        scope != currentSessionReadScope() ||
        calculationSignature != _calculationSignature()) {
      return false;
    }
    _updateComboState(() {
      _combo = saved;
      _comboScope = scope;
      _comboLayoutSignature = productionComboLayoutSignature(draft);
    });
    if (previous?.itemCode != saved.itemCode) {
      M3AsyncPickerSheet.clearMemoryCache();
      MobileApi.instance.invalidateProductionComboCatalog();
      QolipDataRevision.notifyLocationsChanged();
    }
    if (previous != null && previous.itemCode != saved.itemCode) {
      showAdminTopNotice(
          context, context.l10n.adminText('calculate.combo_new_revision'),
          tone: AdminTopNoticeTone.success);
    }
    return true;
  }

  Future<void> _selectCatalogCombo(SupplierItem item) async {
    if (_calculating || _loadingCombo || widget.openedOrder != null) return;
    final scope = currentSessionReadScope();
    final generation = ++_productCustomerGeneration;
    _updateComboState(() => _loadingCombo = true);
    try {
      final entry = await MobileApi.instance.adminProductionCombo(item.code);
      if (!mounted ||
          scope != currentSessionReadScope() ||
          generation != _productCustomerGeneration) {
        return;
      }
      if (entry.template.products.isEmpty) {
        throw const FormatException('Kombo tarkibi topilmadi');
      }
      _updateComboState(() {
        _productCustomerGeneration++;
        _editingAllFields = true;
        // Reusing a catalog definition opens a fresh order; it is never a child SKU.
        _applyTemplate(entry.template.copyWith(
            combo: entry.combo,
            id: '',
            code: '',
            sourceMapId: '',
            variantId: '',
            orderNumber: ''));
      });
    } catch (error) {
      if (mounted && scope == currentSessionReadScope()) {
        showAdminTopNotice(
            context,
            error is MobileApiException
                ? error.message
                : context.l10n.adminText('calculate.combo_load_failed'),
            tone: AdminTopNoticeTone.error);
      }
    } finally {
      if (mounted) _updateComboState(() => _loadingCombo = false);
    }
  }

  Widget _comboIdentityCard() {
    final combo = _combo;
    if (combo == null || !_multipleProducts) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Chip(
            label: Text(
                '${context.l10n.adminText('calculate.combo')} · v${combo.revision}')),
        Text(combo.name, style: Theme.of(context).textTheme.titleMedium),
        if (!_hasCurrentCombo)
          Text(context.l10n.adminText('calculate.combo_recalculate')),
      ]),
    );
  }
}

class _ComboNameDialog extends StatefulWidget {
  const _ComboNameDialog();
  @override
  State<_ComboNameDialog> createState() => _ComboNameDialogState();
}

class _ComboNameDialogState extends State<_ComboNameDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitted = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitted || _formKey.currentState?.validate() != true) return;
    _submitted = true;
    Navigator.of(context).pop(_controller.text.trim());
  }

  void _cancel() {
    if (_submitted) return;
    _submitted = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(context.l10n.adminText('calculate.combo_name_title')),
        content: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(context.l10n.adminText('calculate.combo_name_hint')),
              const SizedBox(height: 12),
              TextFormField(
                  key: const ValueKey('combo-name-input'),
                  controller: _controller,
                  autofocus: true,
                  maxLength: 160,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                      labelText:
                          context.l10n.adminText('calculate.combo_name')),
                  validator: (value) => value?.trim().isNotEmpty == true
                      ? null
                      : context.l10n.adminText('calculate.combo_name_required'),
                  onFieldSubmitted: (_) => _submit()),
            ])),
        actions: [
          TextButton(
              key: const ValueKey('combo-name-cancel'),
              onPressed: _cancel,
              child: Text(context.l10n.adminText('action.cancel'))),
          FilledButton(
              key: const ValueKey('combo-name-confirm'),
              onPressed: _submit,
              child: Text(context.l10n.adminText('action.save'))),
        ],
      );
}
