import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/common_app_bar.dart';
import '../../../core/app_config.dart';
import '../../../core/snackbar_helper.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_alert_dialog.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/model/database.dart' as db_model;
import '../../../data/providers/billing_provider.dart';
import '../../../data/providers/families_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../../data/repositories/families_repository.dart';
import '../../../main.dart';
import '../../login/view/login_screen.dart';
import '../../onboarding/onboarding_flow.dart';
import '../../dev/components_catalog_screen.dart';
import '../../start/view/start_screen.dart';
import 'premium_plan_sheet.dart';
import 'notification_settings_screen.dart';
import 'family_members_screen.dart';
import 'profile_edit_screen.dart';

class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({super.key});

  @override
  ConsumerState<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingPage> {
  static final Uri _contactUri = Uri.parse(
    'https://www.notion.so/31026c0ce32580bf8342eaea3199b45d?source=copy_link',
  );

  bool get _showBillingDebugTools =>
      kDebugMode || AppConfig.enableBillingDebugTools;

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

  void _showLoginRequiredDialog() {
    showAppConfirmDialog(
      context: context,
      title: 'ログインが必要です',
      message: '家族機能を使うにはログインが必要です。',
      confirmLabel: 'ログインする',
      cancelLabel: 'キャンセル',
    ).then((ok) {
      if (!ok || !mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    });
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    await db.disconnectAndClear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const StartPage()),
    );
  }

  Future<void> _openInviteActions(db_model.Family? targetFamily) async {
    if (_isGuest) {
      _showLoginRequiredDialog();
      return;
    }
    if (targetFamily == null) {
      showTopSnackBar(context, '先に家族を作成してください');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => FamilyInviteActionsPage(
        familyId: targetFamily.id,
        familyName: targetFamily.name,
        showCreatedHeader: false,
        showAsSheet: true,
      ),
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

  Future<void> _showMemberLimitPremiumModal() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final typography = AppTypography.of(dialogContext);
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close),
                    color: const Color(0xFF5A6E89),
                    splashRadius: 20,
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/images/Tab_ItemCreate/img_Premium-lg.png',
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '3人以上のメンバー追加には\nプラン変更が必要です',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3B4A),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '変更で10人までメンバーを招待可能に◎\n履歴・カテゴリの上限アップ／広告非表示など\nの機能も充実します',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    color: Color(0xFF4A5A6D),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _showPremiumPlanModal();
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      backgroundColor: const Color(0xFF2ECCA1),
                      foregroundColor: Colors.white,
                      surfaceTintColor: const Color(0xFF2ECCA1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '1か月無料',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          'プレミアムプラン詳細 ↗',
                          textAlign: TextAlign.center,
                          style: typography.std14B160.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                AppButton(
                  variant: AppButtonVariant.text,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('閉じる'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPremiumPlanModal() async {
    await openPremiumPlanPage(context);
  }

  Future<void> _openContactPage() async {
    final opened = await launchUrl(
      _contactUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      showTopSnackBar(context, 'お問い合わせページを開けませんでした');
    }
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

  Widget _billingDebugTile({
    required BillingDebugOverride value,
    required BillingDebugOverride selectedValue,
    required String title,
    required String subtitle,
  }) {
    return RadioListTile<BillingDebugOverride>(
      value: value,
      groupValue: selectedValue,
      onChanged: (next) {
        if (next == null) return;
        ref.read(billingControllerProvider.notifier).setDebugOverride(next);
      },
      title: Text(title),
      subtitle: Text(subtitle),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      dense: true,
    );
  }

  Future<void> _purchaseDebugPackage(String packageIdentifier) async {
    final success = await ref
        .read(billingControllerProvider.notifier)
        .purchasePackageByIdentifier(packageIdentifier);
    if (!mounted) return;
    showTopSnackBar(
      context,
      success ? 'Test Store の $packageIdentifier を反映しました' : '購入処理を完了できませんでした',
    );
  }

  Future<void> _restoreDebugPurchases() async {
    final success = await ref
        .read(billingControllerProvider.notifier)
        .restore();
    if (!mounted) return;
    showTopSnackBar(context, success ? '購入情報を復元しました' : '復元できませんでした');
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
    final familyMembersAsync = ref.watch(familyMembersProvider);
    final profile = ref.watch(myProfileProvider).value;
    final billingState = ref.watch(billingControllerProvider);

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
          final memberCount = familyMembersAsync.valueOrNull?.length ?? 0;

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
                        subtitle: billingState.lifecycleLabel == null
                            ? billingState.planLabel
                            : '${billingState.planLabel}\n${billingState.lifecycleLabel}',
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
                            if (!billingState.hasPremium && memberCount >= 2) {
                              _showMemberLimitPremiumModal();
                              return;
                            }
                            _openInviteActions(selectedFamily);
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
                onTap: _showPremiumPlanModal,
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
              if (_showBillingDebugTools) ...[
                _sectionTitle('課金デバッグ'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _plainTile(
                        leading: const Icon(
                          Icons.bug_report_outlined,
                          color: Color(0xFF687A95),
                        ),
                        title: '現在の課金状態',
                        subtitle: billingState.lifecycleLabel == null
                            ? '${billingState.planLabel} / override: ${billingState.debugOverride.name}'
                            : '${billingState.planLabel}\n${billingState.lifecycleLabel} / override: ${billingState.debugOverride.name}',
                        onTap: () async {
                          await ref
                              .read(billingControllerProvider.notifier)
                              .refresh();
                        },
                        showDivider: true,
                        showChevron: false,
                      ),
                      _billingDebugTile(
                        value: BillingDebugOverride.system,
                        selectedValue: billingState.debugOverride,
                        title: 'system',
                        subtitle: 'RevenueCat の状態を使う',
                      ),
                      _billingDebugTile(
                        value: BillingDebugOverride.forceFree,
                        selectedValue: billingState.debugOverride,
                        title: 'forceFree',
                        subtitle: '未課金状態を強制する',
                      ),
                      _billingDebugTile(
                        value: BillingDebugOverride.forceExpired,
                        selectedValue: billingState.debugOverride,
                        title: 'forceExpired',
                        subtitle: '解約後の無料状態を強制する',
                      ),
                      _billingDebugTile(
                        value: BillingDebugOverride.forceBasic,
                        selectedValue: billingState.debugOverride,
                        title: 'forceBasic',
                        subtitle: 'ベーシック状態を強制する',
                      ),
                      _billingDebugTile(
                        value: BillingDebugOverride.forceBasicCanceling,
                        selectedValue: billingState.debugOverride,
                        title: 'forceBasicCanceling',
                        subtitle: 'ベーシック解約手続き中を強制する',
                      ),
                      _billingDebugTile(
                        value: BillingDebugOverride.forcePremium,
                        selectedValue: billingState.debugOverride,
                        title: 'forcePremium',
                        subtitle: 'プレミアム状態を強制する',
                      ),
                      _billingDebugTile(
                        value: BillingDebugOverride.forcePremiumCanceling,
                        selectedValue: billingState.debugOverride,
                        title: 'forcePremiumCanceling',
                        subtitle: 'プレミアム解約手続き中を強制する',
                      ),
                      _billingDebugTile(
                        value: BillingDebugOverride.forcePremiumTrial,
                        selectedValue: billingState.debugOverride,
                        title: 'forcePremiumTrial',
                        subtitle: 'プレミアム無料体験中を強制する',
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _showBillingDebugTools && !kDebugMode
                                  ? 'TestFlightデバッグ'
                                  : 'Test Store確認',
                              style: const TextStyle(
                                color: Color(0xFF2C3844),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              kDebugMode
                                  ? 'system を選んだ状態で使うと、RevenueCat の実状態を確認できます。'
                                  : 'TestFlight では override を使ってプラン状態を擬似切替できます。system は本物の課金接続確認用です。',
                              style: const TextStyle(
                                color: Color(0xFF687A95),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (kDebugMode)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton(
                                    onPressed: () =>
                                        _purchaseDebugPackage('basic'),
                                    child: const Text('basic を購入'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        _purchaseDebugPackage('premium'),
                                    child: const Text('premium を購入'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _restoreDebugPurchases,
                                    child: const Text('購入を復元'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () async {
                                      await ref
                                          .read(
                                            billingControllerProvider.notifier,
                                          )
                                          .refresh();
                                      if (!context.mounted) return;
                                      showTopSnackBar(context, '課金状態を再読込しました');
                                    },
                                    child: const Text('状態を再読込'),
                                  ),
                                ],
                              )
                            else
                              OutlinedButton(
                                onPressed: () async {
                                  await ref
                                      .read(billingControllerProvider.notifier)
                                      .refresh();
                                  if (!context.mounted) return;
                                  showTopSnackBar(context, '課金状態を再読込しました');
                                },
                                child: const Text('状態を再読込'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
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
                      showDivider: true,
                      onTap: () => showTopSnackBar(context, '準備中です'),
                    ),
                    _plainTile(
                      leading: const Icon(
                        Icons.support_agent_outlined,
                        color: Color(0xFF687A95),
                      ),
                      title: 'お問い合わせ',
                      onTap: _openContactPage,
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
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
                color: count > _maxLength
                    ? const Color(0xFFCC2E59)
                    : const Color(0xFF687A95),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
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
    this.showCreatedHeader = true,
    this.showAsSheet = false,
  });

  final String familyId;
  final String familyName;
  final bool showCreatedHeader;
  final bool showAsSheet;

  Future<String?> _buildInviteText(WidgetRef ref) async {
    final info = await ref
        .read(familiesRepositoryProvider)
        .getInviteLinkInfo(familyId, forceNew: true);
    if (info == null) return null;
    return buildInviteShareText(
      groupName: familyName,
      inviteUrl: info.url,
      expiresAt: info.expiresAt,
      inviteId: info.inviteId,
      groupLabel: '家族グループ',
    );
  }

  Future<void> _shareToLine(BuildContext context, WidgetRef ref) async {
    final text = await _buildInviteText(ref);
    if (text == null || !context.mounted) return;
    final uri = Uri.parse(
      'https://line.me/R/msg/text/?${Uri.encodeComponent(text)}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showTopSnackBar(context, 'LINEを開けませんでした');
    }
  }

  Future<void> _copyInviteLink(BuildContext context, WidgetRef ref) async {
    final info = await ref
        .read(familiesRepositoryProvider)
        .getInviteLinkInfo(familyId, forceNew: true);
    if (info == null || !context.mounted) return;
    await Clipboard.setData(ClipboardData(text: info.url));
    if (context.mounted) {
      showTopSnackBar(context, '招待リンクをコピーしました');
    }
  }

  Future<void> _shareByEmail(BuildContext context, WidgetRef ref) async {
    final text = await _buildInviteText(ref);
    if (text == null || !context.mounted) return;
    final uri = Uri(
      scheme: 'mailto',
      queryParameters: {'subject': '家族グループへの招待', 'body': text},
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showTopSnackBar(context, 'メールアプリを開けませんでした');
    }
  }

  Future<void> _shareOther(BuildContext context, WidgetRef ref) async {
    final text = await _buildInviteText(ref);
    if (text == null || !context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      text,
      subject: '家族グループへの招待',
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : Rect.zero,
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
                              child: Image.asset(
                                assetPath,
                                fit: BoxFit.contain,
                              ),
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
    final content = ListView(
      shrinkWrap: showAsSheet,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        if (showAsSheet) ...[
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.chevron_left, color: Color(0xFF4B5E72)),
              ),
              const Expanded(
                child: Text(
                  '家族を招待',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF2C3844),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const Divider(height: 1, color: Color(0xFFE6EBF2)),
          const SizedBox(height: 20),
        ],
        if (showCreatedHeader) ...[
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
        ],
        const Center(
          child: Text(
            '以下の方法で家族を招待できます',
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _actionRow(
                assetPath: 'assets/icons/LINE_Brand_icon.png',
                label: 'LINEで招待する',
                onTap: () => _shareToLine(context, ref),
                showIconBackground: false,
              ),
              _actionRow(
                icon: Icons.mail_outline,
                label: 'メールで招待する',
                onTap: () => _shareByEmail(context, ref),
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
        ),
      ],
    );

    if (showAsSheet) {
      final screenHeight = MediaQuery.of(context).size.height;
      final topGap = 60.0;
      return SafeArea(
        top: false,
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SizedBox(height: screenHeight - topGap, child: content),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(showBackButton: true, title: '家族を招待'),
      body: content,
    );
  }
}
