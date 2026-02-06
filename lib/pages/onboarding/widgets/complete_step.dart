import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/profiles_provider.dart';
import '../providers/onboarding_provider.dart';

class CompleteStep extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const CompleteStep({super.key, required this.onComplete});

  @override
  ConsumerState<CompleteStep> createState() => _CompleteStepState();
}

class _CompleteStepState extends ConsumerState<CompleteStep> {
  bool _isCompleting = false;

  Future<void> _completeOnboarding() async {
    setState(() => _isCompleting = true);

    try {
      final data = ref.read(onboardingDataProvider);

      // アバター情報を保存
      if (data.avatarPreset != null || data.avatarUrl != null) {
        await ref.read(profileRepositoryProvider).updateAvatar(
          preset: data.avatarPreset,
          url: data.avatarUrl,
        );
      }

      // オンボーディング完了をマーク
      await ref.read(profileRepositoryProvider).completeOnboarding();

      widget.onComplete();
    } catch (e) {
      if (mounted) {
        setState(() => _isCompleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(onboardingDataProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;

    // onboardingDataが空の場合はDBから取得（ホットリロード対策）
    final displayName = data.displayName.isNotEmpty
        ? data.displayName
        : profile?.displayName ?? '';
    final teamName = data.teamName.isNotEmpty ? data.teamName : 'チーム';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            '準備完了！',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            '$displayNameさん、ようこそ！',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '「$teamName」の買い物リストを\n始めましょう',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.shopping_cart_outlined, size: 40, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  '買い物リストを追加できます',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  '追加した商品はチームメンバーと\n自動で共有されます',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isCompleting ? null : _completeOnboarding,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _isCompleting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('はじめる', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
