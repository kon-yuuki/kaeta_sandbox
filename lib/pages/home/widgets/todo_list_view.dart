import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/snackbar_helper.dart';
import '../providers/home_provider.dart';
import '../view/todo_edit_page.dart';

class TodoItemList extends ConsumerWidget {
  const TodoItemList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          categoryName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      for (final combined in todoItems)
  ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16), // 端の余白を少し調整
    title: Row(
      children: [
        // 1. 名前（左端）
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  combined.masterItem.name,
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (combined.todo.quantityCount != null &&
                  combined.todo.quantityCount! > 0) ...[
                const SizedBox(width: 6),
                Text(
                  'x${combined.todo.quantityCount}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ),

        // 2. 欲しい量チップ
        if (combined.todo.quantityText != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Chip(
              label: Text(
                combined.todo.quantityUnit != null
                    ? '${combined.todo.quantityText}${['g', 'mg', 'ml'][combined.todo.quantityUnit!]}'
                    : combined.todo.quantityText!,
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
              backgroundColor: Colors.blue,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),

        // 3. 予算チップ
        if ((combined.todo.budgetMaxAmount ?? 0) > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Chip(
              label: Text(
                '${((combined.todo.budgetMinAmount ?? 0) > 0) ? '${combined.todo.budgetMinAmount}〜' : ''}${combined.todo.budgetMaxAmount}円/${combined.todo.budgetType == 1 ? '100g' : '1つ'}',
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
              backgroundColor: Colors.green,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),

        // 3. 画像（中央：名前のすぐ右）
        if (combined.masterItem.imageUrl != null && combined.masterItem.imageUrl!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
    
    // 3. チェックボックス（右端固定）
    trailing: Checkbox(
      value: combined.todo.isCompleted,
      onChanged: (_) async {
        final message = await ref.read(homeViewModelProvider).completeTodo(combined.todo);
        if (context.mounted) {
          showTopSnackBar(context, message);
        }
      },
    ),
    onTap: () {
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
