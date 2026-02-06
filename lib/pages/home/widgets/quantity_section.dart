import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants.dart';

class QuantitySection extends StatelessWidget {
  final String selectedPreset;
  final String customValue;
  final int unit;
  final ValueChanged<String> onPresetChanged;
  final ValueChanged<String> onCustomValueChanged;
  final ValueChanged<int> onUnitChanged;

  const QuantitySection({
    super.key,
    required this.selectedPreset,
    required this.customValue,
    required this.unit,
    required this.onPresetChanged,
    required this.onCustomValueChanged,
    required this.onUnitChanged,
  });

  void _showQuantityPicker(BuildContext context) {
    int tempValue = int.tryParse(customValue) ?? 0;
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SizedBox(
          height: 280,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        FocusScope.of(parentContext).unfocus();
                      },
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () {
                        onCustomValueChanged(tempValue.toString());
                        Navigator.pop(context);
                        FocusScope.of(parentContext).unfocus();
                      },
                      child: const Text('決定'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 40,
                  scrollController: FixedExtentScrollController(
                    initialItem: tempValue,
                  ),
                  onSelectedItemChanged: (index) {
                    tempValue = index;
                  },
                  children: List.generate(
                    1001,
                    (i) => Center(child: Text('$i', style: const TextStyle(fontSize: 20))),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: 6,
          children: [
            ...quantityPresets.map((preset) => ChoiceChip(
              label: Text(preset, style: const TextStyle(fontSize: 12)),
              selected: selectedPreset == preset,
              visualDensity: VisualDensity.compact,
              onSelected: (_) {
                FocusScope.of(context).unfocus();
                onPresetChanged(preset);
              },
            )),
            ChoiceChip(
              label: const Text('数量入力', style: TextStyle(fontSize: 12)),
              selected: selectedPreset == 'カスタム',
              visualDensity: VisualDensity.compact,
              onSelected: (_) {
                FocusScope.of(context).unfocus();
                onPresetChanged('カスタム');
              },
            ),
          ],
        ),
        if (selectedPreset == 'カスタム') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showQuantityPicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      customValue.isEmpty ? '数量を選択' : customValue,
                      style: TextStyle(
                        fontSize: 16,
                        color: customValue.isEmpty ? Colors.grey : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: unit,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('g')),
                  DropdownMenuItem(value: 1, child: Text('mg')),
                  DropdownMenuItem(value: 2, child: Text('ml')),
                ],
                onChanged: (v) {
                  if (v != null) onUnitChanged(v);
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}
