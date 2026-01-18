import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/home_provider.dart';
import './todo_edit_sheet.dart';

class TodoItemList extends ConsumerWidget {
  const TodoItemList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todoListAsync = ref.watch(todoListProvider);

    return todoListAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('タスクが登録されていません'),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final combined = items[index];
            final todo = combined.todo;
            final master = combined.masterItem;

            return ListTile(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => TodoEditSheet(item: todo),
                );
              },
              leading: Checkbox(
                value: todo.isCompleted,
                onChanged: (_) =>
                    ref.read(homeViewModelProvider).completeTodo(todo),
              ),
              title: Row(
                children: [
                  if (todo.priority == 1)
                    const Icon(Icons.whatshot, color: Colors.orange, size: 20),
                  Expanded(child: Text(master.name)),
                  ActionChip(
                    label: Text(master.category),
                    onPressed: () {
                      print('カテゴリをクリック');
                    },
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () =>
                    ref.read(homeViewModelProvider).deleteTodo(todo),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('読み込みエラー: $err')),
    );
  }
}
