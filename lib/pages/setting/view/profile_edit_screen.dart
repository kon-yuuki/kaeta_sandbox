import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/common_app_bar.dart';
import '../../../core/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/providers/profiles_provider.dart';

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

class ProfileEditScreen extends StatelessWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(showBackButton: true, title: 'プロフィール'),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: ProfileEditSection(),
      ),
    );
  }
}

class ProfileEditSection extends ConsumerStatefulWidget {
  const ProfileEditSection({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  ConsumerState<ProfileEditSection> createState() => _ProfileEditSectionState();
}

class _ProfileEditSectionState extends ConsumerState<ProfileEditSection> {
  static const int _maxLength = 15;
  late final TextEditingController _nameController;
  String _seededName = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _getLimitWarning(int currentLength) {
    if (currentLength >= _maxLength) {
      return '入力文字数は$_maxLength文字以内にしてください';
    }
    return null;
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
                    child: const Icon(
                      Icons.add_photo_alternate,
                      color: Colors.grey,
                    ),
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
          AppButton(
            variant: AppButtonVariant.text,
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
      await ref.read(profileRepositoryProvider).updateAvatar(url: pickedFile.path);
      if (mounted) showTopSnackBar(context, 'アイコンを変更しました');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myProfile = ref.watch(myProfileProvider).value;
    final repository = ref.watch(profileRepositoryProvider);
    final displayName = myProfile?.displayName?.trim() ?? '';

    if (_seededName.isEmpty && displayName.isNotEmpty) {
      _seededName = displayName;
      _nameController.text = displayName;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showTitle)
          const Text(
            'プロフィール',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        if (widget.showTitle) const SizedBox(height: 16),
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
          child: AppButton(
            variant: AppButtonVariant.text,
            onPressed: _showAvatarSelectionDialog,
            child: const Text('アイコンを変更'),
          ),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _nameController,
          maxLength: _maxLength,
          label: 'ユーザー名',
          errorText: _getLimitWarning(_nameController.text.length),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            onPressed: _getLimitWarning(_nameController.text.length) != null
                ? null
                : () async {
                    final inputName = _nameController.text.trim().isEmpty
                        ? 'ゲスト'
                        : _nameController.text.trim();
                    await repository.updateProfile(inputName);
                    if (context.mounted) {
                      showTopSnackBar(context, '名前を「$inputName」に保存しました');
                    }
                  },
            child: const Text('名前を保存'),
          ),
        ),
      ],
    );
  }
}
