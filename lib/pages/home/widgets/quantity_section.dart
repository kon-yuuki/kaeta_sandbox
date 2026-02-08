import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/app_button.dart';
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

  Future<void> _showCustomQuantityInputModal(BuildContext context) async {
    String tempValue = customValue;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (modalContext) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '数量入力',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  initialValue: customValue,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  hintText: '数量を入力',
                  onChanged: (value) => tempValue = value,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      variant: AppButtonVariant.text,
                      onPressed: () => Navigator.pop(modalContext),
                      child: const Text('キャンセル'),
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      onPressed: () => Navigator.pop(
                        modalContext,
                        tempValue.trim(),
                      ),
                      child: const Text('確定'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null) {
      onCustomValueChanged(result);
    }
  }

  Future<void> _showQuantityCountInputModal(BuildContext context) async {
    String tempValue = quantityCount?.toString() ?? '';
    final result = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (modalContext) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '個数入力',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  initialValue: tempValue,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  hintText: '個数を入力',
                  onChanged: (value) => tempValue = value,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      variant: AppButtonVariant.text,
                      onPressed: () => Navigator.pop(modalContext),
                      child: const Text('キャンセル'),
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      onPressed: () {
                        final trimmed = tempValue.trim();
                        final parsed = trimmed.isEmpty ? null : int.tryParse(trimmed);
                        Navigator.pop(modalContext, parsed);
                      },
                      child: const Text('確定'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null || tempValue.trim().isEmpty) {
      onQuantityCountChanged(result);
    }
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
          return InkWell(
            onTap: () {
              FocusScope.of(context).unfocus();
              onPresetChanged(option);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  AppRadioCircle(selected: selected),
                  const SizedBox(width: 10),
                  Text(label),
                ],
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
                _showCustomQuantityInputModal(context);
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
                  child: AppButton(
                    variant: AppButtonVariant.outlined,
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      if (selectedPreset != 'カスタム') {
                        onPresetChanged('カスタム');
                      }
                      _showCustomQuantityInputModal(context);
                    },
                    child: Text(
                      displayText,
                      style: TextStyle(
                        color: customValue.isEmpty ? Colors.grey[600] : Colors.black,
                      ),
                    ),
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
        // 個数入力（ダミーフィールド + モーダル確定）
        Row(
          children: [
            SizedBox(
              width: 100,
              child: AppButton(
                variant: AppButtonVariant.outlined,
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  _showQuantityCountInputModal(context);
                },
                child: Text(
                  quantityCount?.toString() ?? '0',
                  style: TextStyle(
                    color: quantityCount == null ? Colors.grey[600] : Colors.black,
                  ),
                ),
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
