import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';

class AppDropdownOption<T> {
  const AppDropdownOption({required this.value, required this.label});

  final T value;
  final String label;
}

Future<T?> showAppDropdownMenu<T>({
  required BuildContext triggerContext,
  required List<AppDropdownOption<T>> options,
  required T value,
  double? menuWidth,
  double? menuElevation,
  Color? menuShadowColor,
  TextStyle? textStyle,
  TextStyle? menuTextStyle,
  Color? menuDividerColor,
  double? menuDividerWidth,
}) async {
  final colors = AppColors.of(triggerContext);
  final overlay =
      Overlay.of(triggerContext).context.findRenderObject() as RenderBox;
  final box = triggerContext.findRenderObject() as RenderBox;
  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  final rect = Rect.fromLTWH(
    topLeft.dx,
    topLeft.dy,
    box.size.width,
    box.size.height,
  );

  return showMenu<T>(
    context: triggerContext,
    position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
    color: colors.surfaceHighOnInverse,
    elevation: menuElevation ?? 8,
    shadowColor: menuShadowColor,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    constraints:
        menuWidth == null ? null : BoxConstraints.tightFor(width: menuWidth),
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
                    : Border(
                        top: BorderSide(
                          color: menuDividerColor ?? colors.borderLow,
                          width: menuDividerWidth ?? 1,
                        ),
                      ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: entry.value.value == value
                        ? SvgPicture.asset(
                            'assets/icons/check.svg',
                            width: 16,
                            height: 16,
                            colorFilter: const ColorFilter.mode(
                              Color(0xFF000000),
                              BlendMode.srcIn,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.value.label,
                    style:
                        menuTextStyle ??
                        textStyle ??
                        TextStyle(color: colors.textHigh, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList(),
  );
}

class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.backgroundColor,
    this.hideBorder = false,
    this.width,
    this.height,
    this.centerContents = false,
    this.menuWidth,
    this.menuElevation,
    this.menuShadowColor,
    this.textStyle,
    this.menuTextStyle,
    this.menuDividerColor,
    this.menuDividerWidth,
    this.trailingIcon,
    this.trailingSpacing = 4,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  });

  final T value;
  final List<AppDropdownOption<T>> options;
  final ValueChanged<T>? onChanged;
  final Color? backgroundColor;
  final bool hideBorder;
  final double? width;
  final double? height;
  final bool centerContents;
  final double? menuWidth;
  final double? menuElevation;
  final Color? menuShadowColor;
  final TextStyle? textStyle;
  final TextStyle? menuTextStyle;
  final Color? menuDividerColor;
  final double? menuDividerWidth;
  final Widget? trailingIcon;
  final double trailingSpacing;
  final EdgeInsetsGeometry padding;

  Future<void> _showInlineMenu(BuildContext context) async {
    final selected = await showAppDropdownMenu<T>(
      triggerContext: context,
      options: options,
      value: value,
      menuWidth: menuWidth,
      menuElevation: menuElevation,
      menuShadowColor: menuShadowColor,
      textStyle: textStyle,
      menuTextStyle: menuTextStyle,
      menuDividerColor: menuDividerColor,
      menuDividerWidth: menuDividerWidth,
    );
    if (selected != null && onChanged != null) {
      onChanged!(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final selectedLabel = options
        .firstWhere((o) => o.value == value, orElse: () => options.first)
        .label;

    return SizedBox(
      width: width,
      height: height,
      child: Container(
        padding: padding,
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
          child: centerContents
              ? Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedLabel,
                        textAlign: TextAlign.center,
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: false,
                          applyHeightToLastDescent: false,
                        ),
                        style:
                            textStyle ??
                            TextStyle(color: colors.textHigh, fontSize: 16),
                      ),
                      SizedBox(width: trailingSpacing),
                      trailingIcon ??
                          Icon(
                            CupertinoIcons.chevron_up_chevron_down,
                            size: 16,
                            color: colors.textMedium,
                          ),
                    ],
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          selectedLabel,
                          textAlign: TextAlign.start,
                          textHeightBehavior: const TextHeightBehavior(
                            applyHeightToFirstAscent: false,
                            applyHeightToLastDescent: false,
                          ),
                          style:
                              textStyle ??
                              TextStyle(color: colors.textHigh, fontSize: 16),
                        ),
                      ),
                    ),
                    SizedBox(width: trailingSpacing),
                    trailingIcon ??
                        Icon(
                          CupertinoIcons.chevron_up_chevron_down,
                          size: 16,
                          color: colors.textMedium,
                        ),
                  ],
                ),
        ),
      ),
    );
  }
}
