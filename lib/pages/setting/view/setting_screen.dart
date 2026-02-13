import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/common_app_bar.dart';
import '../../../core/snackbar_helper.dart';
import '../../../data/model/database.dart' as db_model;
import '../../../data/providers/families_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../../main.dart';
import '../../home/widgets/home_bottom_nav_bar.dart';
import '../../login/view/login_screen.dart';
import '../../onboarding/onboarding_flow.dart';
import '../../dev/components_catalog_screen.dart';
import 'notification_settings_screen.dart';
import 'family_members_screen.dart';
import 'profile_edit_screen.dart';

class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({super.key});

  @override
  ConsumerState<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingPage> {
  @override
  void initState() {
    super.initState();
    ref.read(profileRepositoryProvider).ensureProfile();
  }

  bool get _isGuest {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.isAnonymous ?? true;
  }

  String _loginStatusText() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return 'ゲスト利用中';

    final identities = user.identities;
    final provider =
        (user.appMetadata['provider'] as String?) ??
        (identities != null && identities.isNotEmpty
            ? identities.first.provider
            : null);

    switch (provider) {
      case 'google':
        return 'Googleアカウントでログイン中';
      case 'apple':
        return 'Appleアカウントでログイン中';
      case 'email':
        return 'メールアドレスでログイン中';
      default:
        return 'ログイン中';
    }
  }

  String _formatInviteExpiry(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.year}/${local.month}/${local.day} $hh:$mm';
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

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    await db.disconnectAndClear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  Future<void> _shareInvite(db_model.Family? targetFamily) async {
    if (_isGuest) {
      _showLoginRequiredDialog();
      return;
    }
    if (targetFamily == null) {
      showTopSnackBar(context, '先に家族を作成してください');
      return;
    }
    final info = await ref
        .read(familiesRepositoryProvider)
        .getInviteLinkInfo(targetFamily.id);
    if (info == null || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      '買い物メモアプリで一緒にリストを共有しましょう！\n'
      'こちらのリンクから家族グループ「${targetFamily.name}」に参加できます。\n\n'
      '${info.url}\n\n'
      '有効期限: ${_formatInviteExpiry(info.expiresAt)}',
      subject: '家族グループへの招待',
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : Rect.zero,
    );
  }

  Future<void> _openInviteFlowWhenNoFamily() async {
    if (_isGuest) {
      _showLoginRequiredDialog();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TeamNameSetupPage()),
    );
  }

  Widget _buildAvatar({
    String? avatarUrl,
    String? avatarPreset,
    double radius = 22,
  }) {
    final hasUrl = avatarUrl != null && avatarUrl.isNotEmpty;
    final hasPreset = avatarPreset != null && avatarPreset.isNotEmpty;
    if (hasUrl) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
    if (hasPreset) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: AssetImage(avatarPreset),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFFFD9D9),
      child: const Icon(Icons.person, color: Color(0xFF687A95)),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF687A95),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _plainTile({
    required Widget leading,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool showDivider = false,
    bool showChevron = true,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(
                  bottom: BorderSide(color: Color(0xFFE6EBF2), width: 1),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF2C3844),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF687A95),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            if (showChevron)
              const Icon(Icons.chevron_right, color: Color(0xFF9AA8BC)),
          ],
        ),
      ),
    );
  }

  Widget _guestRegisterTile() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingFlow()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: const Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ユーザー登録',
                    style: TextStyle(
                      color: Color(0xFF2C3844),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '3分で登録完了 / リスト共有ができるようになります',
                    style: TextStyle(
                      color: Color(0xFF687A95),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Color(0xFF9AA8BC)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final familiesAsync = ref.watch(joinedFamiliesProvider);
    final selectedFamilyId = ref.watch(selectedFamilyIdProvider);
    final profile = ref.watch(myProfileProvider).value;

    return Scaffold(
      appBar: const CommonAppBar(showBackButton: true, title: 'アカウント管理'),
      body: familiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('読み込みエラー: $e')),
        data: (families) {
          db_model.Family? selectedFamily;
          if (selectedFamilyId != null) {
            for (final family in families) {
              if (family.id == selectedFamilyId) {
                selectedFamily = family;
                break;
              }
            }
          }
          selectedFamily ??= families.isNotEmpty ? families.first : null;

          final profileName = profile?.displayName?.trim().isNotEmpty == true
              ? profile!.displayName!.trim()
              : 'ゲスト';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _plainTile(
                      leading: _buildAvatar(
                        avatarUrl: profile?.avatarUrl,
                        avatarPreset: profile?.avatarPreset,
                      ),
                      title: profileName,
                      subtitle: _loginStatusText(),
                      onTap: _isGuest
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ProfileEditScreen(),
                                ),
                              );
                            },
                      showDivider: true,
                      showChevron: !_isGuest,
                    ),
                    if (_isGuest)
                      _guestRegisterTile()
                    else if (selectedFamily != null)
                      _plainTile(
                        leading: const Icon(
                          Icons.groups,
                          color: Color(0xFF687A95),
                        ),
                        title: selectedFamily.name,
                        subtitle: '無料プラン',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FamilyMembersScreen(
                                familyId: selectedFamily!.id,
                                familyName: selectedFamily.name,
                                ownerId: selectedFamily.ownerId,
                              ),
                            ),
                          );
                        },
                        showDivider: true,
                      ),
                    if (!_isGuest)
                      InkWell(
                        onTap: () {
                          if (selectedFamily != null) {
                            _shareInvite(selectedFamily);
                          } else {
                            _openInviteFlowWhenNoFamily();
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.add, color: Color(0xFF2ECCA1)),
                              SizedBox(width: 12),
                              Text(
                                'メンバーを招待する',
                                style: TextStyle(
                                  color: Color(0xFF2C3844),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => showTopSnackBar(context, 'プレミアムプラン詳細は準備中です'),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/Tab_ItemCreate/add_item_premiere_banner.png',
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '月額500円 / オーナー1人の登録でみんなで使える',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF687A95),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle('リスト設定'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _plainTile(
                  leading: const Icon(
                    Icons.notifications_none,
                    color: Color(0xFF687A95),
                  ),
                  title: '通知設定',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle('アプリ情報'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _plainTile(
                      leading: const Icon(
                        Icons.help_outline,
                        color: Color(0xFF687A95),
                      ),
                      title: 'よくある質問',
                      onTap: () => showTopSnackBar(context, '準備中です'),
                      showDivider: true,
                    ),
                    _plainTile(
                      leading: const Icon(
                        Icons.event_note_outlined,
                        color: Color(0xFF687A95),
                      ),
                      title: '更新情報・今後のロードマップ',
                      onTap: () => showTopSnackBar(context, '準備中です'),
                      showDivider: true,
                    ),
                    _plainTile(
                      leading: const Icon(
                        Icons.dashboard_customize_outlined,
                        color: Color(0xFF687A95),
                      ),
                      title: 'コンポーネント一覧',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ComponentsCatalogScreen(),
                          ),
                        );
                      },
                      showDivider: true,
                    ),
                    _plainTile(
                      leading: const Icon(
                        Icons.privacy_tip_outlined,
                        color: Color(0xFF687A95),
                      ),
                      title: 'プライバシーポリシー',
                      onTap: () => showTopSnackBar(context, '準備中です'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: _logout,
                  icon: const Icon(
                    Icons.logout,
                    color: Color(0xFF687A95),
                    size: 18,
                  ),
                  label: const Text(
                    'ログアウト',
                    style: TextStyle(
                      color: Color(0xFF687A95),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const HomeBottomNavBar(currentIndex: 1),
    );
  }
}

class TeamNameSetupPage extends ConsumerStatefulWidget {
  const TeamNameSetupPage({super.key});

  @override
  ConsumerState<TeamNameSetupPage> createState() => _TeamNameSetupPageState();
}

class _TeamNameSetupPageState extends ConsumerState<TeamNameSetupPage> {
  static const int _maxLength = 15;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final teamName = _controller.text.trim();
    if (teamName.isEmpty || teamName.length > _maxLength) return;

    final repo = ref.read(familiesRepositoryProvider);
    final ok = await repo.createFirstFamily(teamName);
    if (!mounted) return;
    if (!ok) {
      showTopSnackBar(context, 'チーム作成に失敗しました');
      return;
    }

    final joined = await repo.watchJoinedFamilies().first;
    if (!mounted) return;
    if (joined.isEmpty) {
      showTopSnackBar(context, 'チーム情報の取得に失敗しました');
      return;
    }
    db_model.Family? created;
    for (final f in joined) {
      if (f.name == teamName) {
        created = f;
        break;
      }
    }
    created ??= joined.first;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FamilyInviteActionsPage(
          familyId: created!.id,
          familyName: created.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _controller.text.characters.length;
    final canSubmit = _controller.text.trim().isNotEmpty && count <= _maxLength;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(showBackButton: true, title: 'チーム名を設定'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Center(
            child: Text(
              '招待するチーム名を設定',
              style: TextStyle(
                color: Color(0xFF2C3844),
                fontSize: 20 / 2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              '招待された人へチーム名が表示されます',
              style: TextStyle(
                color: Color(0xFF687A95),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'チーム名',
              style: TextStyle(
                color: Color(0xFF687A95),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              '※必須',
              style: TextStyle(
                color: Color(0xFFCC2E59),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _controller,
            maxLength: _maxLength,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '○○チーム、○○家など',
              hintStyle: const TextStyle(color: Color(0xFF9AA8BC)),
              filled: true,
              fillColor: Colors.white,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE6EBF2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE6EBF2)),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$count / $_maxLength文字',
              style: TextStyle(
                color: count > _maxLength ? const Color(0xFFCC2E59) : const Color(0xFF687A95),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 420 / 2),
          FilledButton(
            onPressed: canSubmit ? _submit : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: canSubmit
                  ? const Color(0xFF2F3F52)
                  : const Color(0xFFB7C2D2),
              disabledBackgroundColor: const Color(0xFFB7C2D2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              '招待に進む',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FamilyInviteActionsPage extends ConsumerWidget {
  const FamilyInviteActionsPage({
    super.key,
    required this.familyId,
    required this.familyName,
  });

  final String familyId;
  final String familyName;

  String _formatInviteExpiry(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.year}/${local.month}/${local.day} $hh:$mm';
  }

  Future<String?> _buildInviteText(WidgetRef ref) async {
    final info = await ref.read(familiesRepositoryProvider).getInviteLinkInfo(familyId);
    if (info == null) return null;
    return '買い物メモアプリで一緒にリストを共有しましょう！\n'
        'こちらのリンクから家族グループ「$familyName」に参加できます。\n\n'
        '${info.url}\n\n'
        '有効期限: ${_formatInviteExpiry(info.expiresAt)}';
  }

  Future<void> _shareToLine(BuildContext context, WidgetRef ref) async {
    final text = await _buildInviteText(ref);
    if (text == null || !context.mounted) return;
    final uri = Uri.parse('https://line.me/R/msg/text/?${Uri.encodeComponent(text)}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showTopSnackBar(context, 'LINEを開けませんでした');
    }
  }

  Future<void> _copyInviteLink(BuildContext context, WidgetRef ref) async {
    final text = await _buildInviteText(ref);
    if (text == null || !context.mounted) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      showTopSnackBar(context, '招待リンクをコピーしました');
    }
  }

  Future<void> _shareOther(BuildContext context, WidgetRef ref) async {
    final text = await _buildInviteText(ref);
    if (text == null || !context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      text,
      subject: '家族グループへの招待',
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : Rect.zero,
    );
  }

  Widget _actionRow({
    IconData? icon,
    String? assetPath,
    required String label,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF2ECCA1),
    bool showIconBackground = true,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: showIconBackground
                  ? Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6F4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: assetPath != null
                          ? Padding(
                              padding: const EdgeInsets.all(6),
                              child: Image.asset(assetPath, fit: BoxFit.contain),
                            )
                          : Icon(icon, color: iconColor, size: 20),
                    )
                  : (assetPath != null
                        ? Padding(
                            padding: const EdgeInsets.all(2),
                            child: Image.asset(assetPath, fit: BoxFit.contain),
                          )
                        : Icon(icon, color: iconColor, size: 20)),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF2C3844),
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
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(showBackButton: true, title: '家族を招待'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6EBF2)),
            ),
            child: Column(
              children: [
                const Text(
                  'チームを作成しました',
                  style: TextStyle(
                    color: Color(0xFF2C3844),
                    fontSize: 20 / 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1EFEC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      familyName,
                      style: const TextStyle(
                        color: Color(0xFF2C3844),
                        fontSize: 18 / 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              '以下から家族を招待してください',
              style: TextStyle(
                color: Color(0xFF2C3844),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              '招待リンクから相手が参加すると\nメンバーに追加されます',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF687A95),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _actionRow(
            assetPath: 'assets/icons/LINE_Brand_icon.png',
            label: 'LINEで招待',
            onTap: () => _shareToLine(context, ref),
            showIconBackground: false,
          ),
          _actionRow(
            icon: Icons.link,
            label: '招待リンクをコピー',
            onTap: () => _copyInviteLink(context, ref),
          ),
          _actionRow(
            icon: Icons.ios_share,
            label: 'その他の共有',
            onTap: () => _shareOther(context, ref),
          ),
        ],
      ),
    );
  }
}
