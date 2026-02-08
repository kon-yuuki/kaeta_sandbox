import 'package:flutter/material.dart';
import 'app_selection.dart';

class AppSegmentOption<T> {
  const AppSegmentOption({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}

class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  });

  final List<AppSegmentOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (option) => AppChoicePill(
              label: option.label,
              selected: option.value == selectedValue,
              onTap: () => onChanged(option.value),
            ),
          )
          .toList(),
    );
  }
}
