import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_bottom_sheet_header.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_selection.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/constants.dart';

class QuantitySection extends StatefulWidget {
  final String selectedPreset;
  final String customValue;
  final int unit;
  final int? quantityCount;
  final ValueChanged<String> onPresetChanged;
  final ValueChanged<String> onCustomValueChanged;
  final ValueChanged<int> onUnitChanged;
  final ValueChanged<int?> onQuantityCountChanged;
  final Key? customValueFieldKey;
  final VoidCallback? onCustomValueTap;
  final Key? quantityCountFieldKey;
  final VoidCallback? onQuantityCountTap;

  const QuantitySection({
    super.key,
    required this.selectedPreset,
    required this.customValue,
    required this.unit,
    this.quantityCount,
    required this.onPresetChanged,
    required this.onCustomValueChanged,
    required this.onUnitChanged,
    required this.onQuantityCountChanged,
    this.customValueFieldKey,
    this.onCustomValueTap,
    this.quantityCountFieldKey,
    this.onQuantityCountTap,
  });

  @override
  State<QuantitySection> createState() => _QuantitySectionState();
}

class _QuantitySectionState extends State<QuantitySection> {
  late final TextEditingController _quantityCountController;
  late final FocusNode _quantityCountFocusNode;

  @override
  void initState() {
    super.initState();
    _quantityCountController = TextEditingController();
    _quantityCountFocusNode = FocusNode();
    _syncQuantityCountText();
    _quantityCountFocusNode.addListener(_handleQuantityCountFocusChanged);
  }

  @override
  void didUpdateWidget(covariant QuantitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quantityCount != widget.quantityCount &&
        !_quantityCountFocusNode.hasFocus) {
      _syncQuantityCountText();
    }
  }

  @override
  void dispose() {
    _quantityCountFocusNode.removeListener(_handleQuantityCountFocusChanged);
    _quantityCountFocusNode.dispose();
    _quantityCountController.dispose();
    super.dispose();
  }

  void _syncQuantityCountText() {
    _quantityCountController.text = widget.quantityCount?.toString() ?? '';
  }

  void _handleQuantityCountFocusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const quantityInputWidth = 68.0;
    final options = [...quantityPresets];
    final appColors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final optionLabelStyle = typography.jaOnl14Sb100.copyWith(
      height: 1.3,
      color: appColors.textMedium,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // サイズ見出し
        const AppBottomSheetSectionHeading(text: 'サイズ'),
        const SizedBox(height: 12),
        ...options.map((option) {
          final selected = widget.selectedPreset == option;
          final label = option == 'カスタム' ? '数量入力' : option;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  widget.onPresetChanged(option);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppRadioCircle(selected: selected),
                    const SizedBox(width: 10),
                    Text(label, style: optionLabelStyle),
                  ],
                ),
              ),
            ),
          );
        }),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            InkWell(
              onTap: () {
                FocusScope.of(context).unfocus();
                widget.onPresetChanged('カスタム');
              },
              child: AppRadioCircle(selected: widget.selectedPreset == 'カスタム'),
            ),
            const SizedBox(width: 10),
            SizedBox(
              key: widget.customValueFieldKey,
              width: quantityInputWidth,
              height: 40,
              child: AppTextField(
                initialValue: widget.customValue,
                fillColor: appColors.surfaceTertiary,
                hideAllBorders: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                hintText: '0',
                textAlign: TextAlign.center,
                textAlignVertical: TextAlignVertical.center,
                textInputAction: TextInputAction.done,
                onTap: () {
                  if (widget.selectedPreset != 'カスタム') {
                    widget.onPresetChanged('カスタム');
                  }
                  widget.onCustomValueTap?.call();
                },
                onChanged: (value) {
                  if (widget.selectedPreset != 'カスタム') {
                    widget.onPresetChanged('カスタム');
                  }
                  widget.onCustomValueChanged(value.trim());
                },
              ),
            ),
            const SizedBox(width: 12),
            AppDropdown<int>(
              value: widget.unit,
              width: quantityInputWidth,
              height: 40,
              backgroundColor: appColors.surfaceTertiary,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              centerContents: true,
              hideBorder: true,
              menuWidth: 214,
              menuElevation: 16,
              menuShadowColor: Colors.black.withValues(alpha: 0.42),
              menuDividerColor: const Color(0x80808080),
              menuDividerWidth: 0.5,
              trailingSpacing: 4,
              textStyle: typography.egOnl16M160.copyWith(
                color: appColors.textHigh,
              ),
              menuTextStyle: typography.egOnl16M160.copyWith(
                color: appColors.textHigh,
              ),
              trailingIcon: SvgPicture.asset(
                'assets/icons/up-down-arw.svg',
                width: 12,
                height: 12,
                colorFilter: ColorFilter.mode(
                  appColors.textMedium,
                  BlendMode.srcIn,
                ),
              ),
              options: const [
                AppDropdownOption(value: 1, label: 'mg'),
                AppDropdownOption(value: 0, label: 'g'),
                AppDropdownOption(value: 3, label: 'kg'),
                AppDropdownOption(value: 2, label: 'ml'),
                AppDropdownOption(value: 4, label: 'L'),
              ],
              onChanged: widget.onUnitChanged,
            ),
          ],
        ),

        const SizedBox(height: 32),

        // 個数見出し
        const AppBottomSheetSectionHeading(text: '個数'),
        const SizedBox(height: 12),
        // 個数入力（その場で直接入力）
        Row(
          children: [
            Expanded(
              child: SizedBox(
                key: widget.quantityCountFieldKey,
                height: 65,
                child: AppTextField(
                  controller: _quantityCountController,
                  focusNode: _quantityCountFocusNode,
                  fillColor: appColors.surfaceTertiary,
                  hideAllBorders: true,
                  contentPadding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  hintText: _quantityCountFocusNode.hasFocus ? '' : '0',
                  hintColor: appColors.textLow,
                  textStyle: typography.egOnl16M160.copyWith(
                    color: appColors.textHigh,
                  ),
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
                  textInputAction: TextInputAction.done,
                  onTap: widget.onQuantityCountTap,
                  onChanged: (value) {
                    final trimmed = value.trim();
                    final parsed = trimmed.isEmpty
                        ? null
                        : int.tryParse(trimmed);
                    widget.onQuantityCountChanged(parsed);
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
