import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/snackbar_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_alert_dialog.dart';
import '../../../core/widgets/app_list_item.dart';
import '../../../data/providers/families_provider.dart';
import '../providers/home_provider.dart';

class TodayCompletedSection extends ConsumerWidget {
  const TodayCompletedSection({super.key});

  Future<bool> _showRestoreConfirmDialog(BuildContext context) async {
    final result = await showAppConfirmDialog(
      context: context,
      title: 'アイテムをリストに戻す',
      message: '履歴から削除し、アイテムを未購入のリストに戻しますか?',
      confirmLabel: 'リストに戻す',
      cancelLabel: 'キャンセル',
      danger: true,
    );
    return result;
  }

  String _formatQuantityText(String quantityText, int? quantityUnit) {
    if (quantityUnit == null) {
      return quantityText;
    }
    const units = ['g', 'mg', 'ml', 'kg', 'L'];
    if (quantityUnit < 0 || quantityUnit >= units.length) {
      return quantityText;
    }
    return '$quantityText${units[quantityUnit]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appColors = AppColors.of(context);
    final appTypography = AppTypography.of(context);
    final isExpanded = ref.watch(showTodayCompletedProvider);
    final todayListAsync = ref.watch(todayCompletedListProvider);

    final itemCount = todayListAsync.valueOrNull?.length ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              ref.read(showTodayCompletedProvider.notifier).state = !isExpanded;
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Text(
                    '今日購入したリスト',
                    style: appTypography.std14B160.copyWith(
                      color: appColors.textMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: appColors.surfaceTertiary,
                      border: Border.all(color: appColors.borderLow, width: 2),
                    ),
                    child: Transform.translate(
                      offset: const Offset(0, -1),
                      child: Text(
                        '$itemCount',
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: false,
                          applyHeightToLastDescent: false,
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          color: appColors.textLow,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Transform.rotate(
                    angle: isExpanded ? 3.141592653589793 : 0,
                    child: SvgPicture.asset(
                      'assets/icons/chevron-down.svg',
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        appColors.surfaceMedium,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            todayListAsync.when(
              skipLoadingOnReload: true,
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 27),
                    child: Text(
                      '購入されたものはありません',
                      style: appTypography.std14R160.copyWith(
                        color: appColors.textLow,
                      ),
                    ),
                  );
                }
                return Column(
                  children: items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final combined = entry.value;
                    final isLast = index == items.length - 1;
                    final quantityText = combined.todo.quantityText;
                    final quantityUnit = combined.todo.quantityUnit;
                    final quantityCount = combined.todo.quantityCount;
                    final hasCount = quantityCount != null && quantityCount > 0;
                    final hasSizedQuantity =
                        quantityText != null && quantityUnit != null;
                    final budgetMax = combined.todo.budgetMaxAmount ?? 0;
                    final budgetMin = combined.todo.budgetMinAmount ?? 0;
                    final hasBudget = budgetMax > 0;
                    final budgetTypeLabel = combined.todo.budgetType == 1
                        ? '100g'
                        : '1つ';
                    final optionTexts = <String>[
                      if (quantityText != null &&
                          quantityText.isNotEmpty &&
                          quantityUnit == null)
                        quantityText,
                      if (hasSizedQuantity)
                        _formatQuantityText(quantityText, quantityUnit),
                      if (hasBudget && budgetMax >= 2050 && budgetMin > 0)
                        '${budgetMin}円以上/$budgetTypeLabel',
                      if (hasBudget && budgetMax < 2050 && budgetMin <= 0)
                        '${budgetMax}円以下/$budgetTypeLabel',
                      if (hasBudget &&
                          budgetMax < 2050 &&
                          budgetMin > 0 &&
                          budgetMin >= budgetMax)
                        '${budgetMin}円以上/$budgetTypeLabel',
                      if (hasBudget &&
                          budgetMax < 2050 &&
                          budgetMin > 0 &&
                          budgetMin < budgetMax)
                        '${budgetMin}〜${budgetMax}円/$budgetTypeLabel',
                    ];

                    return AppListItem(
                      padding: isLast
                          ? const EdgeInsets.only(top: 12, bottom: 30)
                          : const EdgeInsets.symmetric(vertical: 12),
                      showDivider: !isLast,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      title: Row(
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 170),
                            child: Text(
                              combined.masterItem.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: appColors.textLow,
                                height: 1.3,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: appColors.textLow,
                              ),
                            ),
                          ),
                          if (hasCount)
                            Text(
                              ' ×$quantityCount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: appColors.textLow,
                                height: 1.3,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: appColors.textLow,
                              ),
                            ),
                        ],
                      ),
                      subtitle: optionTexts.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  SvgPicture.asset(
                                    'assets/icons/bag.svg',
                                    width: 14,
                                    height: 14,
                                    colorFilter: const ColorFilter.mode(
                                      Color(0xFF7E8FA5),
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    optionTexts.join('  /  '),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF5A6E89),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (combined.masterItem.imageUrl != null &&
                              combined.masterItem.imageUrl!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                combined.masterItem.imageUrl!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          if (combined.masterItem.imageUrl != null &&
                              combined.masterItem.imageUrl!.isNotEmpty)
                            const SizedBox(width: 10),
                          InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () async {
                              final confirmed = await _showRestoreConfirmDialog(
                                context,
                              );
                              if (!confirmed || !context.mounted) return;
                              final message = await ref
                                  .read(homeViewModelProvider)
                                  .uncompleteTodo(combined.todo);
                              if (context.mounted) {
                                showTopSnackBar(
                                  context,
                                  message,
                                  familyId: ref.read(selectedFamilyIdProvider),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 0,
                                left: 6,
                                right: 6,
                                bottom: 6,
                              ),
                              child: SvgPicture.asset(
                                'assets/icons/undo.svg',
                                width: 20,
                                height: 20,
                                colorFilter: ColorFilter.mode(
                                  appColors.surfaceMedium,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
              error: (err, _) => Text('エラー: $err'),
            ),
        ],
      ),
    );
  }
}
