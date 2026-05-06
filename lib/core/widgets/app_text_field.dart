import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

enum AppTextFieldHeight { h56SingleLine, h56TwoLine, h56SingleLineEdit }

class AppTextField extends StatefulWidget {
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
    this.suffixIconConstraints,
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
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.textInputAction,
    this.onFieldSubmitted,
    this.hideUnfocusedBorder = false,
    this.fillColor,
    this.textColor,
    this.hintColor,
    this.textStyle,
    this.hideAllBorders = false,
    this.keepActiveBorder = false,
    this.useEnabledBorderWhenFocused = false,
    this.contentPadding,
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
  final BoxConstraints? suffixIconConstraints;
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
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool hideUnfocusedBorder;
  final Color? fillColor;
  final Color? textColor;
  final Color? hintColor;
  final TextStyle? textStyle;
  final bool hideAllBorders;
  final bool keepActiveBorder;
  final bool useEnabledBorderWhenFocused;
  final EdgeInsetsGeometry? contentPadding;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _isTextObscured;

  @override
  void initState() {
    super.initState();
    _isTextObscured = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _isTextObscured = widget.obscureText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final contentPadding =
        widget.contentPadding ??
        switch (widget.heightType) {
          AppTextFieldHeight.h56SingleLine => const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          AppTextFieldHeight.h56TwoLine => const EdgeInsets.fromLTRB(
            12,
            8,
            12,
            8,
          ),
          AppTextFieldHeight.h56SingleLineEdit => const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
        };
    final suffixIcon = widget.obscureText
        ? IconButton(
            onPressed: () {
              setState(() => _isTextObscured = !_isTextObscured);
            },
            icon: Icon(
              _isTextObscured ? Icons.visibility_off : Icons.visibility,
              color: colors.textLow,
            ),
          )
        : widget.suffixIcon;

    return TextFormField(
      controller: widget.controller,
      initialValue: widget.controller == null ? widget.initialValue : null,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      onTap: widget.onTap,
      validator: widget.validator,
      maxLength: widget.maxLength,
      maxLengthEnforcement: widget.maxLengthEnforcement,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      obscureText: _isTextObscured,
      autofocus: widget.autofocus,
      readOnly: widget.readOnly,
      showCursor: widget.showCursor,
      maxLines: widget.expands ? null : widget.maxLines,
      expands: widget.expands,
      textAlign: widget.textAlign,
      textAlignVertical: widget.textAlignVertical,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      style:
          widget.textStyle ??
          TextStyle(
            color:
                widget.textColor ??
                (widget.enabled ? colors.textHigh : colors.textDisabled),
            fontSize: 14,
          ),
      decoration: InputDecoration(
        isDense: true,
        labelText: widget.label,
        hintText: widget.hintText,
        helperText: widget.helperText,
        errorText: widget.errorText,
        counterText: widget.counterText,
        prefixIcon: widget.prefixIcon,
        prefixIconConstraints: widget.prefixIcon == null
            ? null
            : const BoxConstraints(minWidth: 0, minHeight: 48),
        suffixIcon: suffixIcon,
        suffixIconConstraints: widget.suffixIconConstraints,
        filled: true,
        fillColor:
            widget.fillColor ??
            (hasError
                ? colors.cautionLight
                : (widget.enabled
                      ? colors.surfaceHighOnInverse
                      : colors.surfaceTertiary)),
        contentPadding: contentPadding,
        labelStyle: TextStyle(color: colors.textMedium),
        hintStyle: (widget.textStyle ?? const TextStyle(fontSize: 14)).copyWith(
          color: widget.hintColor ?? colors.textLow,
        ),
        helperStyle: TextStyle(color: colors.textLow, fontSize: 11),
        errorStyle: TextStyle(color: colors.textAlert, fontSize: 11),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: widget.hideAllBorders
                ? Colors.transparent
                : widget.keepActiveBorder
                ? (hasError ? colors.borderAlert : colors.accentPrimary)
                : widget.hideUnfocusedBorder
                ? Colors.transparent
                : (hasError ? colors.borderAlert : colors.borderMedium),
            width: widget.keepActiveBorder && !widget.hideAllBorders
                ? 1.5
                : 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: widget.hideAllBorders
                ? Colors.transparent
                : widget.useEnabledBorderWhenFocused
                ? (hasError ? colors.borderAlert : colors.borderMedium)
                : (hasError ? colors.borderAlert : colors.accentPrimary),
            width: widget.hideAllBorders
                ? 0
                : widget.useEnabledBorderWhenFocused
                ? 1.0
                : 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: widget.hideAllBorders
                ? Colors.transparent
                : (widget.hideUnfocusedBorder
                      ? Colors.transparent
                      : colors.borderLow),
          ),
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
