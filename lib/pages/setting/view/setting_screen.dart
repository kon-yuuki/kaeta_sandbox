import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/providers/families_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../../main.dart';
import '../../home/home_screen.dart';
import '../../login/view/login_screen.dart';

class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({super.key});

  @override
  ConsumerState<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingPage> {
  // 1. メイン画面の「新規追加」用コントローラー
  late TextEditingController controller;
  String name = "";

  // クラスの冒頭に家族名用のコントローラーを追加
late TextEditingController familyNameController;


  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  familyNameController = TextEditingController(); // 追加
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
      body: SingleChildScrollView( // ← これではみ出しを解決！
  child: Padding(
    padding: const EdgeInsets.all(15.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("ユーザー設定", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextField(controller: controller, decoration: const InputDecoration(labelText: "ユーザー名")),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: () => repository.updateProfile(name), child: const Text("名前を保存")),
        
        const Divider(height: 40),
        const Text("家族を新しく作る", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextField(
          controller: familyNameController,
          decoration: const InputDecoration(labelText: "家族名（例：マイホーム）", hintText: "名前を入力してください"),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () async {
            if (familyNameController.text.isEmpty) return;
            await ref.read(familiesRepositoryProvider).createFirstFamily(familyNameController.text);
            familyNameController.clear();
          },
          child: const Text("家族を作成"),
        ),

        const Divider(height: 40),
        const Text("参加中の家族（タップで選択 / 長押しで削除）"),
        ref.watch(joinedFamiliesProvider).when(
          data: (families) => Column(
            children: [
              // 個人用メモの選択肢
              ListTile(
                title: const Text('個人用メモ'),
                leading: const Icon(Icons.person),
                trailing: ref.watch(selectedFamilyIdProvider) == null ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () => ref.read(profileRepositoryProvider).updateCurrentFamily(null),
              ),
              // 家族リスト
              ...families.map((f) => ListTile(
                title: Text(f.name),
                leading: const Icon(Icons.group),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (f.id == ref.watch(selectedFamilyIdProvider)) const Icon(Icons.check, color: Colors.blue),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        // 削除確認ダイアログを出すとより親切です
                        await ref.read(familiesRepositoryProvider).deleteFamily(f.id);
                      },
                    ),
                  ],
                ),
                onTap: () => ref.read(profileRepositoryProvider).updateCurrentFamily(f.id),
              )),
            ],
          ),
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    ),
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
