import 'package:flutter/material.dart';

class QolipColorOption {
  const QolipColorOption({
    required this.name,
    required this.value,
  });

  final String name;
  final String value;
}

const qolipDefaultColors = <QolipColorOption>[
  QolipColorOption(name: 'Qizil', value: '#E53935'),
  QolipColorOption(name: 'To‘q sariq', value: '#FB8C00'),
  QolipColorOption(name: 'Sariq', value: '#FDD835'),
  QolipColorOption(name: 'Yashil', value: '#43A047'),
  QolipColorOption(name: 'Moviy', value: '#00ACC1'),
  QolipColorOption(name: 'Ko‘k', value: '#1E88E5'),
  QolipColorOption(name: 'To‘q ko‘k', value: '#3949AB'),
  QolipColorOption(name: 'Binafsha', value: '#8E24AA'),
  QolipColorOption(name: 'Pushti', value: '#D81B60'),
  QolipColorOption(name: 'Jigarrang', value: '#6D4C41'),
  QolipColorOption(name: 'Kulrang', value: '#757575'),
  QolipColorOption(name: 'Qora', value: '#212121'),
  QolipColorOption(name: 'Oq', value: '#FFFFFF'),
];

const qolipPantonPrefix = 'PANTON';

String qolipPantonColorValue(int number) => '$qolipPantonPrefix $number';

int? qolipPantonNumber(String value) {
  final match =
      RegExp(r'^PANTON\s+([1-7])$').firstMatch(value.trim().toUpperCase());
  return match == null ? null : int.tryParse(match.group(1)!);
}

Color qolipColorValue(String value) {
  final normalized = value.trim().replaceFirst('#', '');
  final parsed = int.tryParse(normalized, radix: 16);
  return Color(0xFF000000 | (parsed ?? 0x757575));
}

class QolipColorPicker extends StatelessWidget {
  const QolipColorPicker({
    super.key,
    this.selectedColor,
    this.onChanged,
    this.selectedColors,
    this.onColorsChanged,
    this.maxSelectedColors,
    this.enabled = true,
    this.availablePantonNumber = 1,
  });

  final String? selectedColor;
  final ValueChanged<String>? onChanged;
  final Set<String>? selectedColors;
  final ValueChanged<Set<String>>? onColorsChanged;
  final int? maxSelectedColors;
  final bool enabled;
  final int? availablePantonNumber;

  @override
  Widget build(BuildContext context) {
    final multiSelect = selectedColors != null && onColorsChanged != null;
    final selected = selectedColor?.trim().toUpperCase();
    final selectedPantonNumber = qolipPantonNumber(selectedColor ?? '');
    final pantonNumber = selectedPantonNumber ?? availablePantonNumber;

    void selectColor(String value) {
      if (!multiSelect) {
        onChanged?.call(value);
        return;
      }
      final next = {...selectedColors!};
      if (!next.add(value)) {
        next.remove(value);
      } else if (maxSelectedColors != null &&
          next.length > maxSelectedColors!) {
        return;
      }
      onColorsChanged!(next);
    }

    bool isSelected(String value) {
      if (multiSelect) {
        return selectedColors!.contains(value);
      }
      return selected == value;
    }

    return Wrap(
      spacing: 4,
      runSpacing: 6,
      children: [
        for (final option in qolipDefaultColors)
          _QolipColorTile(
            option: option,
            selected: isSelected(option.value),
            isPanton: false,
            onTap: enabled ? () => selectColor(option.value) : null,
          ),
        if (pantonNumber != null)
          _QolipColorTile(
            option: QolipColorOption(
              name: 'Panton $pantonNumber',
              value: qolipPantonColorValue(pantonNumber),
            ),
            selected: multiSelect
                ? selectedColors!.contains(qolipPantonColorValue(pantonNumber))
                : selectedPantonNumber == pantonNumber,
            isPanton: true,
            onTap: enabled
                ? () => selectColor(qolipPantonColorValue(pantonNumber))
                : null,
          ),
      ],
    );
  }
}

class _QolipColorTile extends StatelessWidget {
  const _QolipColorTile({
    required this.option,
    required this.selected,
    required this.isPanton,
    this.onTap,
  });

  final QolipColorOption option;
  final bool selected;
  final bool isPanton;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: option.name,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 60,
          height: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPanton ? null : qolipColorValue(option.value),
                  gradient: isPanton
                      ? const LinearGradient(
                          colors: [
                            Color(0xFFE53935),
                            Color(0xFFFDD835),
                            Color(0xFF43A047),
                            Color(0xFF3949AB),
                            Color(0xFFD81B60),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? scheme.onSurface : scheme.outlineVariant,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        size: 25,
                        color:
                            qolipColorValue(option.value).computeLuminance() >
                                    0.65
                                ? scheme.onSurface
                                : Colors.white,
                      )
                    : null,
              ),
              const SizedBox(height: 3),
              Text(
                option.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
