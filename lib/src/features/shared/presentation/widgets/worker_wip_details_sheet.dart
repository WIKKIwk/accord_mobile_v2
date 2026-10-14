import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/feedback/rps_qr_reprint_sheet.dart';
import '../../../admin/presentation/widgets/admin_order_image_thumb.dart';
import '../../models/app_models.dart';
import 'worker_wip_details.dart';

/// The same WIP presentation for production history and pallet contents.
class WorkerWipDetailsSheet extends StatelessWidget {
  const WorkerWipDetailsSheet({
    super.key,
    required this.batch,
    required this.apparatusCatalog,
    required this.onReprint,
    required this.errorMessage,
    this.viewer,
    this.orderNumber = '',
    this.productName = '',
    this.orderImageId = '',
    this.previewKey,
    this.reprintButtonKey = const ValueKey('worker-wip-reprint'),
  });

  final AdminProgressBatch batch;
  final List<AdminApparatus> apparatusCatalog;
  final Future<String?> Function()? onReprint;
  final String Function(Object) errorMessage;
  final SessionProfile? viewer;
  final String orderNumber;
  final String productName;
  final String orderImageId;
  final Key? previewKey;
  final Key reprintButtonKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final number = _firstNonEmpty([
      orderNumber,
      batch.payloadJson['order_number']?.toString() ?? '',
      RegExp(r'^zakaz-(\d+)$').firstMatch(batch.orderId.trim())?.group(1) ?? '',
      if (RegExp(r'^\d+$').hasMatch(batch.orderId.trim())) batch.orderId,
    ]);
    final name = _firstNonEmpty([
      productName,
      batch.payloadJson['order_title']?.toString() ?? '',
      batch.labelItemName
          .split(RegExp(r',?\s*apparat:', caseSensitive: false))
          .first
          .replaceFirst(
            RegExp(r'\s+(?:yarim tayyor(?: mahsulot)?|tayyor mahsulot)\s*$',
                caseSensitive: false),
            '',
          ),
      l10n.productionText('worker.daily.wip'),
    ]);
    final title = [if (number.isNotEmpty) number, name].join(' • ');
    return RpsQrReprintSheet(
      title: l10n.productionText('worker.wip.history.title'),
      payload: batch.qrPayload.trim(),
      showPayload: false,
      itemName: title,
      itemHeader: _WorkerWipOrderHeader(
        batch: batch,
        title: title,
        imageId: orderImageId,
      ),
      details: const [],
      detailsContent: WorkerWipDetails(
        batch: batch,
        apparatusCatalog: apparatusCatalog,
        viewer: viewer,
      ),
      previewKey: previewKey,
      reprintButtonKey: reprintButtonKey,
      onReprint: onReprint,
      errorMessage: errorMessage,
      successMessage: l10n.productionText('worker.daily.wip_qr.reprinted'),
    );
  }
}

String _firstNonEmpty(Iterable<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

class _WorkerWipOrderHeader extends StatefulWidget {
  const _WorkerWipOrderHeader({
    required this.batch,
    required this.title,
    required this.imageId,
  });

  final AdminProgressBatch batch;
  final String title;
  final String imageId;

  @override
  State<_WorkerWipOrderHeader> createState() => _WorkerWipOrderHeaderState();
}

class _WorkerWipOrderHeaderState extends State<_WorkerWipOrderHeader> {
  late final String _imageUrl;
  late final Future<Uint8List?> _image;

  @override
  void initState() {
    super.initState();
    final orderId = widget.batch.orderId.trim();
    _imageUrl = orderId.isEmpty
        ? ''
        : MobileApi.instance
            .adminProductionMapOrderImageUrl(orderId, imageId: widget.imageId);
    _image = _imageUrl.isEmpty
        ? Future.value()
        : MobileApi.instance.cachedOrderImageBytes(_imageUrl, thumbnail: true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _image,
      builder: (context, snapshot) => Row(
        key: ValueKey('worker-wip-order-header-${widget.batch.batchId}'),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (snapshot.data?.isNotEmpty == true) ...[
            AdminOrderImageThumb(
              key: ValueKey('worker-wip-order-image-${widget.batch.batchId}'),
              imageUrl: _imageUrl,
              displayName: widget.title,
              heroTag: 'worker-wip-order-image-${widget.batch.batchId}',
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
