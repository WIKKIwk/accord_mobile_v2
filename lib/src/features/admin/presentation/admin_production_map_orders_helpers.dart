part of 'admin_production_map_orders_screen.dart';

String _openedOrderDisplayCode(ProductionMapDefinition map) {
  final code = map.code.trim();
  if (code.isNotEmpty) {
    return code;
  }
  final orderNumber = map.orderNumber.trim();
  if (orderNumber.isNotEmpty) {
    return orderNumber;
  }
  final id = map.id.trim();
  const prefix = 'zakaz-';
  if (id.startsWith(prefix)) {
    final suffix = id.substring(prefix.length).trim();
    if (suffix.isNotEmpty) {
      return suffix;
    }
  }
  return '';
}

String _openedOrderPrimaryTitle(
  ProductionMapDefinition map, {
  AppLocalizations? l10n,
}) {
  final title = map.title.trim();
  if (title.isNotEmpty) {
    return title;
  }
  final product = _openedOrderProductTitle(map);
  if (product.isNotEmpty) {
    return product;
  }
  return l10n?.productionText('worker.order.fallback') ?? 'Zakaz';
}

String _openedOrderProductTitle(ProductionMapDefinition map) {
  for (final node in map.nodes) {
    final title = node.title.trim();
    if (node.kind == 'end' && title.isNotEmpty && title != map.title.trim()) {
      return title;
    }
  }
  return '';
}

String _openedOrderSubtitle(
  ProductionMapDefinition map, {
  String customerName = '',
  bool includeApparatusCount = false,
  AppLocalizations? l10n,
}) {
  final productTitle = _openedOrderProductTitle(map);
  // Canonical customer authority: snapshot lookup first, map fallback
  // immediately. Never start empty and fill later (flicker).
  final lookupCustomer = customerName.trim();
  final customer =
      lookupCustomer.isNotEmpty ? lookupCustomer : map.customerName.trim();
  final apparatusCount =
      map.nodes.where((node) => node.kind == 'apparatus').length;
  final secondaryLabel = customer.isNotEmpty
      ? customer
      : map.productCode.trim().isNotEmpty
          ? map.productCode.trim()
          : productTitle;
  return [
    if (secondaryLabel.isNotEmpty) secondaryLabel,
    if (includeApparatusCount && apparatusCount > 0)
      l10n?.productionText(
            'worker.queue.apparatus_count',
            values: {'count': apparatusCount},
          ) ??
          '$apparatusCount ta aparat',
  ].join(' • ');
}

String _closedOrderDisplayCode(AdminClosedProductionOrder order) {
  final orderNumber = order.orderNumber.trim();
  if (orderNumber.isNotEmpty) {
    return orderNumber;
  }
  final id = order.orderId.trim();
  const prefix = 'zakaz-';
  if (id.startsWith(prefix)) {
    final suffix = id.substring(prefix.length).trim();
    if (suffix.isNotEmpty) {
      return suffix;
    }
  }
  return id;
}

String _completionRequestDisplayCode(
  AdminCompletionRequestNotification request,
) {
  final orderNumber = request.orderNumber.trim();
  if (orderNumber.isNotEmpty) {
    return orderNumber;
  }
  final id = request.orderId.trim();
  const prefix = 'zakaz-';
  if (id.startsWith(prefix)) {
    final suffix = id.substring(prefix.length).trim();
    if (suffix.isNotEmpty) {
      return suffix;
    }
  }
  return id;
}

String _closedOrderTitle(AdminClosedProductionOrder order) {
  final title = order.title.trim();
  if (title.isNotEmpty) {
    return title;
  }
  return 'Zakaz';
}

String _closedActorLabel({
  required String displayName,
  required String role,
  required String ref,
}) {
  final display = displayName.trim();
  if (display.isNotEmpty) {
    return display;
  }
  final actorRef = ref.trim();
  if (actorRef.isNotEmpty) {
    return actorRef;
  }
  final actorRole = role.trim();
  if (actorRole.isNotEmpty) {
    return actorRole;
  }
  return 'Noma’lum ijrochi';
}

String _closedLogActionLabel(String action) {
  return switch (action.trim()) {
    'start' => 'Boshladi',
    'pause' => 'Pauza qildi',
    'freeze' => 'Muzlatdi',
    'detach_roll' => 'Rulonni yechdi',
    'merge' => 'WIP rulonni uladi',
    'resume' => 'Davom ettirdi',
    'roll_complete' => 'Rulonni tugatdi',
    'complete' => 'Tugatdi',
    final value when value.isNotEmpty => value,
    _ => 'Harakat',
  };
}

String _closedLogTitle(AdminProductionOrderLogEntry log) {
  if (log.action == 'close_early') return 'Order muammo bilan erta yopildi';
  if (log.freeze != null) {
    return _closedLogFreezeStatusLabel(log.freeze!.status);
  }
  if (log.transfer != null) {
    return 'Apparat almashtirildi';
  }
  if (log.completedWithIssue) {
    final note = log.issueNote.trim();
    return note.isNotEmpty ? note : 'Muammo bilan yopildi';
  }
  return _closedLogActionLabel(log.action);
}

String _closedLogApparatusLabel(
  AdminProductionOrderLogEntry log,
  List<AdminApparatus> apparatusCatalog,
) {
  final freeze = log.freeze;
  if (log.action == 'close_early') return '';
  if (freeze != null) {
    final apparatus = freeze.targetApparatus.trim();
    if (apparatus.isNotEmpty) {
      return canonicalApparatusDisplayLabel(apparatus, apparatusCatalog);
    }
  }
  final transfer = log.transfer;
  if (transfer != null) {
    final from = transfer.fromApparatus.trim();
    final to = transfer.toApparatus.trim();
    if (from.isNotEmpty && to.isNotEmpty) {
      return '${canonicalApparatusDisplayLabel(from, apparatusCatalog)} → '
          '${canonicalApparatusDisplayLabel(to, apparatusCatalog)}';
    }
    return canonicalApparatusDisplayLabel(
      to.isNotEmpty ? to : from,
      apparatusCatalog,
    );
  }
  return canonicalApparatusDisplayLabel(log.apparatus, apparatusCatalog);
}

String _closedLogStateLabel(AdminProductionOrderLogEntry log) {
  if (log.action == 'close_early') return 'Erta yopilgan';
  final freeze = log.freeze;
  if (freeze != null) {
    return _closedLogFreezeStatusLabel(freeze.status);
  }
  final transfer = log.transfer;
  if (transfer != null) {
    final from = transfer.fromApparatus.trim();
    final to = transfer.toApparatus.trim();
    if (from.isNotEmpty && to.isNotEmpty) {
      return '$from → $to';
    }
  }
  final from = log.fromState.trim();
  final to = log.toState.trim();
  if (from.isNotEmpty && to.isNotEmpty) {
    return '$from → $to';
  }
  if (to.isNotEmpty) {
    return to;
  }
  return from;
}

String _closedLogFreezeStatusLabel(String status) {
  return switch (status.trim().toLowerCase()) {
    'pending' => 'Muzlatish so‘raldi',
    'frozen' => 'Muzlatildi',
    'cancelled' => 'Muzlatish bekor qilindi',
    'unfrozen' => 'Muzlatishdan chiqarildi',
    final value when value.isNotEmpty => 'Muzlatish: $value',
    _ => 'Muzlatish hodisasi',
  };
}

String _closedLogTimeLabel(int unixSeconds) {
  return formatUnixSecondsLocalDateTime(unixSeconds);
}

List<ProductionMapNode> _linearProductionMapNodes(ProductionMapDefinition map) {
  return productionMapDisplayPath(map);
}

String _productionMapQtyLabel(double value) => formatRawQuantity(value);
