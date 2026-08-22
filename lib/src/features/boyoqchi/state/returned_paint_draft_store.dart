import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/returned_paint_models.dart';

class ReturnedPaintDraft {
  ReturnedPaintDraft._({
    required void Function() onChanged,
    Map<String, List<String>> valuesByStateKey = const {},
    Map<String, List<String>> dynamicFieldLabelsByStateKey = const {},
    int selectedUsageIndex = 0,
    ReturnedPaintImage? image,
  })  : _onChanged = onChanged,
        _valuesByStateKey = {
          for (final entry in valuesByStateKey.entries)
            entry.key: List<String>.from(entry.value),
        },
        _dynamicFieldLabelsByStateKey = {
          for (final entry in dynamicFieldLabelsByStateKey.entries)
            entry.key: List<String>.from(entry.value),
        },
        _selectedUsageIndex = selectedUsageIndex == 1 ? 1 : 0,
        _image = image;

  final void Function() _onChanged;
  final Map<String, List<String>> _valuesByStateKey;
  final Map<String, List<String>> _dynamicFieldLabelsByStateKey;
  int _selectedUsageIndex;
  ReturnedPaintImage? _image;

  int get selectedUsageIndex => _selectedUsageIndex;

  set selectedUsageIndex(int value) {
    final normalized = value == 1 ? 1 : 0;
    if (_selectedUsageIndex == normalized) return;
    _selectedUsageIndex = normalized;
    _onChanged();
  }

  ReturnedPaintImage? get image => _image;

  void setImage(ReturnedPaintImage? value) {
    if (_image?.imageId == value?.imageId) return;
    _image = value;
    _onChanged();
  }

  List<String> valuesFor(String stateKey, int length) {
    final existing = _valuesByStateKey[stateKey];
    if (existing == null) return List<String>.filled(length, '');
    final values = List<String>.filled(length, '');
    for (var index = 0; index < existing.length && index < length; index++) {
      values[index] = existing[index];
    }
    return values;
  }

  void setValue(String stateKey, int index, String value, int length) {
    final values = valuesFor(stateKey, length);
    if (index < 0 || index >= values.length || values[index] == value) return;
    values[index] = value;
    _valuesByStateKey[stateKey] = values;
    _onChanged();
  }

  List<String> dynamicFieldLabelsFor(String stateKey) =>
      List<String>.from(_dynamicFieldLabelsByStateKey[stateKey] ?? const []);

  void addNamedField(String stateKey, String label) {
    final normalized = label.trim();
    if (normalized.isEmpty) return;
    final labels = dynamicFieldLabelsFor(stateKey);
    if (labels
        .any((value) => value.toLowerCase() == normalized.toLowerCase())) {
      return;
    }
    labels.add(normalized);
    _dynamicFieldLabelsByStateKey[stateKey] = labels;
    _onChanged();
  }

  List<String> fieldLabelsFor(String stateKey, List<String> baseLabels) {
    return [
      ...baseLabels,
      ...dynamicFieldLabelsFor(stateKey),
    ];
  }

  Map<String, dynamic> toJson() => {
        'values': _valuesByStateKey,
        'dynamic_field_labels': _dynamicFieldLabelsByStateKey,
        'selected_usage_index': _selectedUsageIndex,
        if (_image != null) 'image': _image!.toJson(),
      };
}

class ReturnedPaintDraftStore {
  ReturnedPaintDraftStore._();

  static final ReturnedPaintDraftStore instance = ReturnedPaintDraftStore._();
  static const _preferencePrefix = 'returned_paint_draft_v1_';

  final Map<String, ReturnedPaintDraft> _cache = {};
  final Map<String, Future<void>> _writeChains = {};

  Future<ReturnedPaintDraft> load({
    required String scope,
    ReturnedPaintImage? initialImage,
  }) async {
    final normalizedScope = scope.trim();
    final cached = _cache[normalizedScope];
    if (cached != null) return cached;

    Map<String, dynamic> json = const {};
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_preferenceKey(normalizedScope));
    if (encoded != null && encoded.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is Map) json = decoded.cast<String, dynamic>();
      } catch (_) {
        json = const {};
      }
    }

    final values = <String, List<String>>{};
    final rawValues = json['values'];
    if (rawValues is Map) {
      for (final entry in rawValues.entries) {
        final rawList = entry.value;
        if (rawList is List) {
          values[entry.key.toString()] =
              rawList.map((value) => value.toString()).toList();
        }
      }
    }
    final dynamicFieldLabels = <String, List<String>>{};
    final legacyDynamicFields = !json.containsKey('dynamic_field_labels') &&
        json.containsKey('pantone_counts');
    final rawDynamicFieldLabels = json['dynamic_field_labels'];
    if (rawDynamicFieldLabels is Map) {
      for (final entry in rawDynamicFieldLabels.entries) {
        if (entry.value is List) {
          dynamicFieldLabels[entry.key.toString()] = (entry.value as List)
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toList();
        }
      }
    } else {
      // Preserve drafts created before named dynamic fields were introduced.
      final rawPantoneCounts = json['pantone_counts'];
      if (rawPantoneCounts is Map) {
        for (final entry in rawPantoneCounts.entries) {
          final count = (entry.value as num?)?.toInt() ?? 0;
          if (count > 0) {
            dynamicFieldLabels[entry.key.toString()] = [
              for (var index = 1; index <= count; index++) 'Pantone $index',
            ];
          }
        }
      }
    }
    if (legacyDynamicFields) {
      _migrateLegacyColorDrafts(values, dynamicFieldLabels);
    }
    final rawImage = json['image'];
    final storedImage = rawImage is Map
        ? ReturnedPaintImage.fromJson(rawImage.cast<String, dynamic>())
        : null;

    late final ReturnedPaintDraft draft;
    draft = ReturnedPaintDraft._(
      onChanged: () => _schedulePersist(normalizedScope, draft),
      valuesByStateKey: values,
      dynamicFieldLabelsByStateKey: dynamicFieldLabels,
      selectedUsageIndex: (json['selected_usage_index'] as num?)?.toInt() ?? 0,
      image: storedImage?.imageId.trim().isNotEmpty == true
          ? storedImage
          : initialImage,
    );
    _cache[normalizedScope] = draft;
    if (storedImage == null && initialImage != null) {
      _schedulePersist(normalizedScope, draft);
    }
    return draft;
  }

  Future<void> clear(String scope) async {
    final normalizedScope = scope.trim();
    _cache.remove(normalizedScope);
    await (_writeChains.remove(normalizedScope) ?? Future<void>.value());
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_preferenceKey(normalizedScope));
  }

  Future<void> flush(String scope) =>
      _writeChains[scope.trim()] ?? Future<void>.value();

  void resetMemoryForTest() {
    _cache.clear();
    _writeChains.clear();
  }

  void _schedulePersist(String scope, ReturnedPaintDraft draft) {
    final previous = _writeChains[scope] ?? Future<void>.value();
    _writeChains[scope] = previous.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _preferenceKey(scope),
        jsonEncode(draft.toJson()),
      );
    });
    unawaited(_writeChains[scope]);
  }

  String _preferenceKey(String scope) =>
      '$_preferencePrefix${base64Url.encode(utf8.encode(scope))}';

  void _migrateLegacyColorDrafts(
    Map<String, List<String>> values,
    Map<String, List<String>> dynamicFieldLabels,
  ) {
    const legacyColorFieldCount = 9;
    for (final entry in values.entries.toList()) {
      final parts = entry.key.split(':');
      if (parts.length != 2 || entry.value.length < legacyColorFieldCount) {
        continue;
      }
      final usage = parts.first;
      final paint = parts.last;
      if (paint == 'Lak' || paint == 'Spirtlar' || paint == 'Mix') continue;

      final oldValues = entry.value;
      values[entry.key] = [
        oldValues[1],
        oldValues[2],
        oldValues[3],
        oldValues[4],
        oldValues[5],
        oldValues[6],
        oldValues[8],
      ];

      final oldDynamicLabels = dynamicFieldLabels[entry.key] ?? const [];
      final oldDynamicValues = oldValues.skip(legacyColorFieldCount).toList();
      if (oldDynamicLabels.isNotEmpty) {
        values[entry.key]!.addAll(oldDynamicValues);
      }

      final oldMix = oldValues.first.trim();
      if (oldMix.isNotEmpty) {
        final mixKey = '$usage:Mix';
        final mixLabels = dynamicFieldLabels[mixKey] ?? <String>[];
        final mixLabel = '$paint Mix';
        if (!mixLabels.contains(mixLabel)) {
          mixLabels.add(mixLabel);
          dynamicFieldLabels[mixKey] = mixLabels;
          values[mixKey] = [
            ...(values[mixKey] ?? const <String>[]),
            oldMix,
          ];
        }
      }
    }
  }
}

String returnedPaintWorkerDraftScope({
  required String actorRef,
  required String orderId,
  required String apparatus,
}) =>
    'worker:${actorRef.trim()}:${orderId.trim()}:${apparatus.trim()}';

String returnedPaintBoyoqchiDraftScope({
  required String actorRef,
  required String requestId,
}) =>
    'boyoqchi:${actorRef.trim()}:${requestId.trim()}';
