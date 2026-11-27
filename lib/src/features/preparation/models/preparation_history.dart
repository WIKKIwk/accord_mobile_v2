import '../../shared/models/inventory_movement_models.dart';

class PreparationHistoryCursor {
  const PreparationHistoryCursor({required this.time, required this.key});

  final String time;
  final String key;
}

class PreparationHistoryPage {
  PreparationHistoryPage.fromJson(Map<String, dynamic> json)
      : entries = [
          for (final entry in json['entries'] as List)
            PreparationHistoryEntry.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
        ],
        nextCursor = switch (json['next_cursor']) {
          final Map cursor => PreparationHistoryCursor(
              time: cursor['time'] as String,
              key: cursor['key'] as String,
            ),
          _ => null,
        };

  final List<PreparationHistoryEntry> entries;
  final PreparationHistoryCursor? nextCursor;
}

class PreparationHistoryEntry {
  PreparationHistoryEntry.fromJson(Map<String, dynamic> json)
      : key = json['key'] as String,
        occurredAt = DateTime.parse(json['occurred_at'] as String).toLocal(),
        preparationReceivedAt =
            DateTime.tryParse(json['preparation_received_at'] as String? ?? '')
                ?.toLocal(),
        preparationReceipts = [
          for (final receipt
              in (json['preparation_receipts'] as List? ?? const []))
            PreparationTransferReceipt.fromJson(
                Map<String, dynamic>.from(receipt as Map)),
        ],
        transfer = switch (json['transfer']) {
          final Map transfer =>
            InventoryTransfer.fromJson(Map<String, dynamic>.from(transfer)),
          _ => null,
        },
        operation = switch (json['operation']) {
          final Map operation => Map<String, dynamic>.from(operation),
          _ => null,
        } {
    if ((transfer == null) == (operation == null)) {
      throw const FormatException('Tarix yozuvi tushunarsiz');
    }
  }

  final String key;
  final DateTime occurredAt;
  final DateTime? preparationReceivedAt;
  final List<PreparationTransferReceipt> preparationReceipts;
  final InventoryTransfer? transfer;
  final Map<String, dynamic>? operation;
}

class PreparationTransferReceipt {
  PreparationTransferReceipt.fromJson(Map<String, dynamic> json)
      : material = json['material']?.toString() ?? '',
        kg = json['kg']?.toString() ?? '',
        receivedAt = DateTime.parse(json['received_at'] as String).toLocal();

  final String material;
  final String kg;
  final DateTime receivedAt;
}
