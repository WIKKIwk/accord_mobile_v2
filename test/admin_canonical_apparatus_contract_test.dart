import 'dart:io';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const projection = <String, dynamic>{
    'apparatus_id': 'apparatus:default:asset-005',
    'source_revision': 7,
    'source_aasx_sha256':
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'display': {
      'display_name': 'Flexo pechat',
      'description': 'Flexographic printing press',
      'catalog_order': 5,
    },
    'equipment_class_id': 'equipment-class:printing:flexographic',
    'physical_asset_id': 'physical-asset:accord:flexo-01',
    'hierarchy': {
      'enterprise_id': 'enterprise:accord',
      'site_id': 'site:main',
      'area_id': 'area:production',
      'work_center_id': 'work-center:print',
      'work_unit_id': 'work-unit:flexo-01',
    },
    'capabilities': {'print': 3, 'training': 1},
    'execution_profile': {
      'operation': 'print',
      'technology': 'flexographic',
      'color_station_count': 8,
      'virtual_tasks': 'disabled',
      'capability_compatible_reroute': true,
    },
    'placement': {'factory_map_object_id': 'factory-node:flexo-01'},
    'training': {
      'enabled': true,
      'queue_enabled': true,
      'material_tracking_enabled': true,
    },
    'lifecycle': {'state': 'active', 'retirement_reason': null},
  };

  test('runtime projection uses stable canonical identity and metadata', () {
    final apparatus = AdminApparatus.fromJson(projection);

    expect(apparatus.id, 'apparatus:default:asset-005');
    expect(apparatus.name, 'Flexo pechat');
    expect(apparatus.sourceRevision, 7);
    expect(apparatus.operation, 'print');
    expect(apparatus.technology, 'flexographic');
    expect(apparatus.family, 'pechat');
    expect(apparatus.kind, 'flexo');
    expect(apparatus.isPechat, isTrue);
    expect(apparatus.isFlexo, isTrue);
    expect(apparatus.factoryMapObjectId, 'factory-node:flexo-01');
    expect(apparatus.trainingEnabled, isTrue);
  });

  test('committed canonical response reads its runtime projection', () {
    final apparatus = AdminApparatus.fromJson({
      'revision': {
        'apparatus_id': 'apparatus:default:asset-005',
      },
      'runtime_projection': projection,
      'aasx_sha256':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    });

    expect(apparatus.id, 'apparatus:default:asset-005');
    expect(apparatus.sourceRevision, 7);
  });

  test('legacy display-only apparatus cannot synthesize an identity', () {
    expect(
      () => AdminApparatus.fromJson(const {'name': 'Flexo pechat'}),
      throwsFormatException,
    );
  });

  test('legacy id and name payload cannot bypass canonical projection', () {
    expect(
      () => AdminApparatus.fromJson(const {
        'id': 'apparatus:default:asset-005',
        'name': 'Flexo pechat',
      }),
      throwsFormatException,
    );
  });

  test('options are derived from canonical vocabulary', () {
    final options = AdminApparatusMasterOptions.fromJson(const {
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
        'execution_operations': [
          'print',
          'laminate',
          'cut',
          'package',
          'glue',
        ],
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
    });

    expect(
        options.families, ['pechat', 'laminatsiya', 'rezka', 'paket', 'kley']);
    expect(options.kindsForFamily('pechat'), ['color_pechat', 'flexo']);
    expect(options.capabilities, containsAll(['print', 'training']));
    expect(options.capabilities, isNot(contains('pechat')));
  });

  test('queue and capacity projections remain keyed by apparatus id', () {
    final policies = MobileApi.instance.parseApparatusQueuePolicyMap(const [
      {
        'apparatus_id': 'apparatus:default:asset-005',
        'source_revision': 7,
        'source_aasx_sha256':
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'discipline': 'strict_sequence',
      },
    ]);
    final capacity = AdminApparatusCapacityProfile.fromJson(const {
      'apparatus_id': 'apparatus:default:asset-005',
      'source_revision': 7,
      'source_aasx_sha256':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'capacity_slots': 2,
      'setup_minutes': 15,
      'cleanup_minutes': 10,
      'efficiency_percent': 95,
      'finite_capacity': true,
      'always_available': true,
      'working_windows': <dynamic>[],
    });

    expect(policies.keys, ['apparatus:default:asset-005']);
    expect(policies.values.single.sourceRevision, 7);
    expect(capacity.apparatusId, 'apparatus:default:asset-005');
    expect(capacity.sourceRevision, 7);
    expect(capacity.capacitySlots, 2);
  });

  test('queue projections reject display-name identity keys', () {
    expect(
      () => MobileApi.instance.parseApparatusSequenceMap(const {
        'Flexo pechat': ['zakaz-1'],
      }),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.code,
          'code',
          'production_map_snapshot_contract_invalid',
        ),
      ),
    );
    expect(
      () => MobileApi.instance.parseApparatusQueueStateMap(const {
        'Flexo pechat': {'zakaz-1': 'pending'},
      }),
      throwsA(isA<MobileApiException>()),
    );
  });

  test('production map save boundary rejects title-only apparatus nodes',
      () async {
    const map = ProductionMapDefinition(
      id: 'zakaz-title-only',
      productCode: 'TITLE-ONLY',
      title: 'Title-only apparatus map',
      nodes: [
        ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
        ProductionMapNode(
          id: 'apparatus',
          kind: 'apparatus',
          title: 'Flexo pechat',
        ),
        ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
      ],
      edges: [],
    );

    await expectLater(
      () => MobileApi.instance.adminSaveProductionMap(map),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.code,
          'code',
          'production_map_apparatus_id_invalid',
        ),
      ),
    );
    await expectLater(
      () => MobileApi.instance.adminSaveTrainingProductionMap(map),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.code,
          'code',
          'production_map_apparatus_id_invalid',
        ),
      ),
    );
  });

  test('principal apparatus scopes fail closed on legacy names', () {
    expect(
      () => SessionProfile.fromJson(const {
        'role': 'aparatchi',
        'assigned_apparatus': ['Flexo pechat'],
      }),
      throwsFormatException,
    );
    expect(
      () => AdminRoleAssignment.fromJson(const {
        'principal_role': 'aparatchi',
        'principal_ref': 'worker-1',
        'role_id': 'aparatchi',
        'assigned_apparatus': ['Flexo pechat'],
      }),
      throwsFormatException,
    );
  });

  test('progress and material projections reject display-name identity', () {
    expect(
      () => AdminProgressBatch.fromJson(const {
        'batch_id': 'batch-1',
        'apparatus': 'Flexo pechat',
      }),
      throwsA(isA<MobileApiException>()),
    );
    expect(
      () => AdminRawMaterialAssignment.fromJson(const {
        'order_id': 'order-1',
        'apparatus': 'Flexo pechat',
        'barcode': 'RAW-1',
      }),
      throwsA(isA<MobileApiException>()),
    );
    expect(
      () => AdminRawMaterialLookup.fromJson(const {
        'barcode': 'RAW-1',
        'queue_states': {
          'Flexo pechat': {'order-1': 'pending'},
        },
      }),
      throwsA(isA<MobileApiException>()),
    );
  });

  test('progress projection rejects mismatched canonical apparatus keys', () {
    expect(
      () => AdminProgressBatch.fromJson(const {
        'batch_id': 'batch-1',
        'apparatus': 'apparatus:default:asset-005',
        'current_apparatus': 'apparatus:default:asset-005',
        'current_apparatus_key': 'apparatus:default:asset-007',
      }),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.code,
          'code',
          'apparatus_id_mismatch',
        ),
      ),
    );
  });

  test('worker group projection requires canonical apparatus id', () {
    expect(
      () => AdminWorkerGroup.fromJson(const {
        'apparatus': 'Flexo pechat',
        'group_code': 'A',
        'shift': 'kunduz',
      }),
      throwsFormatException,
    );
  });

  test('raw material projection does not accept outer artifact hash fallback',
      () {
    expect(
      () => AdminRawMaterialRule.fromJson(const {
        'revision': {
          'apparatus_id': 'apparatus:default:asset-005',
          'revision_metadata': {'revision': 1},
          'policies': {
            'material': {'mode': 'not_required'},
            'tooling': {'mode': 'not_required'},
          },
        },
        'runtime_projection': {
          'apparatus_id': 'apparatus:default:asset-005',
          'source_revision': 1,
        },
        'aasx_sha256':
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      }),
      throwsFormatException,
    );
  });

  test('optional canonical material groups survive mobile round trip', () {
    final rule = AdminRawMaterialRule.fromJson(const {
      'revision': {
        'apparatus_id': 'apparatus:default:bosma_7',
        'revision_metadata': {'revision': 2},
        'display': {'display_name': '7 ta rangli bosma aparat'},
        'policies': {
          'material': {
            'mode': 'not_required',
            'item_group_ids': ['kraska', 'rulon'],
          },
          'tooling': {
            'mode': 'qolip_scan_required',
            'tooling_class_id': 'tooling-class:qolip',
          },
        },
      },
      'runtime_projection': {
        'apparatus_id': 'apparatus:default:bosma_7',
        'source_revision': 2,
        'source_aasx_sha256':
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      },
    });

    expect(rule.requiresMaterial, isFalse);
    expect(rule.itemGroups, ['kraska', 'rulon']);
    expect(rule.materialPolicyJson(), {
      'mode': 'not_required',
      'item_group_ids': ['kraska', 'rulon'],
    });
  });

  test('canonical cutover source guard blocks legacy identity fallbacks', () {
    final sources = [
      'lib/src/core/api/admin/mobile_api_admin.dart',
      'lib/src/core/api/admin/mobile_api_admin_training.dart',
      'lib/src/features/admin/logic/production_map_chain.dart',
      'lib/src/features/admin/logic/production_map_pechat_rules.dart',
      'lib/src/features/admin/logic/apparatus_queue_state.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    for (final forbidden in const [
      'productionMapWarehouseTitlesMatch',
      'productionMapQueueApparatusTitlesMatch',
      'productionMapNextStageTitleMatchesApparatus',
      'productionMapApparatusNodeMatchesFrom',
      'resolveApparatusStorageKey',
      '_testModeDefaultApparatusIds',
      'AdminApparatusMasterOptions.fallback',
      'includeLegacyApparatus',
      'storageKey.trim().isEmpty ? apparatus.trim()',
    ]) {
      expect(sources, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
