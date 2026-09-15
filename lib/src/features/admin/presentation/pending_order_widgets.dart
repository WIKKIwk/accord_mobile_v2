import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import 'admin_calculate_screen.dart';

class PendingOrderCard extends StatelessWidget {
  const PendingOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.slot = M3SegmentVerticalSlot.top,
  });
  final PendingOrder order;
  final VoidCallback onTap;
  final M3SegmentVerticalSlot slot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle =
        '${order.template.customer} · ${order.template.kg} kg · Chala buyurtma';
    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      onTap: onTap,
      child: ListTile(
        leading: Icon(
          Icons.pending_actions_rounded,
          color: scheme.onSurfaceVariant,
        ),
        title:
            Text('№${order.template.orderNumber} · ${order.template.product}'),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Icon(
          Icons.info_outline_rounded,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class PendingOrderDetailSheet extends StatefulWidget {
  const PendingOrderDetailSheet({super.key, required this.order});
  final PendingOrder order;
  @override
  State<PendingOrderDetailSheet> createState() =>
      _PendingOrderDetailSheetState();
}

class _PendingOrderDetailSheetState extends State<PendingOrderDetailSheet> {
  late final Future<Uint8List> _image =
      MobileApi.instance.pendingOrderImage(widget.order.id);
  bool _opening = false;
  @override
  Widget build(BuildContext context) {
    final t = widget.order.template;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            18, 12, 18, 18 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                      child: Text('№${t.orderNumber} · Chala buyurtma',
                          style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close)),
                ]),
                FutureBuilder<Uint8List>(
                    future: _image,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Rasm yuklanmadi'));
                      }
                      if (!snapshot.hasData) {
                        return const SizedBox(
                            height: 80,
                            child: Center(child: CircularProgressIndicator()));
                      }
                      return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(snapshot.data!,
                              height: 180, fit: BoxFit.contain));
                    }),
                const SizedBox(height: 16),
                for (final row in <(String, String)>[
                  ('Mijoz', t.customer),
                  ('Mahsulot', t.product),
                  ('Holat', t.status),
                  ('Tiraj', '${t.kg} kg'),
                  ('1 kadrdagi o‘lcham', '${t.frameProductSizeMm} mm'),
                  ('Kadr soni', '${t.frameCount} ta'),
                  (
                    'Material',
                    t.effectiveLayers
                        .map((l) => '${l.material} ${l.micron}')
                        .join(' + ')
                  ),
                  ('Menejer', widget.order.managerName),
                ])
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 125, child: Text(row.$1)),
                          Expanded(
                              child: Text(row.$2, textAlign: TextAlign.end))
                        ],
                      )),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _opening
                      ? null
                      : () async {
                          setState(() => _opening = true);
                          final completed = await Navigator.of(context)
                              .push<bool>(MaterialPageRoute(
                                  builder: (_) => AdminCalculateScreen(
                                      template: t,
                                      pendingOrderId: widget.order.id)));
                          if (!context.mounted) return;
                          if (completed == true) {
                            Navigator.pop(context, true);
                          } else {
                            setState(() => _opening = false);
                          }
                        },
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: const Color(0xFF7043A5)),
                  child: const Text('Order ochishni tugallash'),
                ),
              ]),
        ),
      ),
    );
  }
}
