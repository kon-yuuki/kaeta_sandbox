import 'package:flutter/material.dart';
import '../../../core/constants.dart';

class BudgetSection extends StatelessWidget {
  final int amount;
  final int type;
  final ValueChanged<int> onAmountChanged;
  final ValueChanged<int> onTypeChanged;

  const BudgetSection({
    super.key,
    required this.amount,
    required this.type,
    required this.onAmountChanged,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SegmentedButton<int>(
          segments: budgetTypeSegments,
          selected: {type},
          onSelectionChanged: (newSelection) {
            FocusScope.of(context).unfocus();
            onTypeChanged(newSelection.first);
          },
        ),
        const SizedBox(height: 8),
        Text(
          '$amount円',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Slider(
          value: amount.toDouble(),
          min: 0,
          max: 3000,
          divisions: 60,
          label: '$amount円',
          onChanged: (value) => onAmountChanged(value.round()),
        ),
      ],
    );
  }
}
