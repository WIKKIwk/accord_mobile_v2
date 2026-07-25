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
];

const qolipPantonColorValue = 'PANTON';

const qolipPantonColors = <QolipColorOption>[
  QolipColorOption(name: 'Panton 1', value: 'PANTON 1'),
  QolipColorOption(name: 'Panton 2', value: 'PANTON 2'),
  QolipColorOption(name: 'Panton 3', value: 'PANTON 3'),
  QolipColorOption(name: 'Panton 4', value: 'PANTON 4'),
  QolipColorOption(name: 'Panton 5', value: 'PANTON 5'),
  QolipColorOption(name: 'Panton 6', value: 'PANTON 6'),
  QolipColorOption(name: 'Panton 7', value: 'PANTON 7'),
];

bool qolipIsPantonColor(String value) =>
    value.trim().toUpperCase().startsWith(qolipPantonColorValue);

Color qolipColorValue(String value) {
  final normalized = value.trim().replaceFirst('#', '');
  final parsed = int.tryParse(normalized, radix: 16);
  return Color(0xFF000000 | (parsed ?? 0x757575));
}

bool _isPantonOption(QolipColorOption option) =>
    qolipIsPantonColor(option.value);

class QolipColorPicker extends StatelessWidget {
  const QolipColorPicker({
    super.key,
    required this.selectedColor,
    required this.onChanged,
  });

  final String? selectedColor;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = selectedColor?.trim().toUpperCase();
    return Wrap(
      spacing: 4,
      runSpacing: 6,
      children: [
        for (final option in qolipDefaultColors)
          _QolipColorTile(
            option: option,
            selected: selected == option.value,
            isPanton: false,
            onTap: () => onChanged(option.value),
          ),
        for (final option in qolipPantonColors)
          _QolipColorTile(
            option: option,
            selected: selected == option.value,
            isPanton: _isPantonOption(option),
            onTap: () => onChanged(option.value),
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
    required this.onTap,
  });

  final QolipColorOption option;
  final bool selected;
  final bool isPanton;
  final VoidCallback onTap;

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
                    ? const Icon(
                        Icons.check_rounded,
                        size: 25,
                        color: Colors.white,
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
