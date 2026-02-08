import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_selection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/snackbar_helper.dart';
import '../../../data/repositories/notifications_repository.dart';
import '../../../data/providers/families_provider.dart';
import '../providers/home_provider.dart';
import '../view/todo_edit_page.dart';
import '../view/category_edit_page.dart';

class TodoItemList extends ConsumerWidget {
  const TodoItemList({
    super.key,
    this.blockInteractions = false,
    this.onBlockedTap,
  });

  final bool blockInteractions;
  final VoidCallback? onBlockedTap;

  static const List<String> _quantityUnits = ['g', 'mg', 'ml'];

  String? _buildQuantityLabel(String? text, int? unit) {
    if (text == null || text.isEmpty) return null;
    if (unit == null || unit < 0 || unit >= _quantityUnits.length) return text;
    return '$text${_quantityUnits[unit]}';
  }

  String? _buildBudgetLabel(int? min, int? max, int? type) {
    if (max == null || max <= 0) return null;
    final base = '¥$max/${type == 1 ? '100g' : '1つ'}';
    if (min != null && min > 0) {
      return '¥$min〜${base.substring(1)}';
    }
    return base;
  }

  String _priorityLabel(int priority) {
    if (priority == 1) return '必ず条件を守る';
    return '目安でOK';
  }

  Color _priorityBackground(AppColors appColors, int priority) {
    if (priority == 1) return appColors.accentPrimaryLight;
    return appColors.surfaceTertiary;
  }

  Color _priorityTextColor(AppColors appColors, int priority) {
    if (priority == 1) return appColors.textAccentPrimary;
    return appColors.textMedium;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appColors = AppColors.of(context);
    final todoListAsync = ref.watch(todoListProvider);
    final groupTodo = ref.watch(groupedTodoListProvider);

    return todoListAsync.when(
      skipLoadingOnReload: true,
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('タスクが登録されていません'),
            ),
          );
        }

        return Column(
          children: groupTodo.entries.map((entry) {
            final categoryName = entry.key;
            final todoItems = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 4.0,   
                horizontal: 16.0,
              ),
              child: Card(
                color: appColors.surfaceSecondary,
                elevation: 0,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                categoryName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (categoryName != '指定なし')
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                tooltip: 'カテゴリを編集',
                                onPressed: () {
                                  if (blockInteractions) {
                                    onBlockedTap?.call();
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CategoryEditPage(
                                        initialCategoryName: categoryName,
                                        initialCategoryId:
                                            todoItems.isNotEmpty
                                                ? todoItems.first.todo.categoryId
                                                : null,
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      ...[1, 0].where((p) => todoItems.any((e) => e.todo.priority == p)).map((priority) {
                        final groupedItems = todoItems
                            .where((e) => e.todo.priority == priority)
                            .toList();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Column(
                                    children: List.generate(groupedItems.length, (index) {
                                      final combined = groupedItems[index];
                                      final quantityLabel = _buildQuantityLabel(
                                        combined.todo.quantityText,
                                        combined.todo.quantityUnit,
                                      );
                                      final budgetLabel = _buildBudgetLabel(
                                        combined.todo.budgetMinAmount,
                                        combined.todo.budgetMaxAmount,
                                        combined.todo.budgetType,
                                      );
                                      final metaLines = <String>[
                                        if (quantityLabel != null && quantityLabel.isNotEmpty)
                                          quantityLabel,
                                        if (budgetLabel != null && budgetLabel.isNotEmpty)
                                          budgetLabel,
                                      ];

                                      return DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border(
                                            bottom: index == groupedItems.length - 1
                                                ? BorderSide.none
                                                : BorderSide(
                                                    color: appColors.surfacePrimary,
                                                    width: 1,
                                                  ),
                                          ),
                                        ),
                                        child: ListTile(
                                          contentPadding: EdgeInsets.fromLTRB(
                                            16,
                                            index == 0 ? 26 : 12,
                                            16,
                                            8,
                                          ),
                                          title: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            combined.masterItem.name,
                                                            style: const TextStyle(fontSize: 16),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        if (combined.todo.quantityCount != null &&
                                                            combined.todo.quantityCount! > 0)
                                                          Text(
                                                            ' x${combined.todo.quantityCount}',
                                                            style: const TextStyle(
                                                              fontSize: 13,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.black54,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    if (metaLines.isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        metaLines.join('\n'),
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black54,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              if (combined.masterItem.imageUrl != null &&
                                                  combined.masterItem.imageUrl!.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(
                                                    left: 10,
                                                    top: 2,
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Image.network(
                                                      combined.masterItem.imageUrl!,
                                                      width: 44,
                                                      height: 44,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          trailing: AppCheckCircle(
                                            selected: combined.todo.isCompleted,
                                            onTap: () async {
                                              if (blockInteractions) {
                                                onBlockedTap?.call();
                                                return;
                                              }
                                              final message = await ref
                                                  .read(homeViewModelProvider)
                                                  .completeTodo(combined.todo);
                                              if (context.mounted) {
                                                showTopSnackBar(
                                                  context,
                                                  message,
                                                  notificationType: NotificationType.shoppingComplete,
                                                  familyId: ref.read(selectedFamilyIdProvider),
                                                );
                                              }
                                            },
                                          ),
                                          onTap: () {
                                            if (blockInteractions) {
                                              onBlockedTap?.call();
                                              return;
                                            }
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => TodoEditPage(
                                                  item: combined.todo,
                                                  imageUrl: combined.masterItem.imageUrl,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                top: 0,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 160),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _priorityBackground(appColors, priority),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(10),
                                        bottomRight: Radius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      _priorityLabel(priority),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _priorityTextColor(appColors, priority),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('読み込みエラー: $err')),
    );
  }
}
