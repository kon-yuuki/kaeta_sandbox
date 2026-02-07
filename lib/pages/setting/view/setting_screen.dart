import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/common_app_bar.dart';
import '../../../core/snackbar_helper.dart';
import '../../../data/model/database.dart';
import '../../../data/providers/families_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../home/widgets/home_bottom_nav_bar.dart';
import '../../login/view/login_screen.dart';

// プリセットアイコンのリスト
const List<String> _presetIcons = [
  'assets/icons/avatars/img_Men01.png',
  'assets/icons/avatars/img_Men02.png',
  'assets/icons/avatars/img_Men03.png',
  'assets/icons/avatars/img_Men04.png',
  'assets/icons/avatars/img_Men05.png',
  'assets/icons/avatars/img_Men06.png',
  'assets/icons/avatars/img_Women01.png',
  'assets/icons/avatars/img_Women02.png',
  'assets/icons/avatars/img_Women03.png',
  'assets/icons/avatars/img_Women04.png',
  'assets/icons/avatars/img_Women05.png',
  'assets/icons/avatars/img_Women06.png',
];

class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({super.key});

  @override
  ConsumerState<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingPage> {
  static const int _maxLength = 15;

  // 1. メイン画面の「新規追加」用コントローラー
  late TextEditingController controller;
  String name = "";

  // クラスの冒頭に家族名用のコントローラーを追加
  late TextEditingController familyNameController;
  bool _allowPop = false;

  String? _getLimitWarning(int currentLength) {
    if (currentLength >= _maxLength) {
      return '入力文字数は$_maxLength文字以内にしてください';
    }
    return null;
  }


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
    familyNameController.dispose();
    super.dispose();
  }

  bool _hasUnsavedInput(Profile? myProfile) {
    final profileName =
        (myProfile?.displayName?.trim().isNotEmpty ?? false)
            ? myProfile!.displayName!.trim()
            : 'ゲスト';
    final currentName =
        controller.text.trim().isEmpty ? 'ゲスト' : controller.text.trim();
    final hasNameChange = currentName != profileName;
    final hasPendingFamilyName = familyNameController.text.trim().isNotEmpty;
    return hasNameChange || hasPendingFamilyName;
  }

  Future<bool> _confirmDiscardChanges() async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('入力を破棄しますか？'),
        content: const Text('保存していない入力内容は削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return shouldDiscard == true;
  }

  Future<bool> _handleBackPressed() async {
    final myProfile = ref.read(myProfileProvider).valueOrNull;
    if (!_hasUnsavedInput(myProfile)) return true;
    return _confirmDiscardChanges();
  }

  bool get _isGuest {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.isAnonymous ?? true;
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログインが必要です'),
        content: const Text('家族機能を使うにはログインが必要です。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: const Text('ログインする'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAvatarSelectionDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アイコンを選択'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _presetIcons.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                // ライブラリから選択
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImageFromGallery();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_photo_alternate, color: Colors.grey),
                  ),
                );
              }
              final preset = _presetIcons[index - 1];
              return GestureDetector(
                onTap: () => Navigator.pop(context, preset),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(preset, fit: BoxFit.cover),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      await ref.read(profileRepositoryProvider).updateAvatar(preset: result);
      if (mounted) showTopSnackBar(context, 'アイコンを変更しました');
    }
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );

    if (pickedFile != null && mounted) {
      // TODO: 将来的にはSupabase Storageにアップロードして、URLを保存する
      await ref.read(profileRepositoryProvider).updateAvatar(url: pickedFile.path);
      if (mounted) showTopSnackBar(context, 'アイコンを変更しました');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(profileRepositoryProvider);
    final myProfile = ref.watch(myProfileProvider).value;
    debugPrint(myProfile?.displayName);
    if (name == "" && myProfile?.displayName != null) {
      name = myProfile!.displayName!;
      controller.text = name;
    }
    final hasUnsavedInput = _hasUnsavedInput(myProfile);
    return PopScope(
      canPop: _allowPop || !hasUnsavedInput,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _allowPop || !hasUnsavedInput) return;
        final shouldDiscard = await _confirmDiscardChanges();
        if (shouldDiscard && mounted) {
          setState(() => _allowPop = true);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      appBar: CommonAppBar(
        showBackButton: true,
        onBackPressed: _handleBackPressed,
      ),
      body: SingleChildScrollView(
  child: Padding(
    padding: const EdgeInsets.all(15.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("ユーザー設定", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        // プロフィールアイコン
        Center(
          child: GestureDetector(
            onTap: _showAvatarSelectionDialog,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: myProfile?.avatarPreset != null
                      ? AssetImage(myProfile!.avatarPreset!)
                      : null,
                  child: myProfile?.avatarPreset == null
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, size: 20, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _showAvatarSelectionDialog,
            child: const Text('アイコンを変更'),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          maxLength: _maxLength,
          decoration: InputDecoration(
            labelText: "ユーザー名",
            errorText: _getLimitWarning(controller.text.length),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _getLimitWarning(controller.text.length) != null
              ? null
              : () async {
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
          maxLength: _maxLength,
          decoration: InputDecoration(
            labelText: "家族名（例：マイホーム）",
            hintText: "名前を入力してください",
            errorText: _getLimitWarning(familyNameController.text.length),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _getLimitWarning(familyNameController.text.length) != null
              ? null
              : () async {
                  if (_isGuest) {
                    _showLoginRequiredDialog();
                    return;
                  }
                  if (familyNameController.text.isEmpty) return;
                  final familyName = familyNameController.text;
                  final created = await ref.read(familiesRepositoryProvider).createFirstFamily(familyName);
                  if (context.mounted) {
                    if (created) {
                      familyNameController.clear();
                      showTopSnackBar(context, '家族「$familyName」を作成しました');
                    } else {
                      showTopSnackBar(context, '同じ名前の家族「$familyName」は既に存在します');
                    }
                  }
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
    ),
    );
  }
}
