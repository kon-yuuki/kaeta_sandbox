import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/todo_provider.dart';
import '../../../main.dart';
import '../../../database/database.dart';
import '../../todo/views/login_page.dart';

class TodoPage extends ConsumerStatefulWidget {
  const TodoPage({super.key});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> {
  // 1. メイン画面の「新規追加」用コントローラー
  late TextEditingController controller;
  int selectedPriorityForNew = 0; // 💡 追加：デフォルトは「普通(0)」

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void dispose() {
    // 使い終わったらメモリを解放する
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 2. リポジトリ（データ操作の窓口）を取得
    final repository = ref.watch(todoRepositoryProvider);
    final sortOrder = ref.watch(todoSortOrderProvider);
    final searchQuery = ref.watch(todoSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${Supabase.instance.client.auth.currentUser?.userMetadata?['full_name'] ?? 'ゲスト'}のメモ',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // 1. Supabaseからサインアウト
              await Supabase.instance.client.auth.signOut();

              await db.disconnectAndClear();

              // 2. ログイン画面へ戻す（今の画面を捨てて LoginPage へ）
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBar(
              leading: const Icon(Icons.search),
              hintText: 'タスクを検索...',
              elevation: WidgetStateProperty.all(0.5),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) {
                ref.read(todoSearchQueryProvider.notifier).state = value;
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: "メモを追加"),
              onSubmitted: (text) {
                if (text.isNotEmpty) {
                  repository.addItem(text, selectedPriorityForNew);
                  controller.clear();
                  setState(() {
                    selectedPriorityForNew = 0;
                  });
                }
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('普通')),
                ButtonSegment(value: 1, label: Text('重要')),
              ],
              selected: {selectedPriorityForNew},
              onSelectionChanged: (newSelection) {
                setState(() {
                  selectedPriorityForNew = newSelection.first;
                });
              },
            ),
          ),

          const SizedBox(height: 30),

          // 2. ラベル
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              "未完了タスク",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SegmentedButton<TodoSortOrder>(
              segments: const [
                ButtonSegment(
                  value: TodoSortOrder.priority,
                  label: Text('重要度'),
                ),
                ButtonSegment(
                  value: TodoSortOrder.createdAt,
                  label: Text('作成日'),
                ),
              ],
              selected: {sortOrder},
              onSelectionChanged: (newSelection) {
                ref.read(todoSortOrderProvider.notifier).state =
                    newSelection.first;
              },
            ),
          ),

          // 3. メインのリスト表示
          Expanded(
            child: StreamBuilder<List<TodoItem>>(
              stream: repository.watchUnCompleteItems(sortOrder,searchQuery),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data!;
                return TodoListView(
                  items: items,
                  onToggle: (item) => repository.completeItem(item),
                  onDelete: (item) => repository.deleteItem(item),
                  onTap: (item) {
                    final editNameController = TextEditingController(
                      text: item.name,
                    );
                    int selectedPriority = item.priority;

                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (modalContext) {
                        return StatefulBuilder(
                          builder: (context, setModalState) {
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: MediaQuery.of(
                                  context,
                                ).viewInsets.bottom,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: editNameController,
                                      decoration: const InputDecoration(
                                        labelText: '名前を編集',
                                      ),
                                      autofocus: true,
                                    ),

                                    const SizedBox(height: 20),

                                    SegmentedButton<int>(
                                      segments: const [
                                        ButtonSegment(
                                          value: 0,
                                          label: Text('普通'),
                                        ),
                                        ButtonSegment(
                                          value: 1,
                                          label: Text('重要'),
                                        ),
                                      ],
                                      selected: {selectedPriority},
                                      onSelectionChanged: (newSelection) {
                                        setModalState(() {
                                          selectedPriority = newSelection.first;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () {
                                        repository.updateItemName(
                                          item,
                                          editNameController.text,
                                          selectedPriority,
                                        );
                                        Navigator.pop(context);
                                      },
                                      child: const Text('保存'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('履歴', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            height: 60,
            child: StreamBuilder<List<PurchaseHistoryData>>(
              stream: repository.watchTopPurchaseHistory(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final historyItems = snapshot.data!;

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: historyItems.length,
                  itemBuilder: (context, index) {
                    final history = historyItems[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ActionChip(
                        label: Text(
                          "${history.name} (${history.purchaseCount})",
                        ),
                        onPressed: () {
                          controller.text = history.name;
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final text = controller.text;
          if (text.isNotEmpty) {
            repository.addItem(text, selectedPriorityForNew);
            controller.clear();

            setState(() {
              selectedPriorityForNew = 0;
            });
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
          title: Row(
            children: [
              if (item.priority == 1) // 💡 重要なら炎アイコンを出す
                const Padding(
                  padding: EdgeInsets.only(right: 3.0),
                  child: Icon(Icons.whatshot, color: Colors.orange, size: 20),
                ),
              Text(
                item.name,
                style: TextStyle(
                  decoration: isHistory ? TextDecoration.lineThrough : null,
                  color: isHistory ? Colors.grey : null,
                ),
              ),
            ],
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
