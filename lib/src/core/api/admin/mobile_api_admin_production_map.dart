part of '../mobile_api.dart';

class ProductionMapSaveWithOrderResult {
  const ProductionMapSaveWithOrderResult({
    required this.saved,
    required this.template,
  });

  final ProductionMapSaved saved;
  final CalculateOrderTemplate? template;
}

void _validateProductionMapQueueContract({
  required Map<String, List<String>> sequences,
  required Map<String, List<String>> visibleOrderIds,
  required Map<String, Map<String, String>> queueStates,
  required Map<String, Map<String, String>> stageStates,
  required Map<String, AdminApparatusQueuePolicy> queuePolicies,
  required Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
      queueActionControls,
  required Map<String, List<AdminFrozenQueueOrder>> frozenOrdersByApparatus,
}) {
  for (final entry in [...sequences.entries, ...visibleOrderIds.entries]) {
    if (!isCanonicalApparatusId(entry.key.trim()) ||
        entry.value.any((orderId) => orderId.trim().isEmpty)) {
      throw _productionMapQueueContractException(
        'queue order map contains an invalid apparatus or order',
      );
    }
  }
  for (final entry in queuePolicies.entries) {
    if (!isCanonicalApparatusId(entry.key.trim()) ||
        entry.value.apparatusId.trim() != entry.key.trim()) {
      throw _productionMapQueueContractException(
        'queue_policies contains an invalid apparatus',
      );
    }
  }
  for (final entry in frozenOrdersByApparatus.entries) {
    if (!isCanonicalApparatusId(entry.key.trim()) ||
        entry.value.any(
          (order) =>
              order.apparatus.trim() != entry.key.trim() ||
              order.orderId.trim().isEmpty,
        )) {
      throw _productionMapQueueContractException(
        'frozen_orders_by_apparatus contains an invalid order',
      );
    }
  }
  for (final apparatusEntry in queueStates.entries) {
    if (!isCanonicalApparatusId(apparatusEntry.key.trim())) {
      throw _productionMapQueueContractException(
        'queue_states contains an invalid apparatus key',
      );
    }
    for (final stateEntry in apparatusEntry.value.entries) {
      final state = stateEntry.value.trim().toLowerCase();
      if (stateEntry.key.trim().isEmpty ||
          !_knownApparatusQueueStates.contains(state)) {
        throw _productionMapQueueContractException(
          'queue_states contains an unknown order state',
        );
      }
    }
  }
  for (final orderEntry in stageStates.entries) {
    if (orderEntry.key.trim().isEmpty) {
      throw _productionMapQueueContractException(
        'stage_states contains an invalid order key',
      );
    }
    for (final stageEntry in orderEntry.value.entries) {
      final state = stageEntry.value.trim().toLowerCase();
      if (stageEntry.key.trim().isEmpty ||
          !_knownApparatusQueueStates.contains(state)) {
        throw _productionMapQueueContractException(
          'stage_states contains an invalid stage state',
        );
      }
    }
  }
  for (final apparatusEntry in queueActionControls.entries) {
    if (!isCanonicalApparatusId(apparatusEntry.key.trim())) {
      throw _productionMapQueueContractException(
        'queue_action_controls contains an invalid apparatus key',
      );
    }
    for (final orderEntry in apparatusEntry.value.entries) {
      final control = orderEntry.value;
      if (orderEntry.key.trim().isEmpty || !control.contractValid) {
        throw _productionMapQueueContractException(
          'queue_action_controls contains an invalid order control',
        );
      }
      final queueState = queueStates[apparatusEntry.key]?[orderEntry.key];
      if (queueState != null &&
          queueState.trim().isNotEmpty &&
          queueState.trim().toLowerCase() !=
              control.state.trim().toLowerCase()) {
        throw _productionMapQueueContractException(
          'queue state and action control state disagree',
        );
      }
    }
  }
}

class AdminProductionMapLiveSnapshot {
  const AdminProductionMapLiveSnapshot({
    required this.maps,
    required this.sequences,
    required this.visibleOrderIds,
    required this.queueStates,
    required this.queuePolicies,
    this.queueActionControls = const {},
    this.stageStates = const {},
    required this.completedOrders,
    required this.completionRequests,
    required this.completionRequestDecisions,
    required this.orderControls,
    this.orderCustomers = const {},
    this.orderStatuses = const {},
    this.frozenOrdersByApparatus = const {},
  });

  final List<ProductionMapSaved> maps;
  final Map<String, List<String>> sequences;
  final Map<String, List<String>> visibleOrderIds;
  final Map<String, Map<String, String>> queueStates;
  final Map<String, Map<String, String>> stageStates;
  final Map<String, AdminApparatusQueuePolicy> queuePolicies;
  final Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
      queueActionControls;
  final List<AdminCompletedQueueOrder> completedOrders;
  final List<AdminCompletionRequestNotification> completionRequests;
  final List<AdminCompletionRequestDecisionNotification>
      completionRequestDecisions;
  final Map<String, AdminOrderControlState> orderControls;
  final Map<String, String> orderCustomers;
  final Map<String, AdminProductionOrderStatusDetail> orderStatuses;
  final Map<String, List<AdminFrozenQueueOrder>> frozenOrdersByApparatus;

  factory AdminProductionMapLiveSnapshot.fromJson(Map<String, dynamic> json) {
    final visibleOrderIds = _parseRequiredProductionMapVisibleOrderIds(json);
    _requireProductionMapSnapshotShape(json, includesMaps: true);
    final mapsRaw = json['maps'];
    final completedRaw = json['completed_orders'];
    final completionRequestsRaw = json['completion_requests'];
    final completionRequestDecisionsRaw = json['completion_request_decisions'];
    final orderControls = _parseAdminOrderControls(json['order_controls']);
    final snapshot = AdminProductionMapLiveSnapshot(
      maps: [
        if (mapsRaw is List)
          for (final item in mapsRaw)
            ProductionMapSaved.fromJson(item as Map<String, dynamic>),
      ],
      sequences: MobileApi.instance.parseApparatusSequenceMap(
        json['sequences'],
      ),
      visibleOrderIds: visibleOrderIds,
      queueStates: MobileApi.instance.parseApparatusQueueStateMap(
        json['queue_states'],
      ),
      stageStates: _parseProductionMapStageStates(json['stage_states']),
      queuePolicies: MobileApi.instance.parseApparatusQueuePolicyMap(
        json['queue_policies'],
      ),
      queueActionControls: _parseAdminQueueActionControls(
        json['queue_action_controls'],
      ),
      completedOrders: [
        if (completedRaw is List)
          for (final item in completedRaw)
            AdminCompletedQueueOrder.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
      ],
      completionRequests: [
        if (completionRequestsRaw is List)
          for (final item in completionRequestsRaw)
            AdminCompletionRequestNotification.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
      ],
      completionRequestDecisions: [
        if (completionRequestDecisionsRaw is List)
          for (final item in completionRequestDecisionsRaw)
            AdminCompletionRequestDecisionNotification.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
      ],
      orderControls: orderControls,
      orderCustomers: _stringMapOfStrings(json['order_customers']),
      orderStatuses: _parseAdminOrderStatuses(json['order_statuses']),
      frozenOrdersByApparatus: _parseAdminFrozenOrdersByApparatus(
        json['frozen_orders_by_apparatus'],
      ),
    );
    snapshot.validateContract();
    return snapshot;
  }

  void validateContract() {
    _validateProductionMapQueueContract(
      sequences: sequences,
      visibleOrderIds: visibleOrderIds,
      queueStates: queueStates,
      stageStates: stageStates,
      queuePolicies: queuePolicies,
      queueActionControls: queueActionControls,
      frozenOrdersByApparatus: frozenOrdersByApparatus,
    );
  }
}

MobileApiException _adminProductionMapException(
  http.Response response,
  String fallbackCode,
) {
  String code = fallbackCode;
  var apparatusOptions = const <String>[];
  var details = const <String>[];
  try {
    final payload = jsonDecode(response.body);
    if (payload is Map && payload['error'] is String) {
      final error = (payload['error'] as String).trim();
      if (error.isNotEmpty) {
        code = error;
      }
    }
    if (payload is Map && payload['apparatus_options'] is List) {
      apparatusOptions = [
        for (final option in payload['apparatus_options'] as List)
          if (option.toString().trim().isNotEmpty) option.toString().trim(),
      ];
    }
    if (payload is Map && payload['blockers'] is List) {
      details = [
        for (final blocker in payload['blockers'] as List)
          if (blocker is Map &&
              blocker['message']?.toString().trim().isNotEmpty == true)
            blocker['message'].toString().trim(),
      ];
    }
  } catch (_) {}
  return MobileApiException(
    code: code,
    apparatusOptions: apparatusOptions,
    details: details,
    message: switch (code.trim().toLowerCase()) {
      'duplicate_order_number' => 'Bu raqam boshqa zakazga berilgan',
      'order_number_immutable' => 'Zakaz raqamini o‘zgartirish mumkin emas',
      'order_number_exhausted' => 'Zakaz raqamlari limiti tugagan',
      'move_not_allowed' => 'Zakaz bu aparatga tushmaydi',
      'started_order_move_requires_transfer' =>
        'Ish boshlangan orderni avval pause qilib avariyaviy ko‘chiring',
      'production_map_started_stage_locked' =>
        'Ish boshlangan aparat bosqichlarini o‘zgartirib bo‘lmaydi',
      'apparatus_transfer_reason_required' => 'Avariya sababini kiriting',
      'apparatus_transfer_idempotency_required' =>
        'Avariya ko‘chirish identifikatori mavjud emas',
      'apparatus_transfer_idempotency_conflict' =>
        'Avariya ko‘chirish identifikatori boshqa amalda ishlatilgan',
      'apparatus_transfer_order_not_paused' =>
        'Ko‘chirishdan oldin orderni pause qiling',
      'apparatus_transfer_session_not_found' =>
        'Orderning ish sessiyasi topilmadi',
      'apparatus_transfer_progress_not_found' =>
        'Orderning pause progressi topilmadi',
      'apparatus_transfer_session_mismatch' =>
        'Order sessiyasi apparat bilan mos emas',
      'apparatus_transfer_progress_mismatch' =>
        'Order progressi apparat bilan mos emas',
      'apparatus_transfer_target_conflict' =>
        'Order tanlangan apparatda allaqachon mavjud',
      'apparatus_transfer_invalid_response' =>
        'Avariya ko‘chirish javobi noto‘g‘ri',
      'queue_action_not_allowed' =>
        'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
      'order_not_started' => 'Boshlanmagan buyurtmani muzlatib bo‘lmaydi',
      'order_already_completed' => 'Tugallangan buyurtmani muzlatib bo‘lmaydi',
      'order_freeze_requested' =>
        'Buyurtma muzlatish uchun worker pauzasini kutmoqda',
      'order_frozen' => 'Buyurtma muzlatilgan',
      'order_control_action_not_allowed' =>
        'Buyurtmaning hozirgi holatida bu amal mumkin emas',
      'order_delete_blocked' =>
        details.isEmpty ? 'Buyurtmani o‘chirib bo‘lmaydi' : details.join('\n'),
      'order_reset_confirmation_required' => 'Order reset tasdig‘i topilmadi',
      'order_reset_unavailable' => 'Order reset xizmati mavjud emas',
      'order_reset_failed' => 'Orderlar tozalanmadi',
      'order_reset_verification_failed' =>
        'Order reset yakuniy tekshiruvdan o‘tmadi',
      'order_reset_test_mode_unsupported' =>
        'Order reset test rejimida mavjud emas',
      'backup_failed' => 'Resetdan oldingi backup olinmadi',
      'backup_timed_out' => 'Resetdan oldingi backup vaqti tugadi',
      'previous_stage_not_completed' =>
        'Oldingi bosqich tugallanguncha kutilmoqda',
      'apparatus_not_assigned' => 'Bu aparat sizga biriktirilmagan',
      'queue_policy_locked' =>
        'Bosma aparati doim ketma-ketlik bo‘yicha ishlaydi',
      'bosma_completion_metrics_required' =>
        'Bosma tugatish uchun barcha majburiy fieldlarni kiriting',
      'laminatsiya_completion_metrics_required' =>
        'Laminatsiyani tugatish uchun barcha majburiy qiymatlarni kiriting',
      'laminatsiya_astatka_metrics_required' =>
        'Bosmadan, plyonkadan ortgan rulon va chiqindini kiriting',
      'laminatsiya_rubber_too_large' =>
        'Rezina razmeri 1050 mm dan katta bo‘lsa laminatsiya mumkin emas',
      'rezka_progress_metrics_required' =>
        'Rezka uchun barcha majburiy fieldlarni kiriting',
      'rezka_frame_issue_only_on_roll_progress' =>
        'Kadr muammosi faqat Rezka tugatish amalida belgilanadi',
      'rezka_kadr_count_required' =>
        'Rezka uchun kadr soni production mapda sozlanmagan',
      'rezka_final_roll_required' =>
        'Avval qolgan laminatsiya rulonlarini tugating; to‘liq tugatish faqat oxirgi rulonda mumkin',
      'zero_metric_explanation_required' =>
        '0 qiymat kiritilganda sababini yozing',
      'returned_paint_astatka_exceeds_rasxot' =>
        'Astatka Rasxotdan katta bo‘lishi mumkin emas',
      'astatka cannot exceed rasxot' =>
        'Astatka Rasxotdan katta bo‘lishi mumkin emas',
      'raw_material_scan_required' =>
        'Ishni boshlash uchun biriktirilgan homashyoni skaner qiling',
      'raw_material_state_not_ready' =>
        'Apparat oldiga homashyo olib kelinmagan',
      'raw_material_scan_incomplete' =>
        'Apparat oldidagi barcha homashyolarni skaner qiling',
      'raw_material_requirement_not_met' =>
        'Har bir majburiy guruhdan minimum homashyo skaner qiling',
      'raw_material_mismatch' => 'Bu homashyo ish boshlash uchun mos emas',
      'raw_material_stock_unavailable' =>
        'Bu homashyo omborda mavjud emas yoki boshqa zakaz uchun band',
      'raw_material_order_not_active' =>
        'Yana homashyo faqat ish boshlangan yoki pauzadagi zakazga olinadi',
      'qolip_scan_required' => 'Ishni boshlash uchun qolip QR scan qiling',
      'qolip_scan_incomplete' =>
        'Mahsulotga biriktirilgan barcha qoliplarni scan qiling',
      'qolip_code_not_found' => 'Qolip QR topilmadi',
      'qolip_code_mismatch' => 'Bu qolip ushbu zakaz mahsulotiga mos emas',
      'qolip_code_required' => 'Kamida bitta qolipni tanlang',
      'qolip_order_note_not_found' =>
        'Bu order uchun berilgan qolip qaydi topilmadi',
      'qolip_order_note_status_invalid' => 'Qolip qaydi holati noto‘g‘ri',
      'qolip_order_note_in_use' => 'Bu qolip boshqa order uchun band qilingan',
      'qolip_order_note_load_failed' => 'Qolip qaydi yuklanmadi',
      'qolip_order_note_save_failed' => 'Qolip qaydi saqlanmadi',
      'qolip_already_in_use' => 'Bu qolip boshqa aparatda ishlatilmoqda',
      'qolip_location_not_found' => 'Bu qolip hozir ombor yachaykasida emas',
      'insufficient_stock' => 'Bu qolip omborda qolmagan',
      'location_identity_mismatch' =>
        'Qolip joylashuvi o‘zgargan, qayta skanerlang',
      'raw_material_rule_not_found' => 'Bu homashyo uchun aparat qoidasi yo‘q',
      'raw_material_assignment_not_found' => 'Homashyo biriktirilmagan',
      'raw_material_assignment_locked' =>
        'Bu homashyo allaqachon ishga tushgan yoki ishlatilgan, uzib bo‘lmaydi',
      'raw_material_already_assigned' =>
        'Bu homashyo boshqa zakaz uchun band qilingan',
      'raw_material_already_assigned_to_order' =>
        'Bu homashyo allaqachon shu zakazga ulangan',
      'raw_material_group_not_allowed' =>
        'Bu homashyo ish boshlash uchun mos emas',
      'raw_material_group_ambiguous' =>
        'Bu homashyoni qaysi aparatga ulashni tanlang',
      'raw_material_roll_size_missing' => 'Rulon razmeri topilmadi',
      'raw_material_roll_size_mismatch' =>
        'Bu rulon bu buyurtma uchun mos emas',
      'raw_material_invalid_input' => 'Homashyo QR noto‘g‘ri',
      'item group is not assigned to material taminotchi' =>
        'Bu homashyo sizga biriktirilgan guruhlarga kirmaydi',
      'progress_input_invalid' => 'Chiqarilgan miqdorni kiriting',
      'progress_qr_required' => 'Oldingi bosqich QR sini scan qiling',
      'training_input_batch_required' =>
        'Avval admin training batch QR sini generatsiya qilishi kerak',
      'training_input_batch_not_found' => 'Training batch topilmadi',
      'progress_batch_not_found' => 'Progress QR topilmadi',
      'progress_batch_not_accepted' =>
        'Bu QR oldingi bosqich mahsulotiga mos emas',
      'opening_wip_invalid_input' => 'Opening WIP ma’lumotlari to‘liq emas',
      'opening_wip_entry_mismatch' =>
        'Opening WIP faqat production mapning birinchi aparatidan boshlanishi mumkin',
      'opening_wip_order_already_started' =>
        'Ish boshlangan orderga Opening WIP kiritib bo‘lmaydi',
      'opening_wip_location_mismatch' =>
        'Joylashuv production mapdagi aparat bo‘lishi kerak',
      'opening_wip_source_mismatch' =>
        'Tanlangan chiqish apparati production mapga mos emas',
      'opening_wip_source_final_stage' =>
        'Oxirgi aparat chiqish WIP manbasi bo‘la olmaydi',
      'opening_wip_idempotency_conflict' =>
        'Bu Opening WIP so‘rovi boshqa ma’lumot bilan ishlatilgan',
      'opening_wip_status_invalid' => 'Opening WIP holati noto‘g‘ri',
      'opening_wip_qr_mismatch' =>
        'Bu QR ushbu orderning kutilayotgan Opening WIP ruloniga mos emas',
      'opening_wip_delete_locked' =>
        'Ishlatilgan Opening WIP rulonini o‘chirib bo‘lmaydi',
      'opening_wip_delete' => 'Opening WIP ruloni o‘chirilmadi',
      'progress_batch_not_resumable' =>
        'Bu progress QR davom ettirishga yaramaydi',
      'progress_batch_correction_reason_required' =>
        'O‘zgartirish sababini yozing',
      'progress_batch_correction_locked' =>
        'Ishlatilgan WIPni o‘zgartirib bo‘lmaydi',
      'progress_batch_correction_conflict' =>
        'WIP boshqa joyda yangilangan. Ma’lumotni qayta oching',
      'progress_batch_correction_unchanged' =>
        'WIP qiymatlarida o‘zgarish yo‘q',
      'paddon_invalid_input' => 'Paddon ma’lumoti noto‘g‘ri',
      'paddon_code_exhausted' => 'Paddon code raqamlari tugagan',
      'paddon_not_found' => 'Paddon topilmadi',
      'paddon_item_already_assigned' => 'Bu WIP boshqa paddonga biriktirilgan',
      'paddon_item_not_assigned' => 'Bu WIP ushbu paddonda yo‘q',
      'scale_driver_not_configured' => 'Printer ulanmagan',
      'unauthorized' => 'Sessiya tugagan. Qayta login qiling',
      'forbidden' => 'Bu amal sizning rolingiz uchun ruxsat etilmagan',
      'method not allowed' => 'Bu amal bu usulda qo‘llanmaydi',
      'invalid json' => 'Yuborilgan ma’lumot noto‘g‘ri',
      'production maps fetch failed' => 'Production maplar yuklanmadi',
      'training_order_number_exists' =>
        'Bu training order raqami allaqachon mavjud',
      'training_material_assignment_exists' =>
        'Bu QR kodi shu training orderga allaqachon ulangan',
      'training_material_assignment_not_found' => 'Training homashyo topilmadi',
      'training_material_assignment_required' => 'Training homashyo tanlanmadi',
      'training_order_not_found' => 'Tanlangan training order topilmadi',
      'training_map_not_found' => 'Training order topilmadi',
      'training_apparatus_required' => 'Training aparat tanlanmadi',
      'training_apparatus_not_found' => 'Training aparat topilmadi',
      'map_id_required' =>
        'Production map yoki aparat canonical ID si topilmadi',
      'map_product_code_required' => 'Mahsulot kodi kiritilmagan',
      'map_title_required' => 'Production map nomi kiritilmagan',
      'map_start_required' =>
        'Production mapda boshlang‘ich nuqta bo‘lishi kerak',
      'map_end_required' => 'Production mapda yakuniy nuqta bo‘lishi kerak',
      'duplicate_node_id' => 'Production mapda node ID takrorlangan',
      'missing_edge_node' => 'Production mapdagi bog‘lanish nuqtasi topilmadi',
      'production_map_cycle' => 'Production map ketma-ketligida aylanish bor',
      'formula_target_required' => 'Formula maqsadi kiritilmagan',
      'formula_expression_required' => 'Formula ifodasi kiritilmagan',
      'invalid_formula_target' => 'Formula maqsadi noto‘g‘ri',
      'invalid_formula_expression' => 'Formula ifodasi noto‘g‘ri',
      'invalid_order_qty' => 'Zakaz miqdori 0 dan katta bo‘lishi kerak',
      'invalid_node_qty' => 'Bosqich miqdori noto‘g‘ri',
      'invalid_location' => 'Joylashuv noto‘g‘ri',
      'unknown_formula_variable' => 'Formula ichidagi o‘zgaruvchi topilmadi',
      'formula_division_by_zero' => 'Formula 0 ga bo‘lishni o‘z ichiga oladi',
      'condition_branch_required' =>
        'Shart uchun true va false yo‘nalishlari kerak',
      'order_freeze_target_not_found' =>
        'Buyurtmani muzlatish uchun faol ish sessiyasi topilmadi',
      'order_freeze_target_ambiguous' =>
        'Buyurtmani muzlatish uchun bir nechta faol sessiya topildi',
      'order_freeze_request_mismatch' =>
        'Muzlatish so‘rovi bu ish sessiyasiga tegishli emas',
      'freeze_safe_stop_output_or_issue_note_required' =>
        'Miqdorlarni to‘liq kiriting yoki faqat muammo izohini yozing',
      'freeze_safe_stop_output_incomplete' =>
        'Miqdorlar to‘liq emas. Barcha majburiy qiymatlarni kiriting yoki maydonlarni tozalab, faqat muammo izohini yozing',
      'store_failed' ||
      'production_map_store_failed' =>
        fallbackCode == 'production_map_sequence'
            ? 'Ish rejasi navbati serverdan yuklanmadi'
            : 'Production map ma’lumotlarini saqlashda server xatosi',
      'training workspace store failed' =>
        'Training server bazasi yangilanmagan yoki ulanmagan. Serverni restart qiling',
      'capacity_profile_invalid' => 'Aparat quvvati profili noto‘g‘ri',
      'capacity_profile_not_found' => 'Aparat quvvati profili topilmadi',
      'capability_not_supported' => 'Bu aparat kerakli ish turini qo‘llamaydi',
      'capability_level_insufficient' =>
        'Bu aparatning imkoniyat darajasi yetarli emas',
      'capacity_conflict' => 'Bu aparatning quvvati tanlangan vaqt uchun band',
      'capacity_no_working_window' =>
        'Bu aparat uchun tanlangan vaqt oralig‘ida ish vaqti yo‘q',
      'capacity_unavailable' => 'Bu aparat tanlangan vaqtda ishlamaydi',
      'schedule_input_invalid' => 'Jadval ma’lumotlari noto‘g‘ri',
      'schedule_idempotency_conflict' =>
        'Bu jadval identifikatori boshqa orderga tegishli',
      'schedule_reservation_not_found' => 'Jadval bandlovi topilmadi',
      'schedule_reservation_locked' =>
        'Bu jadval bandlovini bekor qilib bo‘lmaydi',
      'map_not_found' => 'Zakaz topilmadi',
      _ => _adminProductionMapUnknownErrorMessage(
          code: code,
          fallbackCode: fallbackCode,
          statusCode: response.statusCode,
        ),
    },
    statusCode: response.statusCode,
  );
}

String _adminProductionMapUnknownErrorMessage({
  required String code,
  required String fallbackCode,
  required int statusCode,
}) {
  final operation = switch (fallbackCode.trim().toLowerCase()) {
    'production_maps_list' => 'Production maplar yuklanmadi',
    'training_maps_list' => 'Training orderlar yuklanmadi',
    'training_map_save' => 'Training order saqlanmadi',
    'training_map_save_with_order' => 'Training order va map saqlanmadi',
    'training_map_delete' => 'Training order o‘chirilmadi',
    'training_apparatus_modes' => 'Training apparatlar rejimi olinmadi',
    'training_apparatus_mode_save' => 'Training aparat rejimi saqlanmadi',
    'training_restart' => 'Training qayta boshlanmadi',
    'training_material_assignments' =>
      'Training homashyo biriktirmalari yuklanmadi',
    'training_material_assignment' => 'Training homashyo ulanmagan',
    'training_material_assignment_delete' => 'Training homashyo o‘chirilmadi',
    'training_input_batches' => 'Training batchlar yuklanmadi',
    'training_input_batch_generate' => 'Training batch generatsiya qilinmadi',
    'training_input_batch_delete' => 'Training batch o‘chirilmadi',
    'training_image_save' => 'Training order rasmi saqlanmadi',
    'production_map_audit' => 'Workflow audit yuklanmadi',
    'production_map_save' => 'Production map saqlanmadi',
    'production_map_save_with_order' => 'Zakaz va production map saqlanmadi',
    'production_map_move_batch' => 'WIP batch ko‘chirilmagan',
    'apparatus_transfer' =>
      'Orderni boshqa apparatga ko‘chirish amalga oshmadi',
    'production_map_move' => 'Order apparati o‘zgartirilmadi',
    'production_map_sequence' => 'Orderlar ketma-ketligi saqlanmadi',
    'order_control_failed' => 'Order holati o‘zgartirilmadi',
    'wip_batches' => 'WIP batchlar yuklanmadi',
    'completed_orders' => 'Yakunlangan orderlar yuklanmadi',
    'completion_requests' => 'Tugatish so‘rovlari yuklanmadi',
    'completion_request_decision' => 'Tugatish so‘rovi qarori saqlanmadi',
    'completion_request_decisions' => 'Tugatish qarorlari yuklanmadi',
    'queue_policies' => 'Aparat navbat qoidalari yuklanmadi',
    'apparatus_capacity' => 'Aparat quvvati ma’lumotlari olinmadi',
    'apparatus_downtime' => 'Aparat downtime ma’lumoti saqlanmadi',
    'apparatus_schedule' => 'Aparat jadvali saqlanmadi',
    'apparatus_schedule_cancel' => 'Aparat jadvali bekor qilinmadi',
    'raw_material_rules' => 'Homashyo qoidalari yuklanmadi',
    'raw_material_start_requirements' =>
      'Homashyo ish boshlash talablari yuklanmadi',
    'raw_material_assignments' => 'Homashyo biriktirmalari yuklanmadi',
    'raw_material_assignment_orders' => 'Homashyo uchun orderlar yuklanmadi',
    'raw_material_assignment_candidates' => 'Homashyo nomzodlari yuklanmadi',
    'raw_material_assignment_candidate_orders' =>
      'Homashyo uchun mos orderlar yuklanmadi',
    'raw_material_intake' => 'Homashyo qabul qilinmadi',
    'raw_material_intake_candidates' =>
      'Qabul qilinadigan homashyolar yuklanmadi',
    'raw_material_history' => 'Homashyo tarixi yuklanmadi',
    'qolip_code_not_found' => 'Qolip ma’lumotlari tekshirilmadi',
    'queue_action_not_allowed' => 'Order navbat amali bajarilmadi',
    'progress_batch_not_found' => 'Progress QR amali bajarilmadi',
    'progress_qr_reprint' => 'WIP QR qayta chop etilmadi',
    'paddons_list' => 'Paddonlar yuklanmadi',
    'paddon_not_found' => 'Paddon ma’lumoti olinmadi',
    'paddon_create' => 'Paddon yaratilmadi',
    'paddon_item_add' => 'WIP paddonga qo‘shilmadi',
    'paddon_item_remove' => 'WIP paddondan chiqarilmadi',
    'production_map_live_failed' => 'Production map jonli holati olinmadi',
    'production_map_run' => 'Production map ishga tushirilmadi',
    _ => 'So‘ralgan amal bajarilmadi',
  };
  final statusSuffix = statusCode > 0 ? ' (HTTP $statusCode)' : '';
  final normalizedCode = code.trim().toLowerCase();
  if (normalizedCode.isEmpty ||
      normalizedCode == fallbackCode.trim().toLowerCase()) {
    return '$operation$statusSuffix';
  }
  return '$operation: $code$statusSuffix';
}

class AdminProductionWorkflowAuditViolation {
  const AdminProductionWorkflowAuditViolation({
    required this.code,
    required this.orderId,
    required this.subject,
    required this.detail,
  });

  final String code;
  final String orderId;
  final String subject;
  final String detail;

  factory AdminProductionWorkflowAuditViolation.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminProductionWorkflowAuditViolation(
      code: json['code']?.toString().trim() ?? '',
      orderId: json['order_id']?.toString().trim() ?? '',
      subject: json['subject']?.toString().trim() ?? '',
      detail: json['detail']?.toString().trim() ?? '',
    );
  }
}

class AdminProductionWorkflowAuditReport {
  const AdminProductionWorkflowAuditReport({
    required this.ok,
    required this.checkedOrderCount,
    required this.checkedBatchCount,
    required this.checkedSessionCount,
    required this.violations,
  });

  final bool ok;
  final int checkedOrderCount;
  final int checkedBatchCount;
  final int checkedSessionCount;
  final List<AdminProductionWorkflowAuditViolation> violations;

  factory AdminProductionWorkflowAuditReport.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawViolations = json['violations'];
    return AdminProductionWorkflowAuditReport(
      ok: json['ok'] == true,
      checkedOrderCount: (json['checked_order_count'] as num?)?.toInt() ?? 0,
      checkedBatchCount: (json['checked_batch_count'] as num?)?.toInt() ?? 0,
      checkedSessionCount:
          (json['checked_session_count'] as num?)?.toInt() ?? 0,
      violations: [
        if (rawViolations is List)
          for (final item in rawViolations)
            if (item is Map)
              AdminProductionWorkflowAuditViolation.fromJson(
                item.cast<String, dynamic>(),
              ),
      ],
    );
  }
}

bool _isSameProductionMapOrder(
  ProductionMapDefinition current,
  ProductionMapDefinition next,
) {
  return current.id.trim() == next.id.trim() &&
      current.title.trim() == next.title.trim() &&
      current.productCode.trim() == next.productCode.trim();
}

extension MobileApiAdminProductionMap on MobileApi {
Future<AdminSettings> adminRegenerateWerkaCode() async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/werka/code/regenerate'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin werka code regenerate failed');
    }
    return AdminSettings.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<void> adminResetOrders() async {
    if (await TestModeController.instance.isEnabled()) {
      throw const MobileApiException(
        code: 'order_reset_test_mode_unsupported',
        message: 'Order reset test rejimida mavjud emas',
      );
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/emergency-reset/orders'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'confirmation': 'RESET ORDERS'}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'order_reset_failed');
    }
  }

Future<List<AdminCapability>> adminCapabilities() async {
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/capabilities'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin capabilities failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map((item) => AdminCapability.fromJson(item as Map<String, dynamic>))
        .toList();
  }

Future<List<ProductionMapSaved>> adminProductionMaps() async {
    if (await TestModeController.instance.isEnabled()) {
      if (_testModeForceProductionMapMenuLoadFailure) {
        throw const MobileApiException(
          code: 'production_maps_list',
          message: 'Production maplar yuklanmadi',
        );
      }
      return List<ProductionMapSaved>.unmodifiable(_testModeProductionMaps);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_maps_list');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map(
          (item) => ProductionMapSaved.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

Future<AdminProductionWorkflowAuditReport> adminProductionMapAudit() async {
    if (await TestModeController.instance.isEnabled()) {
      return AdminProductionWorkflowAuditReport(
        ok: true,
        checkedOrderCount: _testModeProductionMaps.length,
        checkedBatchCount: 0,
        checkedSessionCount: 0,
        violations: const [],
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/audit'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_audit');
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map) {
      throw const MobileApiException(
        code: 'production_map_audit_invalid_response',
        message: 'Workflow audit javobi noto‘g‘ri',
      );
    }
    return AdminProductionWorkflowAuditReport.fromJson(
      payload.cast<String, dynamic>(),
    );
  }

Future<ProductionMapSaved> adminProductionMap(String id) async {
    final normalized = id.trim();
    if (await TestModeController.instance.isEnabled()) {
      return _testModeProductionMaps.firstWhere(
        (item) => item.map.id.trim() == normalized,
        orElse: () => throw const MobileApiException(
          code: 'map_not_found',
          message: 'Zakaz topilmadi',
        ),
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps',
        ).replace(queryParameters: {'id': normalized}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'map_not_found');
    }
    return ProductionMapSaved.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<ProductionMapSaved> adminSaveProductionMap(
    ProductionMapDefinition map,
  ) async {
    _requireCanonicalProductionMapApparatusIds(map);
    if (await TestModeController.instance.isEnabled()) {
      final originalMapId = map.id.trim();
      final normalizedMap = _testModeAssignOrderNumberIfMissing(map);
      final duplicate = _testModeProductionMaps.any(
        (item) =>
            item.map.orderNumber.trim().isNotEmpty &&
            item.map.orderNumber.trim() == normalizedMap.orderNumber.trim() &&
            !_isSameProductionMapOrder(item.map, normalizedMap),
      );
      if (duplicate) {
        throw const MobileApiException(
          code: 'duplicate_order_number',
          message: 'Bu raqam boshqa zakazga berilgan',
        );
      }
      final saved = ProductionMapSaved(
        map: normalizedMap,
        program: ProductionMapProgram(
          mapId: normalizedMap.id,
          productCode: normalizedMap.productCode,
          operations: [
            for (var i = 0; i < normalizedMap.nodes.length; i++)
              ProductionMapOperation(
                order: i + 1,
                nodeId: normalizedMap.nodes[i].id,
                opCode: normalizedMap.nodes[i].kind,
                args: {'title': normalizedMap.nodes[i].title},
              ),
          ],
        ),
      );
      _testModeProductionMaps.removeWhere(
        (item) =>
            item.map.id == originalMapId || item.map.id == normalizedMap.id,
      );
      _testModeProductionMaps.insert(0, saved);
      return saved;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(map.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_save');
    }
    return ProductionMapSaved.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<ProductionMapSaveWithOrderResult> adminSaveProductionMapWithOrder({
    required ProductionMapDefinition map,
    required CalculateOrderTemplate template,
  }) async {
    _requireCanonicalProductionMapApparatusIds(map);
    if (await TestModeController.instance.isEnabled()) {
      final previousIndex = _testModeProductionMaps.indexWhere(
        (item) => item.map.id.trim() == map.id.trim(),
      );
      ProductionMapSaved? previousMap;
      if (previousIndex >= 0) {
        previousMap = _testModeProductionMaps[previousIndex];
      }
      if (template.product.trim().isEmpty || template.widthMm <= 0) {
        throw const MobileApiException(
          code: 'calculate_order_save',
          message: 'Calculate order validation failed',
        );
      }
      ProductionMapSaved? savedMapForRollback;
      try {
        var orderMap =
            previousIndex < 0 ? _testModeAssignOrderNumberIfMissing(map) : map;
        if (previousIndex < 0) {
          orderMap = _orderMapWithTemplateRezkaKadrCount(orderMap, template);
        }
        final orderNumberWasGenerated =
            previousIndex < 0 && orderMap.id.trim() != map.id.trim();
        final savedMap = await adminSaveProductionMap(orderMap);
        savedMapForRollback = savedMap;
        final templateMap = _templateMapCopyForSave(savedMap.map, template);
        final savedTemplateMap = templateMap == null
            ? null
            : await adminSaveProductionMap(templateMap);
        final opensQuickTemplateAsOrder =
            template.sourceMapId.trim().isNotEmpty &&
                template.sourceMapId.trim() != savedMap.map.id.trim() &&
                _isSheetOrderMap(savedMap.map);
        final templateToSave = orderNumberWasGenerated
            ? template.copyWith(orderNumber: savedMap.map.orderNumber)
            : template;
        final savedTemplate = opensQuickTemplateAsOrder
            ? null
            : _testModeUpsertCalculateOrderTemplate(
                templateToSave.copyWith(
                  sourceMapId: savedTemplateMap?.map.id ??
                      _templateSourceMapIdForSave(savedMap.map, template),
                ),
              );
        return ProductionMapSaveWithOrderResult(
          saved: savedMap,
          template: savedTemplate,
        );
      } catch (error) {
        if (previousMap != null) {
          if (previousIndex >= 0) {
            _testModeProductionMaps[previousIndex] = previousMap;
          }
        } else {
          _testModeProductionMaps.removeWhere((item) {
            final itemId = item.map.id.trim();
            return itemId == map.id.trim() ||
                (savedMapForRollback != null &&
                    itemId == savedMapForRollback!.map.id.trim());
          });
        }
        rethrow;
      }
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/with-order'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'map': map.toJson(), 'template': template.toJson()}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'production_map_save_with_order',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return ProductionMapSaveWithOrderResult(
      saved: ProductionMapSaved.fromJson(
        (payload['saved'] as Map).cast<String, dynamic>(),
      ),
      template: payload['template'] is Map
          ? CalculateOrderTemplate.fromJson(
              (payload['template'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }

Future<List<ProductionMapSaved>> adminMoveProductionMapOrdersBatch({
    required List<String> mapIds,
    required String fromApparatus,
    required String toApparatus,
  }) async {
    final normalizedFrom = _requireCanonicalApparatusId(fromApparatus);
    final normalizedTo = _requireCanonicalApparatusId(toApparatus);
    if (await TestModeController.instance.isEnabled()) {
      final sourceApparatus = _testModeRequiredApparatus(normalizedFrom);
      final targetApparatus = _testModeRequiredApparatus(normalizedTo);
      final normalizedIds = [
        for (final id in mapIds)
          if (id.trim().isNotEmpty) id.trim(),
      ];
      if (normalizedIds.isEmpty) {
        throw const MobileApiException(
          code: 'move_not_allowed',
          message: 'Zakaz tanlanmadi',
        );
      }
      final originals = <ProductionMapSaved>[];
      for (final mapId in normalizedIds) {
        final index = _testModeProductionMaps.indexWhere(
          (item) => item.map.id.trim() == mapId,
        );
        if (index < 0) {
          throw const MobileApiException(
            code: 'map_not_found',
            message: 'Zakaz topilmadi',
          );
        }
        originals.add(_testModeProductionMaps[index]);
      }
      final updated = <ProductionMapSaved>[];
      for (final current in originals) {
        _testModeEnsurePendingApparatusMove(
          orderId: current.map.id,
          fromApparatus: normalizedFrom,
        );
        if (!productionMapCanMoveOrderToApparatus(
          nodes: current.map.nodes,
          fromApparatus: sourceApparatus,
          toApparatus: targetApparatus,
          rollCount: current.map.rollCount,
          widthMm: current.map.widthMm,
        )) {
          throw const MobileApiException(
            code: 'move_not_allowed',
            message: 'Zakaz bu aparatga tushmaydi',
          );
        }
        final nodes = productionMapReassignAlternativeApparatusAssignment(
              nodes: current.map.nodes,
              fromApparatus: sourceApparatus,
              toApparatus: targetApparatus,
            ) ??
            productionMapReassignApparatusNodes(
              nodes: current.map.nodes,
              fromApparatus: sourceApparatus,
              toApparatus: targetApparatus,
            );
        if (nodes == null) {
          throw const MobileApiException(
            code: 'move_not_allowed',
            message: 'Zakaz bu aparatga tushmaydi',
          );
        }
        updated.add(
          ProductionMapSaved(
            map: current.map.copyWith(nodes: nodes),
            program: current.program,
          ),
        );
      }
      for (var i = 0; i < normalizedIds.length; i++) {
        final index = _testModeProductionMaps.indexWhere(
          (item) => item.map.id.trim() == normalizedIds[i],
        );
        if (index >= 0) {
          _testModeProductionMaps[index] = updated[i];
        }
      }
      return updated;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/move-batch'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'from_apparatus': normalizedFrom,
          'to_apparatus': normalizedTo,
          'map_ids': mapIds,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_move_batch');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['saved'];
    if (raw is! List) {
      return const [];
    }
    return [
      for (final item in raw)
        if (item is Map)
          ProductionMapSaved.fromJson(item.cast<String, dynamic>()),
    ];
  }

Future<ProductionMapSaved> adminTransferProductionMapOrder({
    required String orderId,
    required String fromApparatus,
    required String toApparatus,
    required String reason,
    required String idempotencyKey,
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedFrom = _requireCanonicalApparatusId(fromApparatus);
    final normalizedTo = _requireCanonicalApparatusId(toApparatus);
    final normalizedReason = reason.trim();
    final normalizedKey = idempotencyKey.trim();
    if (normalizedOrderId.isEmpty) {
      throw const MobileApiException(
        code: 'apparatus_transfer_order_not_paused',
        message: 'Avariya ko‘chirish ma’lumotlari to‘liq emas',
      );
    }
    if (normalizedReason.isEmpty) {
      throw const MobileApiException(
        code: 'apparatus_transfer_reason_required',
        message: 'Avariya sababini kiriting',
      );
    }
    if (normalizedKey.isEmpty || normalizedKey.length > 200) {
      throw const MobileApiException(
        code: 'apparatus_transfer_idempotency_required',
        message: 'Avariya ko‘chirish identifikatori mavjud emas',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final sourceApparatus = _testModeRequiredApparatus(normalizedFrom);
      final targetApparatus = _testModeRequiredApparatus(normalizedTo);
      final existing = _testModeApparatusTransfers[normalizedKey];
      if (existing != null) {
        if (existing.orderId != normalizedOrderId ||
            existing.fromApparatus != normalizedFrom ||
            existing.toApparatus != normalizedTo) {
          throw const MobileApiException(
            code: 'apparatus_transfer_idempotency_conflict',
            message:
                'Avariya ko‘chirish identifikatori boshqa amalda ishlatilgan',
          );
        }
        return existing.saved;
      }
      if (normalizedFrom == normalizedTo) {
        throw const MobileApiException(
          code: 'move_not_allowed',
          message: 'Zakaz shu apparatda qolmoqda',
        );
      }
      final sourceKey = normalizedFrom;
      final targetKey = normalizedTo;
      if (sourceKey == targetKey) {
        throw const MobileApiException(
          code: 'move_not_allowed',
          message: 'Zakaz shu apparatda qolmoqda',
        );
      }
      final sourceStates = Map<String, String>.from(
        _testModeApparatusQueueStates[sourceKey] ?? const {},
      );
      final targetStates = Map<String, String>.from(
        _testModeApparatusQueueStates[targetKey] ?? const {},
      );
      if (apparatusQueueOrderStateFromRaw(sourceStates[normalizedOrderId]) !=
          ApparatusQueueOrderState.paused) {
        throw const MobileApiException(
          code: 'apparatus_transfer_order_not_paused',
          message: 'Ko‘chirishdan oldin orderni pause qiling',
        );
      }
      if (targetStates.containsKey(normalizedOrderId)) {
        throw const MobileApiException(
          code: 'apparatus_transfer_target_conflict',
          message: 'Order tanlangan apparatda allaqachon mavjud',
        );
      }
      final index = _testModeProductionMaps.indexWhere(
        (item) => item.map.id.trim() == normalizedOrderId,
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'map_not_found',
          message: 'Zakaz topilmadi',
        );
      }
      final current = _testModeProductionMaps[index];
      if (!productionMapCanMoveOrderToApparatus(
        nodes: current.map.nodes,
        fromApparatus: sourceApparatus,
        toApparatus: targetApparatus,
        rollCount: current.map.rollCount,
        widthMm: current.map.widthMm,
      )) {
        throw const MobileApiException(
          code: 'move_not_allowed',
          message: 'Zakaz bu aparatga tushmaydi',
        );
      }
      final nodes = productionMapReassignAlternativeApparatusAssignment(
            nodes: current.map.nodes,
            fromApparatus: sourceApparatus,
            toApparatus: targetApparatus,
          ) ??
          productionMapReassignApparatusNodes(
            nodes: current.map.nodes,
            fromApparatus: sourceApparatus,
            toApparatus: targetApparatus,
          );
      if (nodes == null) {
        throw const MobileApiException(
          code: 'move_not_allowed',
          message: 'Zakaz bu aparatga tushmaydi',
        );
      }
      final saved = ProductionMapSaved(
        map: current.map.copyWith(nodes: nodes),
        program: current.program,
      );
      final sourceSequence = List<String>.from(
        _testModeApparatusSequences[sourceKey] ?? const [],
      )..removeWhere((id) => id.trim() == normalizedOrderId);
      final targetSequence =
          List<String>.from(_testModeApparatusSequences[targetKey] ?? const [])
            ..removeWhere((id) => id.trim() == normalizedOrderId)
            ..add(normalizedOrderId);
      sourceStates.remove(normalizedOrderId);
      targetStates[normalizedOrderId] = 'paused';
      _testModeProductionMaps[index] = saved;
      _testModeApparatusSequences[sourceKey] = sourceSequence;
      _testModeApparatusSequences[targetKey] = targetSequence;
      _testModeApparatusQueueStates[sourceKey] = sourceStates;
      _testModeApparatusQueueStates[targetKey] = targetStates;
      _testModeMoveScheduleReservations(
        orderId: normalizedOrderId,
        fromApparatusId: sourceKey,
        toApparatusId: targetKey,
      );
      _testModeApparatusTransfers[normalizedKey] =
          _TestModeApparatusTransferReceipt(
        orderId: normalizedOrderId,
        fromApparatus: normalizedFrom,
        toApparatus: normalizedTo,
        saved: saved,
      );
      return saved;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/apparatus-transfer',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'order_id': normalizedOrderId,
          'from_apparatus': normalizedFrom,
          'to_apparatus': normalizedTo,
          'reason': normalizedReason,
          'idempotency_key': normalizedKey,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'apparatus_transfer');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final rawSaved = payload['saved'];
    if (rawSaved is! Map) {
      throw const MobileApiException(
        code: 'apparatus_transfer_invalid_response',
        message: 'Avariya ko‘chirish javobi noto‘g‘ri',
      );
    }
    return ProductionMapSaved.fromJson(rawSaved.cast<String, dynamic>());
  }

Future<ProductionMapSaved> adminMoveProductionMapOrder({
    required String mapId,
    required String fromApparatus,
    required String toApparatus,
  }) async {
    final normalizedFrom = _requireCanonicalApparatusId(fromApparatus);
    final normalizedTo = _requireCanonicalApparatusId(toApparatus);
    if (await TestModeController.instance.isEnabled()) {
      final sourceApparatus = _testModeRequiredApparatus(normalizedFrom);
      final targetApparatus = _testModeRequiredApparatus(normalizedTo);
      final index = _testModeProductionMaps.indexWhere(
        (item) => item.map.id.trim() == mapId.trim(),
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'map_not_found',
          message: 'Zakaz topilmadi',
        );
      }
      final current = _testModeProductionMaps[index];
      _testModeEnsurePendingApparatusMove(
        orderId: current.map.id,
        fromApparatus: normalizedFrom,
      );
      if (!productionMapCanMoveOrderToApparatus(
        nodes: current.map.nodes,
        fromApparatus: sourceApparatus,
        toApparatus: targetApparatus,
        rollCount: current.map.rollCount,
        widthMm: current.map.widthMm,
      )) {
        throw const MobileApiException(
          code: 'move_not_allowed',
          message: 'Zakaz bu aparatga tushmaydi',
        );
      }
      final nodes = productionMapReassignAlternativeApparatusAssignment(
            nodes: current.map.nodes,
            fromApparatus: sourceApparatus,
            toApparatus: targetApparatus,
          ) ??
          productionMapReassignApparatusNodes(
            nodes: current.map.nodes,
            fromApparatus: sourceApparatus,
            toApparatus: targetApparatus,
          );
      if (nodes == null) {
        throw const MobileApiException(
          code: 'move_not_allowed',
          message: 'Zakaz bu aparatga tushmaydi',
        );
      }
      final saved = ProductionMapSaved(
        map: current.map.copyWith(nodes: nodes),
        program: current.program,
      );
      _testModeProductionMaps[index] = saved;
      return saved;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/move'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'map_id': mapId,
          'from_apparatus': normalizedFrom,
          'to_apparatus': normalizedTo,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_move');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return ProductionMapSaved.fromJson(
      (payload['saved'] as Map).cast<String, dynamic>(),
    );
  }

Uri adminProductionMapLiveUri() {
    final Uri base = Uri.parse(MobileApi.baseUrl);
    final String scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: scheme,
      path: '/v1/mobile/admin/production-maps/live',
      queryParameters: {'token': requireToken()},
    );
  }

Stream<AdminProductionMapLiveSnapshot> adminProductionMapLiveEvents() async* {
    if (await TestModeController.instance.isEnabled()) {
      return;
    }
    await for (final event in connectWarehouseLive(
      adminProductionMapLiveUri(),
    )) {
      if (event['ok'] == true) {
        yield AdminProductionMapLiveSnapshot.fromJson(event);
        continue;
      }
      final errorCode = event['error']?.toString().trim() ?? '';
      throw MobileApiException(
        code: errorCode.isEmpty ? 'production_map_live_failed' : errorCode,
        message: _adminProductionMapUnknownErrorMessage(
          code: errorCode,
          fallbackCode: 'production_map_live_failed',
          statusCode: 0,
        ),
      );
    }
  }

Future<ProductionMapRunResult> adminRunProductionMap(
    ProductionMapRunRequest input,
  ) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/run'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(input.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_run');
    }
    return ProductionMapRunResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
