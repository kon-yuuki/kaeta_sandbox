import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/todo_provider.dart';
import '../../../database/database.dart';

class TodoPage extends ConsumerWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(todoRepositoryProvider);
    final controller = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('メモ')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: "メモを追加"),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TodoItem>>(
              stream: repository.watchAllItems(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!;
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.name),
                      // 1. 右側に配置する部品（Trailing）
                      trailing: IconButton(
                        icon: const Icon(Icons.delete), // 2. 正しいアイコンの書き方
                        onPressed: () {
                          // 3. 先ほどRepositoryに作った削除命令を呼び出す
                          repository.deleteItem(item);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 💡 ここでアイテムを追加する命令を出します
          final text = controller.text;
          if (text.isNotEmpty) {
            repository.addItem(text);
            // 3. 保存したら入力欄を空にする
            controller.clear();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
