import 'package:flutter/material.dart';

const List<String> kQolipGridLetters = [
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
];

const int kQolipGridColumnCount = 9;

Future<String?> showQolipCellPickerSheet(
  BuildContext context, {
  String title = 'Joy tanlang',
  String? excludeCellLabel,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (context) => _QolipCellPickerSheet(
      title: title,
      excludeCellLabel: excludeCellLabel?.trim().toUpperCase(),
    ),
  );
}

String? normalizeQolipCellLabel(String raw) {
  final letters = raw.replaceAll(RegExp(r'[^A-Za-z]'), '');
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (letters.isEmpty || digits.isEmpty) {
    return null;
  }
  final column = int.tryParse(digits);
  if (column == null || column < 1 || column > kQolipGridColumnCount) {
    return null;
  }
  return '${letters[0].toUpperCase()}$column';
}

List<String> allQolipCellLabels() {
  return [
    for (final letter in kQolipGridLetters)
      for (var column = 1; column <= kQolipGridColumnCount; column++)
        '$letter$column',
  ];
}

List<String> searchQolipCellLabels(String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return const [];
  }
  final normalized = normalizeQolipCellLabel(trimmed);
  final lower = trimmed.toLowerCase();
  final matches = allQolipCellLabels().where((label) {
    if (normalized != null && label == normalized) {
      return true;
    }
    return label.toLowerCase().startsWith(lower) ||
        label.toLowerCase().contains(lower);
  }).toList(growable: false);
  if (normalized != null && matches.contains(normalized)) {
    matches.remove(normalized);
    matches.insert(0, normalized);
  }
  return matches;
}

class _QolipCellPickerSheet extends StatefulWidget {
  const _QolipCellPickerSheet({
    required this.title,
    this.excludeCellLabel,
  });

  final String title;
  final String? excludeCellLabel;

  @override
  State<_QolipCellPickerSheet> createState() => _QolipCellPickerSheetState();
}

class _QolipCellPickerSheetState extends State<_QolipCellPickerSheet> {
  final _searchController = TextEditingController();
  String _selectedLetter = 'A';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final excluded = widget.excludeCellLabel;
    if (excluded != null && excluded.isNotEmpty) {
      final letter = normalizeQolipCellLabel(excluded)?.substring(0, 1);
      if (letter != null && kQolipGridLetters.contains(letter)) {
        _selectedLetter = letter;
      }
    }
    _searchController.addListener(() {
      final next = _searchController.text;
      if (next == _searchQuery) {
        return;
      }
      setState(() => _searchQuery = next);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isExcluded(String cellLabel) =>
      widget.excludeCellLabel == cellLabel.trim().toUpperCase();

  void _selectCell(String cellLabel) {
    if (_isExcluded(cellLabel)) {
      return;
    }
    Navigator.of(context).pop(cellLabel);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    final searchResults = searchQolipCellLabels(_searchQuery)
        .where((label) => !_isExcluded(label))
        .take(24)
        .toList(growable: false);
    final searching = _searchQuery.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, bottomInset + 8),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Masalan: A1, B3, C9',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _searchController.clear,
                            icon: const Icon(Icons.close_rounded),
                          ),
                    isDense: true,
                  ),
                  onSubmitted: (value) {
                    final normalized = normalizeQolipCellLabel(value);
                    if (normalized != null && !_isExcluded(normalized)) {
                      _selectCell(normalized);
                    }
                  },
                ),
              ),
              Flexible(
                child: searching
                    ? _SearchResultsList(
                        results: searchResults,
                        query: _searchQuery,
                        onSelect: _selectCell,
                      )
                    : _LetterColumnPicker(
                        selectedLetter: _selectedLetter,
                        excludeCellLabel: widget.excludeCellLabel,
                        onLetterChanged: (letter) {
                          setState(() => _selectedLetter = letter);
                        },
                        onSelect: _selectCell,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.results,
    required this.query,
    required this.onSelect,
  });

  final List<String> results;
  final String query;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final normalized = normalizeQolipCellLabel(query);
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Text(
          'Mos joy topilmadi. A1 yoki B3 kabi yozing.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        if (normalized != null && results.first == normalized) ...[
          FilledButton(
            onPressed: () => onSelect(normalized),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              '$normalized — tanlash',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          if (results.length > 1) ...[
            const SizedBox(height: 12),
            Text(
              'Boshqa mos joylar',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
          ],
        ],
        for (final label in results)
          if (normalized == null || label != normalized)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.tonal(
                onPressed: () => onSelect(label),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ),
      ],
    );
  }
}

class _LetterColumnPicker extends StatelessWidget {
  const _LetterColumnPicker({
    required this.selectedLetter,
    required this.excludeCellLabel,
    required this.onLetterChanged,
    required this.onSelect,
  });

  final String selectedLetter;
  final String? excludeCellLabel;
  final ValueChanged<String> onLetterChanged;
  final ValueChanged<String> onSelect;

  bool _isExcluded(String cellLabel) =>
      excludeCellLabel == cellLabel.trim().toUpperCase();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        Text(
          'Qator',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kQolipGridLetters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final letter = kQolipGridLetters[index];
              final selected = letter == selectedLetter;
              return FilterChip(
                label: Text(letter),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => onLetterChanged(letter),
                labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? scheme.onSecondaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                selectedColor: scheme.secondaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '$selectedLetter qatori',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
          children: [
            for (var column = 1; column <= kQolipGridColumnCount; column++)
              _LargeCellButton(
                cellLabel: '$selectedLetter$column',
                excluded: _isExcluded('$selectedLetter$column'),
                onTap: () => onSelect('$selectedLetter$column'),
              ),
          ],
        ),
      ],
    );
  }
}

class _LargeCellButton extends StatelessWidget {
  const _LargeCellButton({
    required this.cellLabel,
    required this.excluded,
    required this.onTap,
  });

  final String cellLabel;
  final bool excluded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color:
          excluded ? scheme.surfaceContainerHighest : scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: excluded ? null : onTap,
        child: Center(
          child: Text(
            cellLabel,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: excluded
                      ? scheme.onSurfaceVariant.withValues(alpha: 0.45)
                      : scheme.onSecondaryContainer,
                ),
          ),
        ),
      ),
    );
  }
}
