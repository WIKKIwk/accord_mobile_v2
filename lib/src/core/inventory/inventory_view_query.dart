import 'dart:convert';

import '../../features/shared/models/inventory_movement_models.dart';

/// A bounded server-ordered window. Query identity is also cache identity.
class InventoryViewQuery {
  InventoryViewQuery._(this.kind, Map<String, String> parameters)
      : parameters = Map.unmodifiable(parameters);

  factory InventoryViewQuery.locations() =>
      InventoryViewQuery._('locations', {});

  factory InventoryViewQuery.assets({
    String warehouseId = '',
    String query = '',
    InventoryAssetKind? assetKind,
    bool currentUserStatesOnly = false,
    bool includeOrderAssignment = true,
    int limit = 100,
    int offset = 0,
  }) =>
      InventoryViewQuery._('assets', {
        if (warehouseId.trim().isNotEmpty) 'warehouse_id': warehouseId.trim(),
        if (query.trim().isNotEmpty) 'query': query.trim(),
        if (assetKind != null) 'asset_kind': assetKind.apiValue,
        if (currentUserStatesOnly) 'current_user_states_only': 'true',
        if (includeOrderAssignment) 'include_order_assignment': 'true',
        'limit': '$limit',
        if (offset > 0) 'offset': '$offset',
      });

  factory InventoryViewQuery.transfers({
    String direction = 'all',
    InventoryTransferStatus? status,
    int limit = 100,
    int offset = 0,
  }) =>
      InventoryViewQuery._('transfers', {
        'direction': direction,
        if (status != null) 'status': status.apiValue,
        'limit': '$limit',
        if (offset > 0) 'offset': '$offset',
      });

  final String kind;
  final Map<String, String> parameters;

  String get key => jsonEncode([kind, parameters]);

  // Keep only the most recently visited search in each inventory section live.
  String get liveBucket => switch (kind) {
        'assets' =>
          'assets:${parameters['current_user_states_only'] == 'true'}',
        'transfers' => 'transfers:${parameters['direction']}',
        _ => kind,
      };

  Object decode(Map<String, dynamic> row) => switch (kind) {
        'assets' => InventoryAsset.fromJson(row),
        'transfers' => InventoryTransfer.fromJson(row),
        'locations' => InventoryLocation.fromJson(row),
        _ => throw const FormatException('Unknown inventory view'),
      };

  String rowKey(Object row) => switch (row) {
        final InventoryAsset asset =>
          '${asset.kind.apiValue}:${asset.assetRef}',
        final InventoryTransfer transfer => transfer.id,
        final InventoryLocation location => location.id,
        _ => throw const FormatException('Unknown inventory row'),
      };

  Map<String, dynamic> subscription({String? version}) => {
        'id': 'window',
        'kind': kind,
        'query': {
          for (final entry in parameters.entries)
            entry.key: switch (entry.key) {
              'limit' || 'offset' => int.parse(entry.value),
              'current_user_states_only' ||
              'include_order_assignment' =>
                entry.value == 'true',
              _ => entry.value,
            },
        },
        if (version != null) 'version': version,
      };
}
