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

Color qolipColorValue(String value) {
  final normalized = value.trim().replaceFirst('#', '');
  final parsed = int.tryParse(normalized, radix: 16);
  return Color(0xFF000000 | (parsed ?? 0x757575));
}

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
          Semantics(
            button: true,
            label: option.name,
            selected: selected == option.value,
            child: InkWell(
              onTap: () => onChanged(option.value),
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
                        color: qolipColorValue(option.value),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected == option.value
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                          width: selected == option.value ? 3 : 1,
                        ),
                      ),
                      child: selected == option.value
                          ? Icon(
                              Icons.check_rounded,
                              size: 25,
                              color: option.value == '#FDD835'
                                  ? Colors.black
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
          ),
      ],
    );
  }
}
