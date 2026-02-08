import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/widgets/app_heading.dart';
import '../../../core/widgets/app_selection.dart';

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
        const AppHeading('何の予算を設定しますか？', type: AppHeadingType.tertiary),
        const SizedBox(height: 4),
        ...const [(0, 'ひとつあたり'), (1, '100gあたり')].map((entry) {
          final value = entry.$1;
          final label = entry.$2;
          return InkWell(
            onTap: () {
              FocusScope.of(context).unfocus();
              onTypeChanged(value);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  AppRadioCircle(selected: type == value),
                  const SizedBox(width: 10),
                  Text(label),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 16),

        // 金額見出し
        const AppHeading('金額を設定', type: AppHeadingType.tertiary),
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
