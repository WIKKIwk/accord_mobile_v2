part of 'admin_item_detail_screen.dart';

class _CustomerManageButton extends StatelessWidget {
  const _CustomerManageButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const ValueKey('admin-item-detail-manage-customers'),
          onPressed: onPressed,
          icon: const Icon(Icons.group_add_rounded),
          label: const Text('Customerlarni boshqarish'),
        ),
      ),
    );
  }
}

class _ItemGroupPickerSheet extends StatefulWidget {
  const _ItemGroupPickerSheet({
    required this.groups,
    required this.currentGroup,
  });

  final List<String> groups;
  final String currentGroup;

  @override
  State<_ItemGroupPickerSheet> createState() => _ItemGroupPickerSheetState();
}

class _ItemGroupPickerSheetState extends State<_ItemGroupPickerSheet> {
  late final TextEditingController _searchController;
  late final List<String> _groups;
  late String _selectedGroup;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    final groupsByKey = <String, String>{};
    for (final value in <String>[widget.currentGroup, ...widget.groups]) {
      final group = value.trim();
      if (group.isNotEmpty) {
        groupsByKey.putIfAbsent(group.toLowerCase(), () => group);
      }
    }
    _groups = groupsByKey.values.toList()
      ..sort(
          (left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
    _selectedGroup = widget.currentGroup.trim();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = _groups
        .where((group) => query.isEmpty || group.toLowerCase().contains(query))
        .toList(growable: false);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.74,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Text(
              'Item groupni tanlang',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const ValueKey('admin-item-group-search'),
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                labelText: 'Guruhni qidirish',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: visible.isEmpty
                ? const Center(child: Text('Guruh topilmadi'))
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final group = visible[index];
                      final selected =
                          group.toLowerCase() == _selectedGroup.toLowerCase();
                      return ListTile(
                        key: ValueKey('admin-item-group-option-$group'),
                        selected: selected,
                        leading: Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                        ),
                        title: Text(group),
                        onTap: () => setState(() => _selectedGroup = group),
                      );
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              MediaQuery.paddingOf(context).bottom + 16,
            ),
            child: FilledButton(
              key: const ValueKey('admin-item-group-apply'),
              onPressed: _selectedGroup.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_selectedGroup),
              child: const Text('Guruhni saqlash'),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _SetCustomerAssigned = Future<AdminItemDetail> Function({
  required CustomerDirectoryEntry customer,
  required bool assigned,
});

class _ItemCustomerPickerSheet extends StatefulWidget {
  const _ItemCustomerPickerSheet({
    required this.detail,
    required this.loadCustomers,
    required this.onSetAssigned,
  });

  final AdminItemDetail detail;
  final AdminCustomersLoader loadCustomers;
  final _SetCustomerAssigned onSetAssigned;

  @override
  State<_ItemCustomerPickerSheet> createState() =>
      _ItemCustomerPickerSheetState();
}

class _ItemCustomerPickerSheetState extends State<_ItemCustomerPickerSheet> {
  late final TextEditingController _searchController;
  late AdminItemDetail _currentDetail;
  late Map<String, CustomerDirectoryEntry> _selectedByRef;
  List<CustomerDirectoryEntry> _customers = const [];
  bool _loading = true;
  Object? _error;
  String? _pendingRef;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _currentDetail = widget.detail;
    _selectedByRef = {
      for (final customer in widget.detail.customers)
        customer.ref.trim().toLowerCase(): customer,
    };
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loaded = await widget.loadCustomers(
        query: _searchController.text.trim(),
        limit: 200,
        offset: 0,
      );
      if (!mounted) {
        return;
      }
      final byRef = <String, CustomerDirectoryEntry>{..._selectedByRef};
      for (final customer in loaded) {
        final ref = customer.ref.trim().toLowerCase();
        if (ref.isNotEmpty) {
          byRef[ref] = customer;
        }
      }
      final customers = byRef.values.toList()
        ..sort(
          (left, right) => left.name.toLowerCase().compareTo(
                right.name.toLowerCase(),
              ),
        );
      setState(() {
        _customers = customers;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  Future<void> _toggle(CustomerDirectoryEntry customer, bool assigned) async {
    final refKey = customer.ref.trim().toLowerCase();
    if (refKey.isEmpty || _pendingRef != null) {
      return;
    }
    setState(() => _pendingRef = refKey);
    try {
      final updated = await widget.onSetAssigned(
        customer: customer,
        assigned: assigned,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _currentDetail = updated;
        _selectedByRef = {
          for (final entry in updated.customers)
            entry.ref.trim().toLowerCase(): entry,
        };
      });
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Customer saqlanmadi: $message')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pendingRef = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.84,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Text(
              'Customerlarni boshqarish',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const ValueKey('admin-item-customer-search'),
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                labelText: 'Customer qidirish',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Qidirish',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildContent()),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              MediaQuery.paddingOf(context).bottom + 16,
            ),
            child: FilledButton(
              key: const ValueKey('admin-item-customer-done'),
              onPressed: _pendingRef == null
                  ? () => Navigator.of(context).pop(_currentDetail)
                  : null,
              child: const Text('Tayyor'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_error != null) {
      return AppRetryState(
        onRetry: _load,
        message: 'Customerlar yuklanmadi',
      );
    }
    if (_customers.isEmpty) {
      return const Center(child: Text('Customer topilmadi'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _customers.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final customer = _customers[index];
        final refKey = customer.ref.trim().toLowerCase();
        final selected = _selectedByRef.containsKey(refKey);
        final pending = _pendingRef == refKey;
        return CheckboxListTile(
          key: ValueKey('admin-item-customer-option-${customer.ref}'),
          value: selected,
          onChanged: _pendingRef == null
              ? (value) => _toggle(customer, value ?? false)
              : null,
          secondary: pending
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const CircleAvatar(child: Icon(Icons.business_rounded)),
          title:
              Text(customer.name.trim().isEmpty ? customer.ref : customer.name),
          subtitle: Text(
            <String>[customer.ref, customer.phone]
                .where((value) => value.trim().isNotEmpty)
                .join(' • '),
          ),
          controlAffinity: ListTileControlAffinity.trailing,
        );
      },
    );
  }
}

class _AdminItemEditDraft {
  const _AdminItemEditDraft({required this.code, required this.name});

  final String code;
  final String name;
}

class _AdminItemEditDialog extends StatefulWidget {
  const _AdminItemEditDialog({required this.detail});

  final AdminItemDetail detail;

  @override
  State<_AdminItemEditDialog> createState() => _AdminItemEditDialogState();
}

class _AdminItemEditDialogState extends State<_AdminItemEditDialog> {
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.detail.code);
    _nameController = TextEditingController(text: widget.detail.name);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final code = _codeController.text.trim();
    final name = _nameController.text.trim();
    if (code.isEmpty || name.isEmpty) {
      setState(() {
        _validationMessage =
            code.isEmpty ? 'Item code kiriting' : 'Item nomini kiriting';
      });
      return;
    }
    Navigator.of(context).pop(_AdminItemEditDraft(code: code, name: name));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Itemni tahrirlash'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('admin-item-detail-code-field'),
              controller: _codeController,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('admin-item-detail-name-field'),
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'Nomi',
                border: OutlineInputBorder(),
              ),
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _validationMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(
          key: const ValueKey('admin-item-detail-save'),
          onPressed: _save,
          child: const Text('Saqlash'),
        ),
      ],
    );
  }
}
