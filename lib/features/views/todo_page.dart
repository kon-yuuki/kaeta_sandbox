import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/todo_provider.dart';
import '../providers/profiles_provider.dart';
import '../../main.dart';
import '../../database/database.dart';
import 'login_page.dart';
import '../notification/notification_service.dart';
import "./setting_page.dart";

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
    Future.microtask(() => ref.read(profileRepositoryProvider).ensureProfile());
    // 2. リポジトリ（データ操作の窓口）を取得
    final repository = ref.watch(todoRepositoryProvider);
    final sortOrder = ref.watch(todoSortOrderProvider);
    final myProfile = ref.watch(myProfileProvider).value;
    int _currentIndex = 0;
    void _onItemTapped(int index) => setState(() => _currentIndex = index);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${myProfile?.displayName ?? 'ゲスト'}のメモ',
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
                  label: Text('重要度順'),
                ),
                ButtonSegment(
                  value: TodoSortOrder.createdAt,
                  label: Text('作成日順'),
                ),
              ],
              selected: {sortOrder},
              onSelectionChanged: (newSelection) {
                ref.read(todoSortOrderProvider.notifier).state =
                    newSelection.first;
              },
            ),
          ),

          Expanded(
            child: ref
                .watch(todoListProvider)
                .when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const Center(child: Text('タスクが登録されていません'));
                    }
                    return TodoListView(
                      items: items,
                      onToggle: (item) {
                        final String taskName = item.name;
                        final familyId = myProfile?.familyId;
                        repository.completeItem(item, familyId ?? "");
                        NotificationService().showNotification(
                          id:
                              DateTime.now().millisecondsSinceEpoch ~/
                              1000, // 重複しないID
                          title: 'タスクを完了しました',
                          body: '「$taskName」を完了しました！',
                        );
                      },
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
                                              selectedPriority =
                                                  newSelection.first;
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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  // C. エラー：何らかの不具合が発生したとき
                  error: (err, stack) => Center(child: Text('読み込みエラー: $err')),
                ),
          ),

          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('履歴', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            height: 60,
            child: StreamBuilder<List<PurchaseHistoryData>>(
              stream: repository.watchTopPurchaseHistory(
                myProfile?.familyId ?? "",
              ),
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
          final editNameController = TextEditingController();
          int selectedPriority = selectedPriorityForNew;
          int selectedCategoryValue = 0;
          const List<String> categories = [
            "指定なし",
            "カテゴリ1",
            "カテゴリ2",
            "カテゴリ3",
            "カテゴリ4",
          ];
          String category = "指定なし";

          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (modalContext) {
              return StatefulBuilder(
                builder: (context, setModalState) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: editNameController,
                            decoration: const InputDecoration(
                              labelText: 'アイテムを追加',
                            ),
                            autofocus: true,
                          ),

                          const SizedBox(height: 20),

                          Text('条件の重要度', style: TextStyle(fontSize: 12)),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 0, label: Text('普通')),
                              ButtonSegment(value: 1, label: Text('重要')),
                            ],
                            selected: {selectedPriority},
                            onSelectionChanged: (newSelection) {
                              setModalState(() {
                                selectedPriority = newSelection.first;
                              });
                            },
                          ),
                          SizedBox(
                            height: 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: categories.length,
                              itemBuilder: (BuildContext context, int index) {
                                return Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: ChoiceChip(
                                    label: Text(categories[index]),
                                    selected: selectedCategoryValue == index,
                                    onSelected: (bool selected) {
                                      setModalState(() {
                                        selectedCategoryValue = index;
                                        category = categories[index];
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              final String text = editNameController.text;
                              final familyId = myProfile?.familyId;
                              if (text.isNotEmpty && familyId != null) {
                                repository.addItem(
                                  text,
                                  category,
                                  selectedPriority,
                                  familyId,
                                );
                              }
                              NotificationService().showNotification(
                                id:
                                    DateTime.now().millisecondsSinceEpoch ~/
                                    1000, // 重複しないID
                                title: 'タスクを追加しました',
                                body: '「$text」をリストに保存しました！',
                              );
                              controller.clear();
                              setState(() {
                                selectedPriorityForNew = 0;
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('リストに追加する'),
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
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1),
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {},
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.home,
                          color: _currentIndex == 0
                              ? Colors.blueAccent
                              : Colors.grey,
                        ),
                        Text(
                          "ホーム",
                          style: TextStyle(
                            fontSize: 10,
                            color: _currentIndex == 0
                                ? Colors.blueAccent
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SettingPage()),
                      );
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.settings,
                          color: _currentIndex == 0
                              ? Colors.blueAccent
                              : Colors.grey,
                        ),
                        Text(
                          "設定",
                          style: TextStyle(
                            fontSize: 10,
                            color: _currentIndex == 0
                                ? Colors.blueAccent
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    decoration: isHistory ? TextDecoration.lineThrough : null,
                    color: isHistory ? Colors.grey : null,
                  ),
                ),
              ),
              ActionChip(
                label: Text(item.category),
                onPressed: () {
                  print('カテゴリ一覧に遷移処理');
                },
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
