const scanApparatus = 'apparatus:default:bosma_7';
const scanOrder = 'zakaz-scan-bootstrap';

Map<String, dynamic> scanControl() => {
      'state': 'pending',
      'allowed_actions': ['start'],
      'previous_stage_ready': true,
      'stage_node_id': 'apparatus',
      'complete_requires_full_report': false,
      'interaction': {
        'mode': 'fresh_start',
        'start_materials_mode': 'scan_required',
        'material_scan_required': true,
        'assigned_materials_display_only': true,
        'material_intake_allowed': false,
        'previous_wip_mode': 'not_required',
        'opening_wip_mode': 'not_required',
        'qolip_mode': 'scan_required',
      },
    };

Map<String, dynamic> scanMaterials() => {
      'policy': 'state_all',
      'requires_material': true,
      'material_scan_required': true,
      'requirement_groups': [],
      'assigned_barcodes': ['ROLL1'],
      'staged_barcodes': ['ROLL1'],
      'eligible_barcodes': ['ROLL1'],
      'required_scan_count': 1,
      'matched_scan_count': 0,
      'assignments_satisfied': true,
      'scan_satisfied': false,
      'assignments': [scanAssignment()],
      'start_assignments': [scanAssignment()],
    };
Map<String, dynamic> scanAssignment() => {
      'order_id': scanOrder,
      'apparatus': scanApparatus,
      'barcode': 'ROLL1',
      'item_code': 'FILM1',
      'item_name': 'Scan test film',
      'item_group': 'film',
      'execution_status': 'compatible',
      'stock_qty': 10,
      'stock_uom': 'kg',
    };
Map<String, dynamic> scanQolips() => {
      'ok': true,
      'qolip': {
        'qolip_code': '',
        'required_qolip_count': 1,
        'required_qolip_codes': ['MOLD1'],
        'required_qolips': [
          {'qolip_code': 'MOLD1', 'color': 'blue'},
        ],
      },
    };
Map<String, dynamic> scanBootstrap({
  int revision = 7,
  String epoch = 'scan-server',
}) =>
    {
      'ok': true,
      'control_state': {
        'apparatus': scanApparatus,
        'order_id': scanOrder,
        'rev': revision,
        'epoch': epoch,
        'scope': 'scan-read-scope',
        'control': scanControl(),
        'queue_state': 'pending',
        'stage_states': {},
        'order_control': 'active',
      },
      'sections': <String, dynamic>{
        'materials': {'status': 'ready', 'data': scanMaterials()},
        'qolips': {'status': 'ready', 'data': scanQolips()},
      },
    };
Map<String, dynamic> scanSequence() => {
      'ok': true,
      'rev': 7,
      'epoch': 'scan-server',
      'scope': '',
      'maps': [],
      'sequences': {
        scanApparatus: [scanOrder],
      },
      'visible_order_ids': {
        scanApparatus: [scanOrder],
      },
      'queue_states': {
        scanApparatus: {scanOrder: 'pending'},
      },
      'queue_action_controls': {
        scanApparatus: {scanOrder: scanControl()},
      },
      'queue_policies': [],
      'stage_states': {scanOrder: {}},
      'order_controls': {
        scanOrder: {'state': 'active'},
      },
      'order_statuses': {},
      'frozen_orders_by_apparatus': {},
      'order_customers': {},
    };
