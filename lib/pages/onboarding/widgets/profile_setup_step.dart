import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_heading.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/providers/profiles_provider.dart';
import '../providers/onboarding_provider.dart';

class ProfileSetupStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  const ProfileSetupStep({super.key, required this.onNext});

  @override
  ConsumerState<ProfileSetupStep> createState() => _ProfileSetupStepState();
}

class _ProfileSetupStepState extends ConsumerState<ProfileSetupStep> {
  static const int _maxLength = 15;

  late TextEditingController _nameController;
  late TextEditingController _teamController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _teamController = TextEditingController();

    // OAuthから名前を取得して自動入力
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final oauthName = ref.read(profileRepositoryProvider).getOAuthDisplayName();
      if (oauthName != null && _nameController.text.isEmpty) {
        // 15文字を超える場合は切り詰める
        final truncatedName = oauthName.length > _maxLength
            ? oauthName.substring(0, _maxLength)
            : oauthName;
        _nameController.text = truncatedName;
        ref.read(onboardingDataProvider.notifier).setDisplayName(truncatedName);
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teamController.dispose();
    super.dispose();
  }

  bool _isValid() {
    final nameTrimmed = _nameController.text.trim();
    final teamTrimmed = _teamController.text.trim();
    return nameTrimmed.isNotEmpty &&
        nameTrimmed.length < _maxLength &&
        teamTrimmed.isNotEmpty &&
        teamTrimmed.length < _maxLength;
  }

  String? _getLimitWarning(int currentLength) {
    if (currentLength >= _maxLength) {
      return '入力文字数は$_maxLength文字以内にしてください';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final nameWarning = _getLimitWarning(_nameController.text.length);
    final teamWarning = _getLimitWarning(_teamController.text.length);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const AppHeading('プロフィールを設定', type: AppHeadingType.primary),
          const SizedBox(height: 8),
          const Text(
            'あなたの名前とチーム名を入力してください',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          AppTextField(
            controller: _nameController,
            maxLength: _maxLength,
            label: 'あなたの名前',
            hintText: '例: 山田太郎',
            errorText: nameWarning,
            onChanged: (value) {
              ref.read(onboardingDataProvider.notifier).setDisplayName(value);
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _teamController,
            maxLength: _maxLength,
            label: 'チーム名',
            hintText: '例: 山田家',
            errorText: teamWarning,
            onChanged: (value) {
              ref.read(onboardingDataProvider.notifier).setTeamName(value);
              setState(() {});
            },
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: _isValid()
                  ? () {
                      FocusScope.of(context).unfocus();
                      widget.onNext();
                    }
                  : null,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('アイコン設定へ', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
