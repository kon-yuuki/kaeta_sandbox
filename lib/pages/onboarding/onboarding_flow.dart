import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/profiles_provider.dart';
import 'providers/onboarding_provider.dart';
import 'widgets/profile_setup_step.dart';
import 'widgets/icon_selection_step.dart';
import 'widgets/team_invite_step.dart';
import 'widgets/notification_step.dart';
import 'widgets/complete_step.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // オンボーディング開始時にプロフィールを確実に作成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileRepositoryProvider).ensureProfile();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onComplete() {
    // オンボーディング完了後、ホーム画面へ
    // main.dartのStreamBuilderが自動的にTodoPageへ遷移する
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // プログレスインジケーター
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: List.generate(5, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // ページビュー
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  ref.read(onboardingStepProvider.notifier).goTo(index);
                },
                children: [
                  ProfileSetupStep(onNext: _nextPage),
                  IconSelectionStep(onNext: _nextPage, onBack: _previousPage),
                  TeamInviteStep(onNext: _nextPage, onBack: _previousPage),
                  NotificationStep(onNext: _nextPage, onBack: _previousPage),
                  CompleteStep(onComplete: _onComplete),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
