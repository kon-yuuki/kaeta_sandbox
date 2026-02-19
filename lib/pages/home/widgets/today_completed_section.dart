import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/snackbar_helper.dart';
import '../../../core/widgets/app_list_item.dart';
import '../../../data/providers/families_provider.dart';
import '../providers/home_provider.dart';

class TodayCompletedSection extends ConsumerWidget {
  const TodayCompletedSection({super.key});

  String _formatQuantityText(String quantityText, int? quantityUnit) {
    if (quantityUnit == null) {
      return quantityText;
    }
    const units = ['g', 'mg', 'ml'];
    if (quantityUnit < 0 || quantityUnit >= units.length) {
      return quantityText;
    }
    return '$quantityText${units[quantityUnit]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(showTodayCompletedProvider);
    final todayListAsync = ref.watch(todayCompletedListProvider);

    final itemCount = todayListAsync.valueOrNull?.length ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              ref.read(showTodayCompletedProvider.notifier).state = !isExpanded;
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Row(
                children: [
                  const Text(
                    '今日買ったアイテム',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4E6078),
                    ),
                    child: Text(
                      '$itemCount',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
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
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'まだありません',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return Column(
                  children: items.map((combined) {
                    final quantityText = combined.todo.quantityText;
                    final quantityUnit = combined.todo.quantityUnit;
                    final quantityCount = combined.todo.quantityCount;
                    final hasCount = quantityCount != null && quantityCount > 0;
                    final hasSizedQuantity = quantityText != null && quantityUnit != null;
                    final budgetMax = combined.todo.budgetMaxAmount ?? 0;
                    final budgetMin = combined.todo.budgetMinAmount ?? 0;
                    final hasBudget = budgetMax > 0;
                    final budgetTypeLabel =
                        combined.todo.budgetType == 1 ? '100g' : '1つ';
                    final optionTexts = <String>[
                      if (quantityText != null &&
                          quantityText.isNotEmpty &&
                          quantityUnit == null)
                        quantityText,
                      if (hasSizedQuantity)
                        _formatQuantityText(quantityText, quantityUnit),
                      if (hasBudget)
                        '${budgetMin > 0 ? '$budgetMin〜' : ''}$budgetMax円/$budgetTypeLabel',
                    ];

                    return AppListItem(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      showDivider: true,
                      title: Row(
                        children: [
                          Expanded(
                            child: RichText(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 40 / 3,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF5A6E89),
                                  height: 1.3,
                                ),
                                children: [
                                  TextSpan(text: combined.masterItem.name),
                                  if (hasCount) TextSpan(text: ' ×$quantityCount'),
                                ],
                              ),
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
                        children: [
                          if (combined.masterItem.imageUrl != null &&
                              combined.masterItem.imageUrl!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                combined.masterItem.imageUrl!,
                                width: 24,
                                height: 24,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            SvgPicture.asset(
                              'assets/icons/no-image.svg',
                              width: 24,
                              height: 24,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFFB4BECC),
                                BlendMode.srcIn,
                              ),
                            ),
                          const SizedBox(width: 10),
                          InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () async {
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
                              padding: const EdgeInsets.all(6),
                              child: SvgPicture.asset(
                                'assets/icons/undo.svg',
                                width: 20,
                                height: 20,
                                colorFilter: const ColorFilter.mode(
                                  Color(0xFF5A6E89),
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
          const Divider(height: 1),
        ],
      ),
    );
  }
}
