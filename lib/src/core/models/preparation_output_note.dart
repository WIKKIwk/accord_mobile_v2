const preparationNoteLimit = 2000;
const preparationNoteSelectionLimit = 100;

enum PreparationNoteViewerRole {
  rezkaMaster('rezka_master', 'Rezka master'),
  homashyoRezkachi('homashyo_rezkachi', 'Homashyo rezkachisi'),
  rezkaWorker('rezka_worker', 'Ishchi rezka'),
  aparatchi('aparatchi', 'Boshqa aparatchilar'),
  tayyorlovMasteri('tayyorlov_masteri', 'Tayyorlov masteri'),
  materialTaminotchi('material_taminotchi', 'Material ta’minotchisi'),
  werka('werka', 'Werka'),
  metalayzer('metalayzer', 'Metalayzer'),
  qolipchi('qolipchi', 'Qolipchi'),
  brigader('brigader', 'Brigader'),
  admin('admin', 'Admin');

  const PreparationNoteViewerRole(this.code, this.label);

  final String code;
  final String label;
}

class PreparationNoteAudience {
  const PreparationNoteAudience.all() : roles = null;

  PreparationNoteAudience.selected(Iterable<PreparationNoteViewerRole> roles)
      : roles = Set.unmodifiable(roles);

  factory PreparationNoteAudience.fromJson(Object? value) {
    if (value == null || (value is Map && value['mode'] == 'all')) {
      return const PreparationNoteAudience.all();
    }
    if (value is! Map || value['mode'] != 'roles' || value['roles'] is! List) {
      throw const FormatException('Eslatma rollari noto‘g‘ri');
    }
    return PreparationNoteAudience.selected(
      (value['roles'] as List).map((code) =>
          PreparationNoteViewerRole.values.firstWhere(
            (role) => role.code == code,
            orElse: () => throw const FormatException('Eslatma roli noto‘g‘ri'),
          )),
    );
  }

  final Set<PreparationNoteViewerRole>? roles;
  bool get isAll => roles == null;

  Map<String, Object> toJson() => {
        'mode': isAll ? 'all' : 'roles',
        if (roles case final selected?)
          'roles': [
            for (final role in PreparationNoteViewerRole.values)
              if (selected.contains(role)) role.code,
          ],
      };

  @override
  bool operator ==(Object other) {
    final selected = roles;
    return other is PreparationNoteAudience &&
        selected?.length == other.roles?.length &&
        (selected == null || selected.containsAll(other.roles!));
  }

  @override
  int get hashCode => roles == null ? 0 : Object.hashAllUnordered(roles!);
}

class PreparationOutputNote {
  const PreparationOutputNote({
    required this.text,
    required this.revision,
    this.audience = const PreparationNoteAudience.all(),
  });

  final String text;
  final int revision;
  final PreparationNoteAudience audience;

  static PreparationOutputNote? fromJson(Object? value) {
    if (value == null) return null;
    if (value is! Map ||
        value['text'] is! String ||
        value['revision'] is! int) {
      throw const FormatException('Eslatma ma’lumoti noto‘g‘ri');
    }
    final text = value['text'] as String;
    final revision = value['revision'] as int;
    if (revision < 0 ||
        revision > 9007199254740991 ||
        (revision == 0 && text.isNotEmpty) ||
        text.runes.length > preparationNoteLimit ||
        text.contains('\u0000')) {
      throw const FormatException('Eslatma ma’lumoti noto‘g‘ri');
    }
    return PreparationOutputNote(
      text: text,
      revision: revision,
      audience: PreparationNoteAudience.fromJson(value['audience']),
    );
  }
}

class PreparationRollNotes {
  PreparationRollNotes.fromJson(Map<String, dynamic> json)
      : batch = PreparationOutputNote.fromJson(json['batch_note']),
        roll = PreparationOutputNote.fromJson(json['roll_note']);

  final PreparationOutputNote? batch;
  final PreparationOutputNote? roll;

  bool get isEmpty =>
      (batch?.text.isEmpty ?? true) && (roll?.text.isEmpty ?? true);
}
