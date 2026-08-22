import 'dart:math' as math;

import '../../shared/models/app_models.dart';
import '../models/production_map_models.dart';

int productionMapRubberSizeFromWidth(double widthMm) {
  return (widthMm / 50).ceil().clamp(1, 27).toInt() * 50;
}

bool productionMapAllRequiredQolipsScanned({
  required Iterable<String> requiredQolipCodes,
  required Iterable<String> scannedQolipCodes,
}) {
  final required = {
    for (final code in requiredQolipCodes)
      if (code.trim().isNotEmpty) code.trim().toLowerCase(),
  };
  final scanned = {
    for (final code in scannedQolipCodes)
      if (code.trim().isNotEmpty) code.trim().toLowerCase(),
  };
  return required.isNotEmpty &&
      required.length == scanned.length &&
      required.containsAll(scanned);
}

int? productionMapRecommendedPechatColorCount({
  double? rollCount,
  double? widthMm,
}) {
  final hasRoll = rollCount != null && rollCount > 0;
  final hasWidth = widthMm != null && widthMm > 0;
  if (!hasRoll && !hasWidth) {
    return null;
  }

  var requiredColorCount = 0;
  if (hasRoll) {
    if (rollCount > 9) {
      return null;
    }
    requiredColorCount = rollCount > 8
        ? 9
        : rollCount > 7
            ? 8
            : 7;
  }
  if (hasWidth) {
    final rubberSize = productionMapRubberSizeFromWidth(widthMm);
    if (rubberSize > 1350) {
      return null;
    }
    final rubberColorCount = rubberSize > 1050
        ? 9
        : rubberSize > 850
            ? 8
            : 7;
    requiredColorCount = math.max(requiredColorCount, rubberColorCount);
  }
  return requiredColorCount == 0 ? null : requiredColorCount;
}

bool productionMapPechatCanHandleOrder({
  required int apparatusColorCount,
  required double? rollCount,
  required double? widthMm,
}) {
  if (rollCount != null && rollCount > apparatusColorCount) {
    return false;
  }
  if (widthMm == null || widthMm <= 0) {
    return true;
  }
  final rubberSize = productionMapRubberSizeFromWidth(widthMm);
  return switch (apparatusColorCount) {
    7 => rubberSize <= 850,
    8 => rubberSize >= 150 && rubberSize <= 1050,
    9 => rubberSize >= 800 && rubberSize <= 1350,
    _ => false,
  };
}

String productionMapPechatApparatusLabel(int colorCount) {
  return '$colorCount ta rangli bosma';
}

List<int> productionMapCompatiblePechatColorCounts({
  required double? rollCount,
  required double? widthMm,
}) {
  final recommended = productionMapRecommendedPechatColorCount(
    rollCount: rollCount,
    widthMm: widthMm,
  );
  return [
    for (final count in [7, 8, 9])
      if ((recommended == null || count >= recommended) &&
          productionMapPechatCanHandleOrder(
            apparatusColorCount: count,
            rollCount: rollCount,
            widthMm: widthMm,
          ))
        count,
  ];
}

String productionMapPechatCompatibilitySummary({
  required double? rollCount,
  required double? widthMm,
}) {
  final recommended = productionMapRecommendedPechatColorCount(
    rollCount: rollCount,
    widthMm: widthMm,
  );
  final compatible = productionMapCompatiblePechatColorCounts(
    rollCount: rollCount,
    widthMm: widthMm,
  );
  if (compatible.isEmpty) {
    return 'Mos bosma topilmadi';
  }
  final compatibleText =
      compatible.map(productionMapPechatApparatusLabel).join(', ');
  if (recommended == null) {
    return 'Mos bosma: $compatibleText';
  }
  return 'Minimal ${productionMapPechatApparatusLabel(recommended)} • '
      'Mos: $compatibleText';
}

bool productionMapPechatCanMoveOrder({
  required int apparatusColorCount,
  required double? rollCount,
  required double? widthMm,
  int? sourceApparatusColorCount,
}) {
  final recommended = productionMapRecommendedPechatColorCount(
    rollCount: rollCount,
    widthMm: widthMm,
  );
  if (recommended != null && apparatusColorCount < recommended) {
    return false;
  }
  final movingDown = sourceApparatusColorCount != null &&
      apparatusColorCount < sourceApparatusColorCount;
  if (movingDown) {
    if (widthMm == null || widthMm <= 0) {
      return false;
    }
    return productionMapPechatCanHandleOrder(
      apparatusColorCount: apparatusColorCount,
      rollCount: rollCount,
      widthMm: widthMm,
    );
  }
  if (rollCount == null || rollCount <= 0 || widthMm == null || widthMm <= 0) {
    return apparatusColorCount != 9;
  }
  return productionMapPechatCanHandleOrder(
    apparatusColorCount: apparatusColorCount,
    rollCount: rollCount,
    widthMm: widthMm,
  );
}

bool productionMapAlternativeAssignedGroupContainsTarget({
  required List<ProductionMapNode> nodes,
  required String fromApparatusId,
  required String toApparatusId,
}) {
  final fromId = fromApparatusId.trim();
  final toId = toApparatusId.trim();
  if (fromId.isEmpty || toId.isEmpty) return false;
  final candidateGroups = <String>{};
  for (final node in nodes) {
    final groupId = node.alternativeGroupId.trim();
    if (node.kind == 'apparatus' &&
        groupId.isNotEmpty &&
        node.alternativeAssignedApparatusId.trim() == fromId) {
      candidateGroups.add(groupId);
    }
  }
  if (candidateGroups.isEmpty) {
    return true;
  }
  return nodes.any(
    (node) =>
        node.kind == 'apparatus' &&
        candidateGroups.contains(node.alternativeGroupId.trim()) &&
        node.apparatusId.trim() == toId,
  );
}

bool productionMapUnassignedAlternativeGroupContainsTarget({
  required List<ProductionMapNode> nodes,
  required String fromApparatusId,
  required String toApparatusId,
}) {
  final fromId = fromApparatusId.trim();
  final toId = toApparatusId.trim();
  if (fromId.isEmpty || toId.isEmpty) return false;
  final candidateGroups = <String>{};
  for (final node in nodes) {
    final groupId = node.alternativeGroupId.trim();
    if (node.kind == 'apparatus' &&
        groupId.isNotEmpty &&
        node.alternativeAssignedApparatusId.trim().isEmpty &&
        node.apparatusId.trim() == fromId) {
      candidateGroups.add(groupId);
    }
  }
  return candidateGroups.any((groupId) {
    final groupNodes = nodes.where(
      (node) =>
          node.kind == 'apparatus' && node.alternativeGroupId.trim() == groupId,
    );
    return groupNodes.isNotEmpty &&
        groupNodes.every(
          (node) => node.alternativeAssignedApparatusId.trim().isEmpty,
        ) &&
        groupNodes.any(
          (node) => node.apparatusId.trim() == toId,
        );
  });
}

bool productionMapCanMoveOrderToApparatus({
  required List<ProductionMapNode> nodes,
  required AdminApparatus fromApparatus,
  required AdminApparatus toApparatus,
  required double? rollCount,
  required double? widthMm,
}) {
  final fromId = fromApparatus.id.trim();
  final toId = toApparatus.id.trim();
  if (fromId.isEmpty || toId.isEmpty || fromId == toId) return false;
  final sourceNodes = nodes.where(
    (node) =>
        node.kind == 'apparatus' &&
        (_effectiveApparatusId(node) == fromId ||
            node.apparatusId.trim() == fromId),
  );
  if (sourceNodes.isEmpty) return false;

  final fromOperation = fromApparatus.operation.trim();
  final toOperation = toApparatus.operation.trim();
  if (fromOperation.isEmpty ||
      toOperation.isEmpty ||
      fromOperation != toOperation) {
    return false;
  }
  final fromTechnology = fromApparatus.technology.trim();
  final toTechnology = toApparatus.technology.trim();
  if (fromTechnology.isEmpty ||
      toTechnology.isEmpty ||
      fromTechnology != toTechnology) {
    return false;
  }

  if (sourceNodes.any(
    (node) => node.alternativeGroupId.trim().isNotEmpty,
  )) {
    return productionMapAlternativeAssignedGroupContainsTarget(
          nodes: nodes,
          fromApparatusId: fromId,
          toApparatusId: toId,
        ) ||
        productionMapUnassignedAlternativeGroupContainsTarget(
          nodes: nodes,
          fromApparatusId: fromId,
          toApparatusId: toId,
        );
  }

  final targetColorCount = toApparatus.colorStations;
  if (targetColorCount == null) {
    return true;
  }
  return productionMapPechatCanMoveOrder(
    apparatusColorCount: targetColorCount,
    rollCount: rollCount,
    widthMm: widthMm,
    sourceApparatusColorCount: fromApparatus.colorStations,
  );
}

/// Reassigns the chosen apparatus for alternative-group maps.
/// Also claims an entirely unassigned alternative group for [toApparatus].
/// Returns null when no matching source assignment or candidate is found.
List<ProductionMapNode>? productionMapReassignAlternativeApparatusAssignment({
  required List<ProductionMapNode> nodes,
  required AdminApparatus fromApparatus,
  required AdminApparatus toApparatus,
}) {
  final fromId = fromApparatus.id.trim();
  final toId = toApparatus.id.trim();
  final toTitle = toApparatus.name.trim();
  if (fromId.isEmpty || toId.isEmpty || toTitle.isEmpty) {
    return null;
  }
  final candidateGroups = <String>{};
  for (final node in nodes) {
    final groupId = node.alternativeGroupId.trim();
    if (node.kind == 'apparatus' &&
        groupId.isNotEmpty &&
        node.alternativeAssignedApparatusId.trim() == fromId) {
      candidateGroups.add(groupId);
    }
  }
  if (candidateGroups.isEmpty) {
    for (final node in nodes) {
      final groupId = node.alternativeGroupId.trim();
      if (node.kind != 'apparatus' ||
          groupId.isEmpty ||
          node.alternativeAssignedApparatusId.trim().isNotEmpty ||
          node.apparatusId.trim() != fromId) {
        continue;
      }
      final groupNodes = nodes.where(
        (candidate) =>
            candidate.kind == 'apparatus' &&
            candidate.alternativeGroupId.trim() == groupId,
      );
      if (groupNodes.every(
            (candidate) =>
                candidate.alternativeAssignedApparatusId.trim().isEmpty,
          ) &&
          groupNodes.any(
            (candidate) => candidate.apparatusId.trim() == toId,
          )) {
        candidateGroups.add(groupId);
      }
    }
  }
  if (candidateGroups.isEmpty) {
    return null;
  }
  return [
    for (final node in nodes)
      node.kind == 'apparatus' &&
              candidateGroups.contains(node.alternativeGroupId.trim())
          ? node.copyWith(
              alternativeAssignedTitle: toTitle,
              alternativeAssignedApparatusId: toId,
            )
          : node,
  ];
}

/// Reassigns apparatus nodes from [fromApparatus] to [toApparatus].
/// Returns null when no matching source node was found.
List<ProductionMapNode>? productionMapReassignApparatusNodes({
  required List<ProductionMapNode> nodes,
  required AdminApparatus fromApparatus,
  required AdminApparatus toApparatus,
}) {
  final fromId = fromApparatus.id.trim();
  final toId = toApparatus.id.trim();
  final toTitle = toApparatus.name.trim();
  if (fromId.isEmpty || toId.isEmpty || toTitle.isEmpty) return null;
  var changed = false;
  final next = nodes.map((node) {
    if (node.kind == 'apparatus' &&
        node.alternativeGroupId.trim().isEmpty &&
        _effectiveApparatusId(node) == fromId) {
      changed = true;
      return node.copyWith(title: toTitle, apparatusId: toId);
    }
    return node;
  }).toList(growable: false);
  return changed ? next : null;
}

String _effectiveApparatusId(ProductionMapNode node) {
  final assignedId = node.alternativeAssignedApparatusId.trim();
  return assignedId.isEmpty ? node.apparatusId.trim() : assignedId;
}
