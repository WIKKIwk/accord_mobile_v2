import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../shared/models/app_models.dart';

typedef PaddonApparatusLoader = Future<List<AdminApparatus>> Function();

/// Display formatting only: batch identities and quantities remain unchanged.
class AparatchiPaddonDisplay {
  static String orderSummary(AdminProgressBatch batch) {
    final payloadNumber =
        batch.payloadJson['order_number']?.toString().trim() ?? '';
    final orderId = batch.orderId.trim();
    final number = payloadNumber.isNotEmpty
        ? payloadNumber
        : RegExp(r'^zakaz-(\d+)$').firstMatch(orderId)?.group(1) ??
            (RegExp(r'^\d+$').hasMatch(orderId) ? orderId : '—');
    final payloadTitle =
        batch.payloadJson['order_title']?.toString().trim() ?? '';
    final title = payloadTitle.isNotEmpty
        ? payloadTitle
        : batch.labelItemName
            .split(RegExp(r',\s*apparat:', caseSensitive: false))
            .first
            .replaceFirst(
              RegExp(
                r'\s+(?:yarim tayyor(?: mahsulot)?|tayyor mahsulot)\s*$',
                caseSensitive: false,
              ),
              '',
            )
            .trim();
    return '$number - ${title.isEmpty ? '—' : title}';
  }

  static String apparatusOrLocation(
    String value,
    List<AdminApparatus> catalog,
    AppLocalizations l10n,
  ) {
    String name(String id) {
      for (final apparatus in catalog) {
        if (apparatus.id.trim() == id ||
            apparatus.physicalAssetId.trim() == id ||
            apparatus.workUnitId.trim() == id) {
          final label = apparatus.name.trim();
          if (label.isNotEmpty && !label.contains('apparatus:')) return label;
        }
      }
      return l10n.adminText('wip.unspecified');
    }

    final text = value.trim();
    if (text.isEmpty) return '';
    return text.replaceAllMapped(
      RegExp(r'apparatus:[a-zA-Z0-9_.:-]+', caseSensitive: false),
      (match) => name(match[0]!),
    );
  }
}
