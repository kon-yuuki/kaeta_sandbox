import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/profiles_provider.dart';
import '../providers/onboarding_provider.dart';

class ProfileSetupStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  const ProfileSetupStep({super.key, required this.onNext});

  @override
  ConsumerState<ProfileSetupStep> createState() => _ProfileSetupStepState();
}

class _ProfileSetupStepState extends ConsumerState<ProfileSetupStep> {
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
        _nameController.text = oauthName;
        ref.read(onboardingDataProvider.notifier).setDisplayName(oauthName);
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
    return _nameController.text.trim().isNotEmpty &&
           _teamController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            'プロフィールを設定',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'あなたの名前とチーム名を入力してください',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'あなたの名前',
              hintText: '例: 山田太郎',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              ref.read(onboardingDataProvider.notifier).setDisplayName(value);
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _teamController,
            decoration: const InputDecoration(
              labelText: 'チーム名',
              hintText: '例: 山田家',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              ref.read(onboardingDataProvider.notifier).setTeamName(value);
              setState(() {});
            },
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isValid() ? widget.onNext : null,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('次へ', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
