import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_alert_dialog.dart';
import '../../../core/widgets/app_bottom_sheet_header.dart';
import '../../../core/widgets/app_text_field.dart';

Future<String?> showCategoryNameEditorSheet({
  required BuildContext context,
  required String title,
  required String initialName,
  required String hintText,
  int maxLength = 10,
}) async {
  final controller = TextEditingController(text: initialName);
  final focusNode = FocusNode();

  Future<bool> askDiscardConfirmation(BuildContext dialogContext) async {
    return showDiscardChangesConfirmDialog(context: dialogContext);
  }

  var shouldReopen = true;
  String? savedValue;

  while (context.mounted && shouldReopen) {
    shouldReopen = false;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (focusNode.canRequestFocus) {
            focusNode.requestFocus();
          }
        });
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final appColors = AppColors.of(modalContext);
            final text = controller.text;
            final trimmed = text.trim();
            final hasText = text.isNotEmpty;
            final canSave =
                trimmed.isNotEmpty &&
                text.length <= maxLength &&
                trimmed != initialName.trim();

            Future<void> requestCloseWithConfirm() async {
              if (controller.text.trim() == initialName.trim()) {
                if (modalContext.mounted) {
                  Navigator.of(modalContext).pop('discard');
                }
                return;
              }
              final shouldDiscard = await askDiscardConfirmation(modalContext);
              if (shouldDiscard && modalContext.mounted) {
                Navigator.of(modalContext).pop('discard');
              }
            }

            return Container(
              decoration: BoxDecoration(
                color: appColors.surfaceHighOnInverse,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBottomSheetHeader(
                    title: title,
                    onBack: requestCloseWithConfirm,
                    trailing: AppBottomSheetSaveButton(
                      enabled: canSave,
                      onPressed: () => Navigator.of(modalContext).pop(trimmed),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      24,
                      16,
                      24 + MediaQuery.of(modalContext).viewInsets.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'カテゴリ名',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        AppTextField(
                          controller: controller,
                          focusNode: focusNode,
                          hintText: hintText,
                          maxLength: maxLength,
                          maxLengthEnforcement: MaxLengthEnforcement.none,
                          counterText: '${controller.text.length}/$maxLength文字',
                          suffixIcon: TextButton(
                            onPressed: hasText
                                ? () {
                                    controller.clear();
                                    setModalState(() {});
                                    focusNode.requestFocus();
                                  }
                                : null,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: SizedBox(
                              width: 36,
                              height: 24,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  width: 19,
                                  height: 19,
                                  decoration: BoxDecoration(
                                    color: appColors.surfaceDisabled,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: SvgPicture.asset(
                                      'assets/icons/cross.svg',
                                      width: 14,
                                      height: 14,
                                      colorFilter: const ColorFilter.mode(
                                        Colors.white,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 24,
                          ),
                          onChanged: (_) => setModalState(() {}),
                          useEnabledBorderWhenFocused: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == 'discard') {
      break;
    }
    if (result != null) {
      savedValue = result;
      break;
    }

    if (controller.text.trim() == initialName.trim()) {
      break;
    }

    if (!context.mounted) break;
    final shouldDiscard = await askDiscardConfirmation(context);
    if (!context.mounted) break;
    if (!shouldDiscard) {
      shouldReopen = true;
    }
  }

  Future<void>.delayed(const Duration(milliseconds: 320), () {
    focusNode.dispose();
    controller.dispose();
  });

  return savedValue;
}
