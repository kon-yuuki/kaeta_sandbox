import 'package:flutter/cupertino.dart';
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
    this.backgroundColor,
    this.hideBorder = false,
  });

  final T value;
  final List<AppDropdownOption<T>> options;
  final ValueChanged<T>? onChanged;
  final Color? backgroundColor;
  final bool hideBorder;

  Future<void> _showInlineMenu(BuildContext context) async {
    final colors = AppColors.of(context);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final box = context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, box.size.width, box.size.height);

    final selected = await showMenu<T>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      color: colors.surfaceHighOnInverse,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: options
          .asMap()
          .entries
          .map(
            (entry) => PopupMenuItem<T>(
              value: entry.value.value,
              padding: EdgeInsets.zero,
              height: 46,
              child: Container(
                height: 46,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: entry.key == 0
                      ? null
                      : Border(top: BorderSide(color: colors.borderLow)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: entry.value.value == value
                          ? const Icon(Icons.check, size: 18)
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 8),
                    Text(entry.value.label),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
    if (selected != null && onChanged != null) {
      onChanged!(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final selectedLabel = options
        .firstWhere(
          (o) => o.value == value,
          orElse: () => options.first,
        )
        .label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surfaceHighOnInverse,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hideBorder ? Colors.transparent : colors.borderMedium,
        ),
      ),
      child: InkWell(
        onTap: onChanged == null ? null : () => _showInlineMenu(context),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedLabel,
              style: TextStyle(color: colors.textHigh, fontSize: 16),
            ),
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_up_chevron_down,
              size: 16,
              color: colors.textMedium,
            ),
          ],
        ),
      ),
    );
  }
}
