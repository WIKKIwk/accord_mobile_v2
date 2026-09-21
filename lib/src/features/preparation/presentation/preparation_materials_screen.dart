part of 'preparation_screen.dart';

class PreparationMaterialsScreen extends StatefulWidget {
  const PreparationMaterialsScreen({super.key});
  @override
  State<PreparationMaterialsScreen> createState() =>
      _PreparationMaterialsScreenState();
}

class _PreparationMaterialsScreenState
    extends State<PreparationMaterialsScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  List<PreparationOwnedMaterial> _items = [];
  String? _error;
  bool _loading = true, _saving = false, _refreshing = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _message(Object error) => error is MobileApiException
      ? error.code == 'preparation_request_failed'
          ? 'Omborlar ro‘yxatini olib bo‘lmadi. Qayta urinib ko‘ring'
          : error.message
      : 'Homashyolar bilan amal bajarilmadi. Internet aloqasini tekshirib, qayta urinib ko‘ring';

  Future<void> _load({bool refresh = false}) async {
    if (_saving || _refreshing) return;
    setState(() {
      _loading = !refresh;
      _refreshing = true;
      _error = null;
    });
    try {
      final items = await MobileApi.instance.preparationOwnedMaterials();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _actions(PreparationOwnedMaterial material) async {
    if (_saving || _loading || _refreshing) return;
    final action = await showSpringBottomSheet<String>(
      context: context,
      builder: (_) => AppActionSheet<String>(
        title: material.name,
        actions: const [
          AppActionSheetAction(
            title: 'Nomini o‘zgartirish',
            icon: Icons.edit_outlined,
            value: 'rename',
          ),
          AppActionSheetAction(
            title: 'Omborga biriktirish',
            icon: Icons.warehouse_outlined,
            value: 'warehouses',
          ),
          AppActionSheetAction(
            title: 'O‘chirish',
            icon: Icons.delete_outline_rounded,
            value: 'delete',
            destructive: true,
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'warehouses') {
      await _editWarehouses(material);
      return;
    }
    String? name;
    if (action == 'rename') {
      name = await showDialog<String>(
          context: context,
          builder: (_) => _PreparationInputDialog(
              title: 'Homashyo nomini o‘zgartirish',
              label: 'Homashyo nomi',
              initialValue: material.name));
      if (!mounted || name == null) return;
    } else {
      final confirmed = await showM3ConfirmDialog(
          context: context,
          title: 'Homashyoni o‘chirish',
          message:
              '«${material.name}» o‘chirilsinmi? Faqat ishlatilmagan homashyo o‘chiriladi. Qoldiq, kirim yoki formula bo‘lsa, o‘chirish rad etiladi.',
          cancelLabel: 'Bekor qilish',
          confirmLabel: 'O‘chirish',
          destructive: true);
      if (!mounted || confirmed != true) return;
    }
    if (_saving || _loading) return;
    setState(() => _saving = true);
    try {
      if (action == 'rename') {
        final savedName = await MobileApi.instance
            .preparationRenameMaterial(itemCode: material.code, name: name!);
        if (!mounted) return;
        setState(() {
          _items = _items
              .map((item) => item.code == material.code
                  ? PreparationOwnedMaterial(
                      code: item.code,
                      name: savedName,
                      warehouses: item.warehouses)
                  : item)
              .toList()
            ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        });
      } else {
        await MobileApi.instance.preparationDeleteMaterial(material.code);
        if (!mounted) return;
        setState(
            () => _items.removeWhere((item) => item.code == material.code));
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'rename'
              ? 'Homashyo nomi o‘zgartirildi'
              : 'Homashyo o‘chirildi')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editWarehouses(PreparationOwnedMaterial material) async {
    if (_saving || _loading || _refreshing) return;
    setState(() => _saving = true);
    try {
      final snapshot = await MobileApi.instance.preparationSnapshot();
      if (!mounted) return;
      setState(() => _saving = false);
      final editable = snapshot.materialWarehouses.toSet();
      final selected = material.warehouses.toSet();
      final options = {...editable, ...selected}.toList()..sort();
      final warehouses = await showModalBottomSheet<List<String>>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheet) => StatefulBuilder(builder: (sheet, update) {
          final changed = selected.length != material.warehouses.length ||
              !selected.containsAll(material.warehouses);
          return SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.sizeOf(sheet).height * .65,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Omborga biriktirish',
                          style: Theme.of(sheet).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(material.name),
                      const SizedBox(height: 12),
                      Expanded(
                          child: options.isEmpty
                              ? const Center(
                                  child: Text(
                                      'Sizga exclusive ombor biriktirilmagan.'))
                              : ListView(children: [
                                  M3SegmentSpacedColumn(children: [
                                    for (var i = 0; i < options.length; i++)
                                      M3SegmentFilledSurface(
                                        slot: _slotFor(i, options.length),
                                        cornerRadius:
                                            M3SegmentedListGeometry.cornerLarge,
                                        child: CheckboxListTile(
                                          title: Text(options[i]),
                                          subtitle: editable
                                                  .contains(options[i])
                                              ? null
                                              : const Text(
                                                  'Bu biriktirishni faqat administrator o‘zgartira oladi'),
                                          value: selected.contains(options[i]),
                                          onChanged: !editable
                                                  .contains(options[i])
                                              ? null
                                              : (checked) => update(() {
                                                    if (checked == true) {
                                                      selected.add(options[i]);
                                                    } else {
                                                      selected
                                                          .remove(options[i]);
                                                    }
                                                  }),
                                        ),
                                      ),
                                  ]),
                                ])),
                      const SizedBox(height: 12),
                      const Text('Bu amal ombordagi qoldiqni ko‘chirmaydi.'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: !changed
                            ? null
                            : () =>
                                Navigator.pop(sheet, selected.toList()..sort()),
                        child: const Text('Saqlash'),
                      ),
                    ]),
              ),
            ),
          );
        }),
      );
      if (!mounted || warehouses == null) return;
      if (_saving || _loading || _refreshing) return;
      setState(() => _saving = true);
      final updated = await MobileApi.instance.preparationSetMaterialWarehouses(
          itemCode: material.code, warehouses: warehouses);
      if (!mounted) return;
      setState(() => _items = _items
          .map((item) => item.code == updated.code ? updated : item)
          .toList());
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ombor biriktirish yangilandi')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items
        .where((item) =>
            '${item.name} ${item.code} ${item.warehouses.join(' ')}'
                .toLowerCase()
                .contains(_query.trim().toLowerCase()))
        .toList();
    return AppShell(
      title: 'Homashyolar',
      subtitle: '',
      nativeTopBar: true,
      automaticallyImplyNativeLeading: false,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      profileActionListenable: _searchFocus,
      showProfileActionResolver: () => !_searchFocus.hasFocus,
      titleWidget: AdminCatalogSearchField(
        controller: _search,
        focusNode: _searchFocus,
        hintText: 'Homashyoni qidirish',
        onChanged: (query) => setState(() => _query = query),
        onClear: () {
          _search.clear();
          setState(() => _query = '');
        },
      ),
      contentPadding: EdgeInsets.zero,
      bottom: const PreparationDock(showPrimaryFab: false),
      child: Column(children: [
        if (_saving) const LinearProgressIndicator(),
        Expanded(
            child: _loading
                ? const Center(child: AppLoadingIndicator())
                : AppRefreshIndicator(
                    onRefresh: () => _load(refresh: true),
                    allowRefreshOnShortContent: true,
                    child: ListView(
                      physics: const TopRefreshScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(4, 4, 4,
                          MediaQuery.viewPaddingOf(context).bottom + 136),
                      children: [
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(children: [
                                Text(_error!),
                                TextButton(
                                    onPressed: _load,
                                    child: const Text('Qayta urinish')),
                              ])),
                        if (_error == null && items.isEmpty)
                          Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(_query.trim().isEmpty
                                  ? 'Hali homashyo yaratmagansiz.'
                                  : 'Homashyo topilmadi.')),
                        M3SegmentSpacedColumn(children: [
                          for (var i = 0; i < items.length; i++) ...[
                            Builder(builder: (_) {
                              final slot = M3SegmentedListGeometry
                                  .standaloneListSlotForIndex(i, items.length);
                              final scheme = Theme.of(context).colorScheme;
                              return AdminSummaryCard(
                                key: ValueKey(
                                    'preparation-material-${items[i].code}'),
                                slot: slot,
                                cornerRadius: M3SegmentedListGeometry
                                    .cornerRadiusForSlot(slot),
                                fixedHeight: 61,
                                padding: const EdgeInsets.fromLTRB(
                                    14, 8, 10, 8),
                                title: items[i].name,
                                subtitle: items[i].warehouses.isEmpty
                                    ? 'Ombor biriktirilmagan'
                                    : items[i].warehouses.join(', '),
                                value: '',
                                leading: SizedBox.square(
                                  dimension: 30,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: scheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.inventory_2_rounded,
                                      size: 16,
                                      color: scheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                                trailing: IconButton(
                                    tooltip: 'Homashyo amallari',
                                    icon: const Icon(Icons.more_vert),
                                    onPressed: _saving
                                        ? null
                                        : () => _actions(items[i])),
                                onTap:
                                    _saving ? null : () => _actions(items[i]),
                                titleMaxLines: 1,
                                subtitleMaxLines: 1,
                                titleStyle: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                subtitleStyle: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.05,
                                    ),
                              );
                            }),
                          ],
                        ]),
                      ],
                    ),
                  )),
      ]),
    );
  }
}
