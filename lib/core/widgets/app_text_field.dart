import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

enum AppTextFieldHeight {
  h56SingleLine,
  h56TwoLine,
  h56SingleLineEdit,
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.counterText,
    this.onChanged,
    this.onTap,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.heightType = AppTextFieldHeight.h56SingleLine,
    this.maxLength,
    this.maxLengthEnforcement,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.autofocus = false,
    this.readOnly = false,
    this.showCursor,
    this.maxLines = 1,
    this.expands = false,
    this.textAlignVertical,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? counterText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final AppTextFieldHeight heightType;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool autofocus;
  final bool readOnly;
  final bool? showCursor;
  final int? maxLines;
  final bool expands;
  final TextAlignVertical? textAlignVertical;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasError = errorText != null && errorText!.isNotEmpty;
    final contentPadding = switch (heightType) {
      AppTextFieldHeight.h56SingleLine => const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      AppTextFieldHeight.h56TwoLine => const EdgeInsets.fromLTRB(12, 8, 12, 8),
      AppTextFieldHeight.h56SingleLineEdit => const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
    };

    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      focusNode: focusNode,
      enabled: enabled,
      onChanged: onChanged,
      onTap: onTap,
      validator: validator,
      maxLength: maxLength,
      maxLengthEnforcement: maxLengthEnforcement,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      autofocus: autofocus,
      readOnly: readOnly,
      showCursor: showCursor,
      maxLines: expands ? null : maxLines,
      expands: expands,
      textAlignVertical: textAlignVertical,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      style: TextStyle(
        color: enabled ? colors.textHigh : colors.textDisabled,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        counterText: counterText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: enabled ? colors.surfaceHighOnInverse : colors.surfaceTertiary,
        contentPadding: contentPadding,
        labelStyle: TextStyle(color: colors.textMedium),
        hintStyle: TextStyle(color: colors.textLow),
        helperStyle: TextStyle(color: colors.textLow, fontSize: 11),
        errorStyle: TextStyle(color: colors.textAlert, fontSize: 11),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: hasError ? colors.borderAlert : colors.borderMedium,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: hasError ? colors.borderAlert : colors.accentPrimary,
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.borderLow),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.borderAlert),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.borderAlert, width: 1.5),
        ),
      ),
    );
  }
}
