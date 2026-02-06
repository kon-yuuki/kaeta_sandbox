import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/common_app_bar.dart';
import '../../../core/snackbar_helper.dart';
import '../../../data/providers/families_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../home/widgets/home_bottom_nav_bar.dart';

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
    familyNameController = TextEditingController();
    ref.read(profileRepositoryProvider).ensureProfile();
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
    final repository = ref.watch(profileRepositoryProvider);
    final myProfile = ref.watch(myProfileProvider).value;
    // かつプロフィールのデータが届いたら、その値をセットする
    debugPrint(myProfile?.displayName);
    if (name == "" && myProfile?.displayName != null) {
      name = myProfile!.displayName!;
      controller.text = name; // 画面の入力欄にも反映
    }
    return Scaffold(
      appBar: const CommonAppBar(),
      body: SingleChildScrollView( 
  child: Padding(
    padding: const EdgeInsets.all(15.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("ユーザー設定", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextField(controller: controller, decoration: const InputDecoration(labelText: "ユーザー名")),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () async {
            final inputName = controller.text.trim().isEmpty ? 'ゲスト' : controller.text.trim();
            await repository.updateProfile(inputName);
            if (context.mounted) showTopSnackBar(context, '名前を「$inputName」に保存しました');
          },
          child: const Text("名前を保存"),
        ),
        
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
            final familyName = familyNameController.text;
            await ref.read(familiesRepositoryProvider).createFirstFamily(familyName);
            familyNameController.clear();
            if (context.mounted) showTopSnackBar(context, '家族「$familyName」を作成しました');
          },
          child: const Text("家族を作成"),
        ),

        const Divider(height: 40),
        const Text("参加中の家族（タップで選択 / 長押しで削除）"),
        ref.watch(joinedFamiliesProvider).when(
          data: (families) => Column(
            children: [
              ListTile(
                title: const Text('個人用メモ'),
                leading: const Icon(Icons.person),
                trailing: ref.watch(selectedFamilyIdProvider) == null ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () => ref.read(profileRepositoryProvider).updateCurrentFamily(null),
              ),
              ...families.map((f) => ListTile(
                title: Text(f.name),
                leading: const Icon(Icons.group),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (f.id == ref.watch(selectedFamilyIdProvider)) const Icon(Icons.check, color: Colors.blue),
                    Builder(builder: (buttonContext) {
                      return IconButton(
                        icon: const Icon(Icons.person_add_alt_1, color: Colors.blue),
                        onPressed: () async {
                          final inviteUrl = await ref.read(familiesRepositoryProvider).createInviteUrl(f.id);
                          if (inviteUrl != null && buttonContext.mounted) {
                            final box = buttonContext.findRenderObject() as RenderBox?;
                            await Share.share(
                              '買い物メモアプリで一緒にリストを共有しましょう！\n'
                              'こちらのリンクから家族グループ「${f.name}」に参加できます。\n\n'
                              '$inviteUrl',
                              subject: '家族グループへの招待',
                              sharePositionOrigin: box != null
                                  ? box.localToGlobal(Offset.zero) & box.size
                                  : Rect.zero,
                            );
                          }
                        },
                      );
                    }),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
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
      bottomNavigationBar: const HomeBottomNavBar(currentIndex: 1),
    );
  }
}
