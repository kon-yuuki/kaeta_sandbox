import 'package:flutter/material.dart';
import 'dart:math' as math;

class BudgetSection extends StatelessWidget {
  final int minAmount;
  final int maxAmount;
  final int type;
  final ValueChanged<({int min, int max})> onRangeChanged;
  final ValueChanged<int> onTypeChanged;

  const BudgetSection({
    super.key,
    required this.minAmount,
    required this.maxAmount,
    required this.type,
    required this.onRangeChanged,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeMin = math.min(minAmount, maxAmount);
    final safeMax = math.max(minAmount, maxAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 予算タイプ見出し
        const Text(
          '何の予算を設定しますか？',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        // 予算タイプ選択（ラジオボタン）
        RadioListTile<int>(
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          title: const Text('ひとつあたり'),
          value: 0,
          groupValue: type,
          onChanged: (value) {
            if (value != null) {
              FocusScope.of(context).unfocus();
              onTypeChanged(value);
            }
          },
        ),
        RadioListTile<int>(
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          title: const Text('100gあたり'),
          value: 1,
          groupValue: type,
          onChanged: (value) {
            if (value != null) {
              FocusScope.of(context).unfocus();
              onTypeChanged(value);
            }
          },
        ),

        const SizedBox(height: 16),

        // 金額見出し
        const Text(
          '金額を設定',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        // 金額表示
        Center(
          child: Text(
            '$safeMin円 〜 $safeMax円',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        // スライダー
        RangeSlider(
          values: RangeValues(safeMin.toDouble(), safeMax.toDouble()),
          min: 0,
          max: 3000,
          divisions: 60,
          labels: RangeLabels('$minAmount円', '$maxAmount円'),
          onChanged: (value) => onRangeChanged(
            (
              min: value.start.round(),
              max: value.end.round(),
            ),
          ),
        ),
      ],
    );
  }
}
