import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                TextFormField(
                  initialValue: customValue,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    hintText: '数量を入力',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => tempValue = value,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(modalContext),
                      child: const Text('キャンセル'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
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

  @override
  Widget build(BuildContext context) {
    final options = [...quantityPresets];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...options.map(
          (option) => RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            title: Text(option == 'カスタム' ? '数量入力' : option),
            value: option,
            groupValue: selectedPreset,
            onChanged: (value) {
              if (value == null) return;
              FocusScope.of(context).unfocus();
              onPresetChanged(value);
            },
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              child: Radio<String>(
                value: 'カスタム',
                groupValue: selectedPreset,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (value) {
                  if (value == null) return;
                  FocusScope.of(context).unfocus();
                  onPresetChanged(value);
                  _showCustomQuantityInputModal(context);
                },
              ),
            ),
            Builder(
              builder: (context) {
                final displayText = customValue.isEmpty ? '0' : customValue;
                final width = _calcQuantityButtonWidth(context, displayText);
                return SizedBox(
                  width: width,
                  child: OutlinedButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      if (selectedPreset != 'カスタム') {
                        onPresetChanged('カスタム');
                      }
                      _showCustomQuantityInputModal(context);
                    },
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
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
    );
  }
}
