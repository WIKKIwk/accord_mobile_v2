part of 'aparatchi_paddon_detail_screen.dart';

class _PaddonWipOrderHeader extends StatefulWidget {
  const _PaddonWipOrderHeader({required this.batch, required this.title});

  final AdminProgressBatch batch;
  final String title;

  @override
  State<_PaddonWipOrderHeader> createState() => _PaddonWipOrderHeaderState();
}

class _PaddonWipOrderHeaderState extends State<_PaddonWipOrderHeader> {
  late final String _imageUrl;
  late final Future<Uint8List?> _image;

  @override
  void initState() {
    super.initState();
    final orderId = widget.batch.orderId.trim();
    _imageUrl = orderId.isEmpty
        ? ''
        : MobileApi.instance.adminProductionMapOrderImageUrl(orderId);
    _image = _imageUrl.isEmpty
        ? Future.value()
        : MobileApi.instance.cachedOrderImageBytes(_imageUrl, thumbnail: true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _image,
      builder: (context, snapshot) => Row(
        key: ValueKey('paddon-wip-order-header-${widget.batch.batchId}'),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (snapshot.data?.isNotEmpty == true) ...[
            AdminOrderImageThumb(
              key: ValueKey('paddon-wip-order-image-${widget.batch.batchId}'),
              imageUrl: _imageUrl,
              displayName: widget.title,
              heroTag: 'paddon-wip-order-image-${widget.batch.batchId}',
              dimension: 40,
              previewOnLongPress: false,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              widget.title,
              textAlign: TextAlign.start,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
