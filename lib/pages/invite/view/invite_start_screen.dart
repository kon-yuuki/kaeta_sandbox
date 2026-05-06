import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/providers/families_provider.dart';
import '../../../data/providers/notifications_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../../data/repositories/families_repository.dart';
import '../../login/view/invite_auth_start_screen.dart';
import '../providers/invite_flow_provider.dart';
import 'invite_error_screen.dart';

class InviteStartPreviewData {
  const InviteStartPreviewData({
    required this.familyName,
    required this.inviterName,
  });

  final String familyName;
  final String inviterName;
}

class InviteStartPage extends ConsumerStatefulWidget {
  const InviteStartPage({super.key, required this.inviteId, this.previewData});

  final String inviteId;
  final InviteStartPreviewData? previewData;

  @override
  ConsumerState<InviteStartPage> createState() => _InviteStartPageState();
}

class _InviteStartPageState extends ConsumerState<InviteStartPage> {
  static const _heroAssetPath = 'assets/icons/user-plus.png';
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _familyId;
  String _familyName = '不明';
  String _inviterName = '誰か';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvitation();
    });
  }

  Future<void> _loadInvitation() async {
    final previewData = widget.previewData;
    if (previewData != null) {
      setState(() {
        _isLoading = false;
        _familyId = 'debug-preview-family';
        _familyName = previewData.familyName;
        _inviterName = previewData.inviterName;
      });
      return;
    }

    final repo = ref.read(familiesRepositoryProvider);
    final invitation = await repo.fetchInvitationDetails(widget.inviteId);
    if (!mounted) return;

    if (!invitation.isSuccess) {
      final error = invitation.error;
      final isInvalidInvite =
          error == InvitationFetchError.notFound ||
          error == InvitationFetchError.expired;
      final message = switch (error) {
        InvitationFetchError.notFound => '招待リンクが見つかりません',
        InvitationFetchError.expired => '期限が切れたURLです。招待リンクの有効期間は7日間です。',
        _ => '通信エラーが発生しました。時間をおいて再度お試しください',
      };
      if (isInvalidInvite) {
        await ref.read(inviteFlowPersistenceProvider).clearPendingInviteId();
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => InviteErrorPage(message: message)),
      );
      return;
    }

    final details = invitation.details!;
    setState(() {
      _isLoading = false;
      _familyId = details['family_id'] as String?;
      _familyName = (details['families']?['name'] as String?) ?? '不明';
      _inviterName = (details['profiles']?['display_name'] as String?) ?? '誰か';
    });
  }

  Future<void> _startJoinFlow() async {
    if (_isSubmitting) return;
    if (widget.previewData != null) {
      showTopSnackBar(context, 'プレビューモードのため参加処理は実行されません', saveToHistory: false);
      return;
    }
    setState(() => _isSubmitting = true);
    await ref
        .read(inviteFlowPersistenceProvider)
        .setPendingInviteId(widget.inviteId);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const InviteAuthStartPage()));
      return;
    }

    final profile = await ref.read(myProfileProvider.future);
    final isOnboardingCompleted = profile?.onboardingCompleted == true;
    if (isOnboardingCompleted && _familyId != null && _familyId!.isNotEmpty) {
      final repo = ref.read(familiesRepositoryProvider);
      final result = await repo.joinFamily(
        _familyId!,
        inviteId: widget.inviteId,
      );
      if (!mounted) return;

      if (result == JoinFamilyResult.joined ||
          result == JoinFamilyResult.alreadyMember) {
        if (result == JoinFamilyResult.joined) {
          await ref
              .read(notificationsRepositoryProvider)
              .notifyTeamJoined(familyId: _familyId!);
        }
        await ref.read(inviteFlowPersistenceProvider).clearPendingInviteId();
        ref.invalidate(selectedFamilyIdProvider);
        ref.invalidate(joinedFamiliesProvider);
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      final message = switch (result) {
        JoinFamilyResult.alreadyHasFamily => 'すでに別のチームに参加しています。',
        JoinFamilyResult.invalidInvite => 'この招待リンクは無効です。新しい招待リンクを受け取ってください。',
        JoinFamilyResult.notSignedIn => 'ログイン状態を確認できません。もう一度お試しください。',
        _ => 'チーム参加に失敗しました。時間をおいて再度お試しください。',
      };
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showTopSnackBar(context, message, saveToHistory: false);
      return;
    }

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('参加してはじめる')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            children: [
              const SizedBox(height: 26),
              Image.asset(
                _heroAssetPath,
                width: 54,
                height: 54,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 22),
              const Text(
                'このチームに参加しますか？',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF2C3844),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'アカウント連携・プロフィール設定後に\nすぐに利用を開始できます',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF7B8CA5),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6FA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Text(
                        _familyName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(height: 22),
              const Text(
                '招待した人',
                style: TextStyle(
                  color: Color(0xFF8A99AD),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _inviterName,
                style: const TextStyle(
                  color: Color(0xFF2C3844),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  onPressed: (!_isLoading && _familyId != null)
                      ? _startJoinFlow
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: const Color(0xFF334155),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('参加してはじめる'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
