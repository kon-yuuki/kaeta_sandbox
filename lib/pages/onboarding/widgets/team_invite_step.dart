import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
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
  bool _isLoading = false;
  bool _teamCreated = false;

  Future<void> _createTeamAndGetInviteUrl() async {
    setState(() => _isLoading = true);

    try {
      final data = ref.read(onboardingDataProvider);
      final teamName = data.teamName;
      final displayName = data.displayName;

      debugPrint('OnboardingData - displayName: "$displayName", teamName: "$teamName"');

      // 名前が空の場合は処理しない
      if (displayName.isEmpty || teamName.isEmpty) {
        debugPrint('Warning: displayName or teamName is empty!');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // プロフィールが存在することを確認（なければ作成）
      debugPrint('Step 1: ensureProfile...');
      await ref.read(profileRepositoryProvider).ensureProfile(displayName: displayName);

      // プロフィール名を更新
      debugPrint('Step 2: updateProfileWithName...');
      await ref.read(profileRepositoryProvider).updateProfileWithName(displayName);

      // 既にチームが存在するかチェック
      final existingProfile = await ref.read(myProfileProvider.future);
      String? familyId = existingProfile?.currentFamilyId;

      if (familyId == null) {
        // チームを作成
        debugPrint('Step 3: createFirstFamily...');
        await ref.read(familiesRepositoryProvider).createFirstFamily(teamName);

        // 少し待ってからプロフィールを取得（同期待ち）
        await Future.delayed(const Duration(milliseconds: 500));

        // 作成したチームのIDを取得
        debugPrint('Step 4: getting profile...');
        final profile = await ref.read(myProfileProvider.future);
        familyId = profile?.currentFamilyId;
      } else {
        debugPrint('Team already exists: $familyId');
      }
      debugPrint('Step 5: familyId = $familyId');

      if (familyId != null) {
        final url = await ref.read(familiesRepositoryProvider).createInviteUrl(familyId);
        debugPrint('Step 6: inviteUrl = $url');
        setState(() {
          _inviteUrl = url;
          _teamCreated = true;
        });
      } else {
        // familyIdがnullでもチーム作成は成功しているのでUIを更新
        debugPrint('familyId is null but team might be created');
        setState(() {
          _teamCreated = true;
        });
      }
    } catch (e, st) {
      debugPrint('Error in _createTeamAndGetInviteUrl: $e');
      debugPrint('Stack trace: $st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareInvite(BuildContext buttonContext) async {
    if (_inviteUrl == null) return;

    final data = ref.read(onboardingDataProvider);
    final box = buttonContext.findRenderObject() as RenderBox?;
    final screenSize = MediaQuery.of(context).size;

    // iPadでもエラーにならないようにデフォルト位置を設定
    final shareRect = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromCenter(
            center: Offset(screenSize.width / 2, screenSize.height / 2),
            width: 100,
            height: 100,
          );

    await Share.share(
      '買い物メモアプリで一緒にリストを共有しましょう！\n'
      'こちらのリンクから「${data.teamName}」に参加できます。\n\n'
      '$_inviteUrl',
      subject: 'チームへの招待',
      sharePositionOrigin: shareRect,
    );
  }

  Future<void> _copyToClipboard() async {
    if (_inviteUrl == null) return;

    await Clipboard.setData(ClipboardData(text: _inviteUrl!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('リンクをコピーしました')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // 初期化時にチームを作成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _createTeamAndGetInviteUrl();
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(onboardingDataProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            'チームメンバーを招待',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '「${data.teamName}」に家族やパートナーを招待しましょう',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          if (_isLoading)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('チームを作成中...'),
                ],
              ),
            )
          else if (_teamCreated) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      '「${data.teamName}」を作成しました',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Builder(builder: (buttonContext) {
              return ListTile(
                leading: const Icon(Icons.share),
                title: const Text('LINEやメールで招待'),
                subtitle: const Text('招待リンクを共有します'),
                onTap: () => _shareInvite(buttonContext),
                tileColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('リンクをコピー'),
              subtitle: const Text('クリップボードにコピーします'),
              onTap: _copyToClipboard,
              tileColor: Colors.grey.shade100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ],
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onBack,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('戻る', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _teamCreated ? widget.onNext : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _inviteUrl != null ? '通知設定へ' : 'スキップして通知設定へ',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
