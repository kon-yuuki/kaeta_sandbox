import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_heading.dart';
import '../../../core/widgets/app_selection.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/constants.dart';

class QuantitySection extends StatelessWidget {
  final String selectedPreset;
  final String customValue;
  final int unit;
  final int? quantityCount;
  final ValueChanged<String> onPresetChanged;
  final ValueChanged<String> onCustomValueChanged;
  final ValueChanged<int> onUnitChanged;
  final ValueChanged<int?> onQuantityCountChanged;
  final Key? quantityCountFieldKey;
  final VoidCallback? onQuantityCountTap;

  const QuantitySection({
    super.key,
    required this.selectedPreset,
    required this.customValue,
    required this.unit,
    this.quantityCount,
    required this.onPresetChanged,
    required this.onCustomValueChanged,
    required this.onUnitChanged,
    required this.onQuantityCountChanged,
    this.quantityCountFieldKey,
    this.onQuantityCountTap,
  });

  double _calcQuantityButtonWidth(BuildContext context, String label) {
    final textStyle = Theme.of(context).textTheme.labelLarge;
    final painter = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();

    // テキスト幅 + 左右padding + 若干の余白
    final target = painter.width + 24 + 24 + 8;
    return target.clamp(72.0, 220.0);
  }

  @override
  Widget build(BuildContext context) {
    final options = [...quantityPresets];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // サイズ見出し
        const AppHeading('サイズ', type: AppHeadingType.tertiary),
        const SizedBox(height: 4),
        ...options.map((option) {
          final selected = selectedPreset == option;
          final label = option == 'カスタム' ? '数量入力' : option;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  onPresetChanged(option);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppRadioCircle(selected: selected),
                    const SizedBox(width: 14),
                    Text(label),
                  ],
                ),
              ),
            ),
          );
        }),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            InkWell(
              onTap: () {
                FocusScope.of(context).unfocus();
                onPresetChanged('カスタム');
              },
              child: AppRadioCircle(selected: selectedPreset == 'カスタム'),
            ),
            const SizedBox(width: 10),
            Builder(
              builder: (context) {
                final displayText = customValue.isEmpty ? '0' : customValue;
                final width = _calcQuantityButtonWidth(context, displayText);
                return SizedBox(
                  width: width,
                  child: AppTextField(
                    initialValue: customValue,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    hintText: '0',
                    textInputAction: TextInputAction.done,
                    onTap: () {
                      if (selectedPreset != 'カスタム') {
                        onPresetChanged('カスタム');
                      }
                    },
                    onChanged: (value) {
                      if (selectedPreset != 'カスタム') {
                        onPresetChanged('カスタム');
                      }
                      onCustomValueChanged(value.trim());
                    },
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            AppDropdown<int>(
              value: unit,
              options: const [
                AppDropdownOption(value: 0, label: 'g'),
                AppDropdownOption(value: 1, label: 'mg'),
                AppDropdownOption(value: 2, label: 'ml'),
              ],
              onChanged: onUnitChanged,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 個数見出し
        const AppHeading('個数', type: AppHeadingType.tertiary),
        const SizedBox(height: 8),
        // 個数入力（その場で直接入力）
        Row(
          children: [
            SizedBox(
              key: quantityCountFieldKey,
              width: 100,
              child: AppTextField(
                initialValue: quantityCount?.toString() ?? '',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                hintText: '0',
                textInputAction: TextInputAction.done,
                onTap: onQuantityCountTap,
                onChanged: (value) {
                  final trimmed = value.trim();
                  final parsed = trimmed.isEmpty ? null : int.tryParse(trimmed);
                  onQuantityCountChanged(parsed);
                },
              ),
            ),
            const SizedBox(width: 8),
            const Text('個'),
          ],
        ),
      ],
    );
  }
}
