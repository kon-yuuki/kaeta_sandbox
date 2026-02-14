import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../data/providers/families_provider.dart';
import '../../data/providers/profiles_provider.dart';
import '../../data/repositories/families_repository.dart';
import '../invite/providers/invite_flow_provider.dart';
import 'providers/onboarding_provider.dart';
import 'widgets/profile_setup_step.dart';
import 'widgets/icon_selection_step.dart';
import 'widgets/team_invite_step.dart';
import 'widgets/notification_step.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({
    super.key,
    this.requireEmailCredentials = false,
    this.onComplete,
    this.onExitRequested,
  });

  final bool requireEmailCredentials;
  final VoidCallback? onComplete;
  final Future<void> Function()? onExitRequested;

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  static const List<String> _defaultStepLabels = [
    'ユーザー情報',
    'アイコン設定',
    '家族を招待',
    '通知設定',
  ];
  static const List<String> _inviteStepLabels = [
    'ユーザー情報',
    'アイコン設定',
    '通知設定',
  ];

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
    final pendingInviteId = ref.read(pendingInviteIdProvider);
    final isInviteFlow = pendingInviteId != null && pendingInviteId.isNotEmpty;
    final maxIndex = isInviteFlow ? 2 : 3;
    if (_currentPage < maxIndex) {
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
    widget.onComplete?.call();
  }

  Future<void> _markReadyModalPending() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('home_ready_modal_pending_${user.id}', true);
  }

  Future<void> _completeOnboarding() async {
    final data = ref.read(onboardingDataProvider);

    if (data.avatarPreset != null || data.avatarUrl != null) {
      await ref.read(profileRepositoryProvider).updateAvatar(
        preset: data.avatarPreset,
        url: data.avatarUrl,
      );
    }

    final pendingInviteId = ref.read(pendingInviteIdProvider);
    if (pendingInviteId != null && pendingInviteId.isNotEmpty) {
      final repo = ref.read(familiesRepositoryProvider);
      final invitation = await repo.fetchInvitationDetails(pendingInviteId);
      if (invitation.isSuccess) {
        final familyId = invitation.details?['family_id'] as String?;
        if (familyId != null && familyId.isNotEmpty) {
          final result = await repo.joinFamily(
            familyId,
            inviteId: pendingInviteId,
          );
          if (result == JoinFamilyResult.joined ||
              result == JoinFamilyResult.alreadyMember) {
            ref.invalidate(selectedFamilyIdProvider);
            ref.invalidate(joinedFamiliesProvider);
          }
        }
      }
      ref.read(pendingInviteIdProvider.notifier).state = null;
    }

    await ref.read(profileRepositoryProvider).completeOnboarding();
    await _markReadyModalPending();
    ref.invalidate(myProfileProvider);
    _onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final pendingInviteId = ref.watch(pendingInviteIdProvider);
    final isInviteFlow = pendingInviteId != null && pendingInviteId.isNotEmpty;
    final stepLabels = isInviteFlow ? _inviteStepLabels : _defaultStepLabels;
    final showHeader = _currentPage < stepLabels.length;

    return Scaffold(
      backgroundColor: colors.surfaceHighOnInverse,
      body: SafeArea(
        child: Column(
          children: [
            if (showHeader) ...[
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () async {
                        if (_currentPage == 0) {
                          if (widget.onExitRequested != null) {
                            await widget.onExitRequested!.call();
                            return;
                          }
                          if (!context.mounted) return;
                          Navigator.of(context).maybePop();
                          return;
                        }
                        _previousPage();
                      },
                      icon: Icon(Icons.arrow_back_ios_new, color: colors.surfaceMedium),
                    ),
                    Expanded(
                      child: Text(
                        stepLabels[_currentPage],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textHigh,
                          fontSize: 20 / 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.borderLow),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: _OnboardingStepIndicator(
                  currentStep: _currentPage,
                  labels: stepLabels,
                ),
              ),
            ],
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
                  ProfileSetupStep(
                    onNext: _nextPage,
                    requireEmailCredentials: widget.requireEmailCredentials,
                    requireTeamName: !isInviteFlow,
                  ),
                  IconSelectionStep(onNext: _nextPage, onBack: _previousPage),
                  if (!isInviteFlow)
                    TeamInviteStep(onNext: _nextPage, onBack: _previousPage),
                  NotificationStep(
                    onComplete: _completeOnboarding,
                    onBack: _previousPage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStepIndicator extends StatelessWidget {
  const _OnboardingStepIndicator({
    required this.currentStep,
    required this.labels,
  });

  final int currentStep;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final safeStep = currentStep.clamp(0, labels.length - 1);

    return Column(
      children: [
        Row(
          children: List.generate(labels.length * 2 - 1, (index) {
            if (index.isOdd) {
              final isActive = (index ~/ 2) < safeStep;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  height: 2,
                  decoration: BoxDecoration(
                    color: isActive ? colors.accentPrimary : colors.borderMedium,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              );
            }

            final stepIndex = index ~/ 2;
            final isDone = stepIndex <= safeStep;
            return Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isDone ? colors.accentPrimary : colors.surfaceHighOnInverse,
                border: Border.all(
                  color: isDone ? colors.accentPrimary : colors.borderMedium,
                  width: 1.5,
                ),
                shape: BoxShape.circle,
              ),
              child: isDone
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: colors.textHighOnInverse,
                    )
                  : Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.borderMedium,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(labels.length, (index) {
            return Expanded(
              child: Text(
                labels[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: index <= safeStep ? colors.textAccentPrimary : colors.textLow,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
