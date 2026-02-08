import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppDropdownOption<T> {
  const AppDropdownOption({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}

class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<AppDropdownOption<T>> options;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surfaceHighOnInverse,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.borderMedium),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: options
              .map(
                (o) => DropdownMenuItem<T>(
                  value: o.value,
                  child: Text(o.label),
                ),
              )
              .toList(),
          onChanged: onChanged == null ? null : (v) => v == null ? null : onChanged!(v),
        ),
      ),
    );
  }
}
