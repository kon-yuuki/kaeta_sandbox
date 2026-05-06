import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_bottom_sheet_header.dart';

class BudgetSection extends StatelessWidget {
  static const int _maxBudgetAmount = 2000;
  static const int _sliderUpperNoneValue = 2050;
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
    final typography = AppTypography.of(context);
    final isInactive = maxAmount <= 0;
    final safeMin = isInactive ? 0 : math.min(minAmount, maxAmount);
    final safeMax = isInactive
        ? _sliderUpperNoneValue
        : math.min(_sliderUpperNoneValue, math.max(minAmount, maxAmount));
    final isUpperNone = safeMax >= _sliderUpperNoneValue;
    final budgetDisplayText = isUpperNone
        ? (safeMin <= 0 ? '上限なし' : '$safeMin円以上')
        : (safeMin <= 0
              ? '$safeMax円以下'
              : safeMin >= safeMax
              ? '$safeMin円以上'
              : '$safeMin円 〜 $safeMax円');
    final rangeTextColor = isInactive
        ? appColors.textDisabled
        : appColors.textHigh;
    final activeTrackColor = isInactive
        ? appColors.surfaceSecondary
        : appColors.accentPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 予算タイプ見出し
        const AppBottomSheetSectionHeading(text: '何の予算を設定しますか？'),
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
                  height: 43,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: type == 0
                        ? appColors.accentPrimaryLight
                        : appColors.surfaceTertiary,
                    border: type == 0
                        ? Border.all(
                            color: appColors.borderAccentPrimary,
                            width: 1.2,
                          )
                        : Border.all(color: Colors.transparent),
                  ),
                  child: Text(
                    'ひとつあたり',
                    style: AppTypography.of(context).std12B160.copyWith(
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
                  height: 43,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: type == 1
                        ? appColors.accentPrimaryLight
                        : appColors.surfaceTertiary,
                    border: type == 1
                        ? Border.all(
                            color: appColors.borderAccentPrimary,
                            width: 1.2,
                          )
                        : Border.all(color: Colors.transparent),
                  ),
                  child: Text(
                    '100gあたり',
                    style: AppTypography.of(context).std12B160.copyWith(
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

        const SizedBox(height: 32),

        // 金額見出し
        const AppBottomSheetSectionHeading(text: '金額を設定'),
        const SizedBox(height: 24),
        // 金額表示
        Center(
          child: Text(
            budgetDisplayText,
            style: typography.egOnl26R120.copyWith(color: rangeTextColor),
          ),
        ),
        const SizedBox(height: 16),
        // スライダー
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: activeTrackColor,
            inactiveTrackColor: appColors.surfaceSecondary,
            thumbColor: Colors.white,
            overlappingShapeStrokeColor: Colors.white,
            activeTickMarkColor: Colors.transparent,
            inactiveTickMarkColor: Colors.transparent,
            tickMarkShape: SliderTickMarkShape.noTickMark,
            rangeThumbShape: const RoundRangeSliderThumbShape(
              enabledThumbRadius: 16,
              elevation: 1.5,
              pressedElevation: 2.5,
            ),
            overlayColor: appColors.accentPrimary.withValues(alpha: 0.12),
          ),
          child: RangeSlider(
            values: RangeValues(safeMin.toDouble(), safeMax.toDouble()),
            min: 0,
            max: _sliderUpperNoneValue.toDouble(),
            divisions: 41,
            labels: RangeLabels(
              '$safeMin円',
              isUpperNone ? '上限なし' : '$safeMax円',
            ),
            onChanged: (value) => onRangeChanged((
              min: value.start.round(),
              max: value.end.round(),
            )),
          ),
        ),
      ],
    );
  }
}
