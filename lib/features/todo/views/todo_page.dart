import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/todo_provider.dart';
import '../../../database/database.dart';

class TodoPage extends ConsumerStatefulWidget {
  const TodoPage({super.key});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> {
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(todoRepositoryProvider);

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
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("未完了タスク", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: StreamBuilder<List<TodoItem>>(
              stream: repository.watchUnCompleteItems(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('エラー発生: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!;
                return TodoListView(
                  items: items, // 表示するデータの配列
                  // 💡 ここで「親の持っている repository」を使った処理を、子に託します
                  onToggle: (item) => repository.completeItem(item),
                  onDelete: (item) => repository.deleteItem(item),
                  onTap: (item) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'アイテムを編集',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextField(
                                autofocus: true,
                                controller: TextEditingController(
                                  text: item.name,
                                ),
                                onSubmitted: (newName) async {
                                  if(newName.isNotEmpty){
                                  await repository.updateItemName(item, newName);
                                  }
                                  if(mounted){
                                  Navigator.pop(context);
                                  }
                                },
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  isHistory: false, // 下のエリアなら true にする
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              "履歴",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 60,
            child: StreamBuilder<List<PurchaseHistoryData>>(
              stream: repository.watchTopPurchaseHistory(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      '履歴はまだありません',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                final historyItems = snapshot.data!;
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: historyItems.length,
                  itemBuilder: (context, index) {
                    final history = historyItems[index];

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        label: Text(
                          "${history.name} (${history.purchaseCount})",
                        ),
                        onPressed: () {
                          controller.text = history.name;
                        },
                        backgroundColor: Colors.blue.shade50,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
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

class TodoListView extends StatelessWidget {
  final List<TodoItem> items;
  final Function(TodoItem) onToggle;
  final Function(TodoItem) onDelete;
  final Function(TodoItem) onTap;
  final bool isHistory;

  const TodoListView({
    super.key,
    required this.items,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
    this.isHistory = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          onTap: () => onTap(item),
          leading: Checkbox(
            value: item.isCompleted,
            onChanged: (value) => onToggle(item),
          ),
          title: Text(
            item.name,
            style: TextStyle(
              decoration: isHistory ? TextDecoration.lineThrough : null,
              color: isHistory ? Colors.grey : null,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete), // 2. 正しいアイコンの書き方
            onPressed: () => onDelete(item),
          ),
        );
      },
    );
  }
}
