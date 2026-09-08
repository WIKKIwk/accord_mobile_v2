import 'package:flutter/material.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/lists/app_segment_surface_card.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../admin/presentation/widgets/admin_surface_tab_bar.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../models/preparation_models.dart';
import 'preparation_navigation.dart';

part 'preparation_screen_forms.dart';

class PreparationScreen extends StatefulWidget {
  const PreparationScreen({super.key});
  @override
  State<PreparationScreen> createState() => _PreparationScreenState();
}

class _PreparationScreenState extends State<PreparationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  PreparationSnapshot? _snapshot;
  PreparationPendingCommand? _pending;
  PreparationOrder? _order;
  String? _warehouse, _error;
  bool _loading = true, _saving = false;
  int _tab = 0;
  final Map<String, TextEditingController> _percent = {};
  bool get _locked => _loading || _saving || _pending != null;
  void _update(VoidCallback action) => setState(action);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _percent.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final pending = await MobileApi.instance.preparationPendingCommand();
      if (mounted) setState(() => _pending = pending);
      final snapshot = await MobileApi.instance.preparationSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        if (!snapshot.warehouses.contains(_warehouse)) {
          _warehouse = snapshot.warehouses.length == 1
              ? snapshot.warehouses.first
              : null;
        }
        if (_order != null) {
          final fresh =
              snapshot.orders.where((o) => o.id == _order!.id).firstOrNull;
          if (fresh == null || fresh.saved) {
            _clearRecipe();
          } else {
            _order = fresh;
          }
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearRecipe() {
    _order = null;
    for (final c in _percent.values) {
      c.dispose();
    }
    _percent.clear();
  }

  Future<void> _submit(String kind, Map<String, dynamic> payload) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await MobileApi.instance.preparationSubmit(kind, payload);
      if (!mounted) return;
      if (kind == 'consumptions') setState(_clearRecipe);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saqlandi')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        await _reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _snapshot;
    return AppShell(
        title: 'Tayyorlov masteri',
        subtitle: 'Ichki homashyo ta’minoti',
        drawer: const PreparationDrawer(),
        bottom: const PreparationDock(),
        actions: [
          IconButton(
              tooltip: 'Yangilash',
              onPressed: _saving || _loading ? null : _reload,
              icon: const Icon(Icons.refresh))
        ],
        child: data == null && _loading
            ? const Center(child: AppLoadingIndicator())
            : AppRefreshIndicator(
                onRefresh: () async {
                  if (!_saving && !_loading) await _reload();
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
                  children: [
                    if (_error != null)
                      _surface(ListTile(
                          title: Text(_error!),
                          trailing: IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _loading ? null : _reload))),
                    if (_pending != null)
                      _surface(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                                'Oldingi operatsiya natijasi hali tasdiqlanmagan.'),
                            Text(_pending!.kind == 'receipts'
                                ? 'Kirim: ${_pending!.payload['kg']} kg'
                                : _pending!.kind == 'materials'
                                    ? 'Homashyo: ${_pending!.payload['name']}'
                                    : 'Order: ${_pending!.payload['order_id']}'),
                            const Text(
                                'Qayta tekshirish miqdorni ikkinchi marta sarflamaydi.'),
                            FilledButton(
                                onPressed: _saving
                                    ? null
                                    : () => _submit(
                                        _pending!.kind, _pending!.payload),
                                child: const Text('Natijani tekshirish')),
                          ])),
                    if (data != null) ...[
                      if (data.warehouses.isEmpty)
                        _surface(const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warehouse_outlined),
                            SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    'Sizga ombor biriktirilmagan. Admin foydalanuvchi kartasidan ombor biriktirishi kerak.')),
                          ],
                        ))
                      else
                        _surface(ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.warehouse_outlined),
                            title: Text(_warehouse ?? 'Ombor tanlang'),
                            trailing: const Icon(Icons.expand_more),
                            onTap: _locked ? null : _pickWarehouse)),
                      const SizedBox(height: 12),
                      AdminSurfaceTabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: const [
                          Tab(text: 'Homashyo'),
                          Tab(text: 'Order'),
                          Tab(text: 'Tarix'),
                        ],
                        onTap: (index) => setState(() => _tab = index),
                      ),
                      const SizedBox(height: 16),
                      if (_loading) const LinearProgressIndicator(),
                      if (_tab == 0) ..._materials(data),
                      if (_tab == 1) ..._recipe(data),
                      if (_tab == 2) ..._history(data),
                    ],
                  ],
                )));
  }

  Widget _surface(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppSegmentSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          elevation: 0,
          child: child));

  List<Widget> _materials(PreparationSnapshot data) => [
        Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
                key: const Key('preparation-add-material'),
                onPressed: _locked ? null : _createMaterial,
                icon: const Icon(Icons.add),
                label: const Text('Homashyo qo‘shish'))),
        const SizedBox(height: 10),
        if (data.materials.isEmpty) const Text('Hali homashyo qo‘shilmagan.'),
        for (final material in data.materials)
          _surface(ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(material.name),
              subtitle: Text(
                  'Mavjud: ${preparationDisplay(material.available(_warehouse))} kg'),
              trailing: const Icon(Icons.add_circle_outline),
              onTap: _locked || _warehouse == null
                  ? null
                  : () => _receive(material))),
        const Text(
            'Kirim qilish uchun homashyo nomini bosing. Qoldiq — sarflash mumkin bo‘lgan miqdor.'),
      ];

  List<Widget> _history(PreparationSnapshot data) => [
        const Text(
            'Oxirgi 100 ta kirim va sarf. Saqlangan hisoblar o‘zgarmas tarix sifatida saqlanadi.'),
        const SizedBox(height: 12),
        if (data.history.isEmpty) const Text('Hali kirim yoki sarf yo‘q.'),
        for (final doc in data.history)
          _surface(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                doc['kind'] == 'receipt'
                    ? 'Kirim — ${doc['name']}'
                    : 'Sarf — ${doc['order_code']} ${doc['order_title']}',
                style: Theme.of(context).textTheme.titleMedium),
            Text('${doc['warehouse']}'),
            if (doc['kind'] == 'receipt')
              Text('${preparationDisplay(doc['kg'] as String)} kg'),
            if (doc['kind'] == 'consumption') ...[
              Text(
                  'Order: ${preparationDisplay(doc['order_kg'] as String)} kg'),
              for (final line in doc['lines'] as List)
                Text(
                    '${line['name']}: ${preparationDisplay(line['percent'] as String)}% → ${preparationDisplay(line['kg'] as String)} kg'),
            ],
            Text(DateTime.tryParse(doc['created_at']?.toString() ?? '')
                    ?.toLocal()
                    .toString()
                    .split('.')
                    .first ??
                ''),
          ])),
      ];
}
