import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppStepBar extends StatelessWidget {
  const AppStepBar({
    super.key,
    required this.steps,
    required this.currentIndex,
    this.expanded = true,
  });

  final List<String> steps;
  final int currentIndex;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final safeCurrent = currentIndex.clamp(0, steps.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (expanded)
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: Text(
                    steps[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: i == safeCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: i <= safeCurrent ? colors.textAccentPrimary : colors.textLow,
                    ),
                  ),
                ),
              ],
            ],
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= safeCurrent ? colors.accentPrimary : colors.borderLow,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              if (i != steps.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}
