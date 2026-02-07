import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/snackbar_helper.dart';
import '../providers/home_provider.dart';

class TodayCompletedSection extends ConsumerWidget {
  const TodayCompletedSection({super.key});

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
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '今日買ったアイテム ($itemCount)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              combined.masterItem.name,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          if (combined.todo.quantityText != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Chip(
                                label: Text(
                                  combined.todo.quantityUnit != null
                                      ? '${combined.todo.quantityText}${['g', 'mg', 'ml'][combined.todo.quantityUnit!]}'
                                      : combined.todo.quantityText!,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white),
                                ),
                                backgroundColor: Colors.blue,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          if ((combined.todo.budgetMaxAmount ?? 0) > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Chip(
                                label: Text(
                                  '${((combined.todo.budgetMinAmount ?? 0) > 0) ? '${combined.todo.budgetMinAmount}〜' : ''}${combined.todo.budgetMaxAmount}円/${combined.todo.budgetType == 1 ? '100g' : '1つ'}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white),
                                ),
                                backgroundColor: Colors.green,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          if (combined.masterItem.imageUrl != null &&
                              combined.masterItem.imageUrl!.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  combined.masterItem.imageUrl!,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final message = await ref
                              .read(homeViewModelProvider)
                              .uncompleteTodo(combined.todo);
                          if (context.mounted) {
                            showTopSnackBar(context, message);
                          }
                        },
                        child: const Text(
                          '戻す',
                          style: TextStyle(fontSize: 12),
                        ),
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
