part of '../mobile_api.dart';

final Map<String, AdminItemDetail> _testModeAdminItemDetailOverrides = {};
final Set<String> _testModeDeletedAdminItemCodes = {};
int _canonicalApparatusOpaqueCounter = 0;

const Map<String, dynamic> _testModeCanonicalApparatusOptions = {
  'contract': 'canonical_apparatus_revision',
  'schema_version': 1,
  'vocabulary': {
    'equipment_capabilities': [
      'print',
      'laminate',
      'cut',
      'package',
      'glue',
      'tooling',
      'virtual_task',
      'training',
    ],
    'execution_operations': ['print', 'laminate', 'cut', 'package', 'glue'],
    'process_technologies': [
      'rotogravure',
      'flexographic',
      'adhesive_lamination',
      'extrusion_lamination',
      'slitting',
      'bag_making',
      'cold_glue',
    ],
  },
};

const Set<String> _canonicalApparatusCapabilities = {
  'print',
  'laminate',
  'cut',
  'package',
  'glue',
  'tooling',
  'virtual_task',
  'training',
};

extension MobileApiAdminItems on MobileApi {}
