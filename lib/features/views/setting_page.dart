import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/profiles_provider.dart';
import '../../main.dart';
import '../../database/database.dart';
import 'todo_page.dart';
import 'login_page.dart';

class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({super.key});

  @override
  ConsumerState<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingPage> {
  // 1. メイン画面の「新規追加」用コントローラー
  late TextEditingController controller;
  String name = "";

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
    final repository = ref.watch(profileRepositoryProvider);
    final myProfile = ref.watch(myProfileProvider).value;
    // かつプロフィールのデータが届いたら、その値をセットする
    debugPrint(myProfile?.displayName);
    if (name == "" && myProfile?.displayName != null) {
      name = myProfile!.displayName!;
      controller.text = name; // 画面の入力欄にも反映
    }
    int _currentIndex = 0;

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
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            Text("ユーザー名"),
            TextField(
              controller: controller,
              onChanged: (value) {
                name = value;
              },
            ),
            ElevatedButton(
              onPressed: () {
                repository.updateProfile(name);
              },
              child: Text("名前を保存"),
            ),
          ],
        ),
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
                    onTap: () {
                      Navigator.pop(
                        context,
                        MaterialPageRoute(builder: (context) => TodoPage()),
                      );
                    },
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
                    onTap: () {},
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
