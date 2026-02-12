import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/providers/families_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../providers/onboarding_provider.dart';

class TeamInviteStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const TeamInviteStep({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<TeamInviteStep> createState() => _TeamInviteStepState();
}

class _TeamInviteStepState extends ConsumerState<TeamInviteStep> {
  String? _inviteUrl;
  DateTime? _inviteExpiresAt;
  bool _isLoading = false;
  bool _teamCreated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _createTeamAndGetInviteUrl();
    });
  }

  Future<void> _createTeamAndGetInviteUrl() async {
    setState(() => _isLoading = true);

    try {
      final data = ref.read(onboardingDataProvider);
      final teamName = data.teamName;
      final displayName = data.displayName;

      if (displayName.isEmpty || teamName.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      await ref.read(profileRepositoryProvider).ensureProfile(displayName: displayName);
      await ref.read(profileRepositoryProvider).updateProfileWithName(displayName);

      final existingProfile = await ref.read(myProfileProvider.future);
      String? familyId = existingProfile?.currentFamilyId;

      if (familyId == null) {
        await ref.read(familiesRepositoryProvider).createFirstFamily(teamName);
        await Future.delayed(const Duration(milliseconds: 500));
        final profile = await ref.read(myProfileProvider.future);
        familyId = profile?.currentFamilyId;
      }

      if (familyId != null) {
        final inviteInfo =
            await ref.read(familiesRepositoryProvider).getInviteLinkInfo(familyId);
        setState(() {
          _inviteUrl = inviteInfo?.url;
          _inviteExpiresAt = inviteInfo?.expiresAt;
          _teamCreated = true;
        });
      } else {
        setState(() {
          _teamCreated = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('エラーが発生しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatInviteExpiry(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.year}/${local.month}/${local.day} $hh:$mm';
  }

  String? _buildInviteText() {
    final inviteUrl = _inviteUrl;
    if (inviteUrl == null || inviteUrl.isEmpty) return null;

    final data = ref.read(onboardingDataProvider);
    final expiresText = _inviteExpiresAt != null
        ? '有効期限: ${_formatInviteExpiry(_inviteExpiresAt!)}'
        : '';

    return '買い物メモアプリで一緒にリストを共有しましょう！\n'
        'こちらのリンクから「${data.teamName}」に参加できます。\n\n'
        '$inviteUrl\n\n'
        '$expiresText';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _shareToLine() async {
    final text = _buildInviteText();
    if (text == null) {
      _showMessage('招待リンクを準備中です');
      return;
    }

    final uri = Uri.parse('https://line.me/R/msg/text/?${Uri.encodeComponent(text)}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _showMessage('LINEを開けませんでした');
  }

  Future<void> _shareByEmail() async {
    final text = _buildInviteText();
    if (text == null) {
      _showMessage('招待リンクを準備中です');
      return;
    }

    final uri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': '家族グループへの招待',
        'body': text,
      },
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _showMessage('メールアプリを開けませんでした');
  }

  Future<void> _copyInviteLink() async {
    final inviteUrl = _inviteUrl;
    if (inviteUrl == null || inviteUrl.isEmpty) {
      _showMessage('招待リンクを準備中です');
      return;
    }
    await Clipboard.setData(ClipboardData(text: inviteUrl));
    if (mounted) _showMessage('招待リンクをコピーしました');
  }

  Future<void> _shareOther() async {
    final text = _buildInviteText();
    if (text == null) {
      _showMessage('招待リンクを準備中です');
      return;
    }

    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      text,
      subject: '家族グループへの招待',
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : Rect.zero,
    );
  }

  Widget _shareRow({
    IconData? icon,
    String? assetPath,
    required String label,
    required VoidCallback onTap,
    bool showIconBackground = true,
  }) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: showIconBackground
                  ? Container(
                      decoration: BoxDecoration(
                        color: colors.surfaceHighOnInverse,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: assetPath != null
                          ? Padding(
                              padding: const EdgeInsets.all(6),
                              child: Image.asset(assetPath, fit: BoxFit.contain),
                            )
                          : Icon(icon, color: colors.textMedium, size: 20),
                    )
                  : (assetPath != null
                        ? Padding(
                            padding: const EdgeInsets.all(2),
                            child: Image.asset(assetPath, fit: BoxFit.contain),
                          )
                        : Icon(icon, color: colors.textMedium, size: 20)),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: colors.textHigh,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(
        children: [
          const SizedBox(height: 18),
          Text(
            '家族を招待してリストを共有する',
            style: TextStyle(
              color: colors.textHigh,
              fontSize: 24 / 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '招待リンクから相手が参加すると\nメンバーに追加されます',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textLow,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      _shareRow(
                        assetPath: 'assets/icons/LINE_Brand_icon.png',
                        label: 'LINEで招待する',
                        onTap: _shareToLine,
                        showIconBackground: false,
                      ),
                      _shareRow(
                        icon: Icons.mail_outline,
                        label: 'メールで招待する',
                        onTap: _shareByEmail,
                      ),
                      _shareRow(
                        icon: Icons.link,
                        label: '招待リンクをコピーする',
                        onTap: _copyInviteLink,
                      ),
                      _shareRow(
                        icon: Icons.ios_share,
                        label: 'その他の共有',
                        onTap: _shareOther,
                      ),
                    ],
                  ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 14, color: colors.textAccentPrimary),
              const SizedBox(width: 4),
              Text(
                '設定画面であとから招待もできます',
                style: TextStyle(
                  color: colors.textMedium,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: _teamCreated ? widget.onNext : null,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('通知設定に進む', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
          if (MediaQuery.of(context).padding.bottom > 0)
            SizedBox(height: MediaQuery.of(context).padding.bottom - 4),
        ],
      ),
    );
  }
}
