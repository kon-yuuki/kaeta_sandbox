import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/widgets/app_heading.dart';
import '../../../core/theme/app_colors.dart';

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
    final appColors = AppColors.of(context);
    final safeMin = math.min(minAmount, maxAmount);
    final safeMax = math.max(minAmount, maxAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 予算タイプ見出し
        const AppHeading('何の予算を設定しますか？', type: AppHeadingType.tertiary),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  onTypeChanged(0);
                },
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: type == 0
                        ? appColors.accentPrimaryLight
                        : appColors.surfaceTertiary,
                    border: type == 0
                        ? Border.all(color: appColors.borderAccentPrimary, width: 1.2)
                        : Border.all(color: Colors.transparent),
                  ),
                  child: Text(
                    'ひとつあたり',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: type == 0
                          ? appColors.textAccentPrimary
                          : appColors.textMedium,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  onTypeChanged(1);
                },
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: type == 1
                        ? appColors.accentPrimaryLight
                        : appColors.surfaceTertiary,
                    border: type == 1
                        ? Border.all(color: appColors.borderAccentPrimary, width: 1.2)
                        : Border.all(color: Colors.transparent),
                  ),
                  child: Text(
                    '100gあたり',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: type == 1
                          ? appColors.textAccentPrimary
                          : appColors.textMedium,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

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
