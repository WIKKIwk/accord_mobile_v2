part 'app_models_declarations_part_01.dart';
part 'app_models_declarations_part_02.dart';
part 'app_models_helpers_part_03.dart';
part 'app_models_models_part_04.dart';
part 'app_models_declarations_part_05.dart';
part 'app_models_declarations_part_06.dart';
part 'app_models_declarations_part_07.dart';
part 'app_models_declarations_part_08.dart';

const String customerDeliveryResultEventPrefix = 'customer_delivery_result:';

/// Operator workflow only; canonical operation still controls names, groups
/// and production-map routing. The canonical glue technology is cold_glue.
bool apparatusUsesLaminationWorkflow(String operation) =>
    switch (operation.trim().toLowerCase()) {
      'laminate' || 'glue' => true,
      _ => false,
    };

const List<String> materialTaminotchiWorkspaceCapabilities = [
  'gscale.catalog.read',
  'gscale.print',
  'rps.batch.manage',
  'catalog.item.create',
  'raw_material.assign',
  'inventory.movement.manage',
];
