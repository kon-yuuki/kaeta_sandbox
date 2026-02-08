import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/common_app_bar.dart';
import '../../../core/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/model/database.dart' as db_model;
import '../../../data/providers/families_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../../data/repositories/families_repository.dart';
import '../../../main.dart';
import '../../home/widgets/home_bottom_nav_bar.dart';
import '../../login/view/login_screen.dart';
import '../../dev/components_catalog_screen.dart';
import 'family_members_screen.dart';

class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({super.key});

  @override
  ConsumerState<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingPage> {
  static const int _maxLength = 15;
  late final TextEditingController familyNameController;

  @override
  void initState() {
    super.initState();
    familyNameController = TextEditingController();
    ref.read(profileRepositoryProvider).ensureProfile();
  }

  @override
  void dispose() {
    familyNameController.dispose();
    super.dispose();
  }

  bool get _isGuest {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.isAnonymous ?? true;
  }

  String? _getLimitWarning(int currentLength) {
    if (currentLength >= _maxLength) {
      return '入力文字数は$_maxLength文字以内にしてください';
    }
    return null;
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
          AppButton(
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          AppButton(
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
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : Rect.zero,
    );
  }

  Widget _buildFamilyAvatarRow(String familyId) {
    final repo = ref.read(familiesRepositoryProvider);
    return StreamBuilder<List<FamilyMemberWithProfile>>(
      stream: repo.watchFamilyMembers(familyId),
      builder: (context, snapshot) {
        final members = snapshot.data ?? const <FamilyMemberWithProfile>[];
        if (members.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('メンバーなし', style: TextStyle(color: Colors.black54)),
          );
        }
        return SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: members.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final m = members[index];
              final hasUrl = m.avatarUrl != null && m.avatarUrl!.isNotEmpty;
              final hasPreset =
                  m.avatarPreset != null && m.avatarPreset!.isNotEmpty;
              if (hasUrl) {
                return CircleAvatar(backgroundImage: NetworkImage(m.avatarUrl!));
              }
              if (hasPreset) {
                return CircleAvatar(backgroundImage: AssetImage(m.avatarPreset!));
              }
              return const CircleAvatar(child: Icon(Icons.person));
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final familiesAsync = ref.watch(joinedFamiliesProvider);
    final selectedFamilyId = ref.watch(selectedFamilyIdProvider);

    return Scaffold(
      appBar: const CommonAppBar(showBackButton: true, title: '設定'),
      body: familiesAsync.when(
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
          final inviteTarget = selectedFamily ?? (families.isNotEmpty ? families.first : null);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (families.isEmpty)
                  const Text(
                    '参加中の家族はありません',
                    style: TextStyle(color: Colors.black54),
                  )
                else
                  Column(
                    children: families.map((family) {
                      final isSelected = family.id == selectedFamilyId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              family.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: AppButton(
                                variant: AppButtonVariant.outlined,
                                isSelected: isSelected,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FamilyMembersScreen(
                                        familyId: family.id,
                                        familyName: family.name,
                                        ownerId: family.ownerId,
                                      ),
                                    ),
                                  );
                                },
                                child: _buildFamilyAvatarRow(family.id),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    variant: AppButtonVariant.outlined,
                    icon: const Icon(Icons.person_add_alt_1),
                    onPressed: () => _shareInvite(inviteTarget),
                    child: const Text('メンバーを招待'),
                  ),
                ),
                const SizedBox(height: 20),
                if (families.isEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    '家族を作る',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  AppTextField(
                    controller: familyNameController,
                    maxLength: _maxLength,
                    label: '家族名（例：マイホーム）',
                    hintText: '名前を入力してください',
                    errorText: _getLimitWarning(familyNameController.text.length),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    onPressed: _getLimitWarning(familyNameController.text.length) !=
                            null
                        ? null
                        : () async {
                            if (_isGuest) {
                              _showLoginRequiredDialog();
                              return;
                            }
                            final familyName = familyNameController.text.trim();
                            if (familyName.isEmpty) return;
                            final created = await ref
                                .read(familiesRepositoryProvider)
                                .createFirstFamily(familyName);
                            if (!mounted) return;
                            if (created) {
                              familyNameController.clear();
                              setState(() {});
                              showTopSnackBar(context, '家族「$familyName」を作成しました');
                            } else {
                              showTopSnackBar(context, '家族の作成に失敗しました');
                            }
                          },
                    child: const Text('家族を作成'),
                  ),
                ],
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    variant: AppButtonVariant.outlined,
                    icon: const Icon(Icons.logout),
                    onPressed: _logout,
                    child: const Text('ログアウト'),
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      variant: AppButtonVariant.outlined,
                      icon: const Icon(Icons.widgets_outlined),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ComponentsCatalogScreen(),
                          ),
                        );
                      },
                      child: const Text('コンポーネント一覧'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('読み込みエラー: $e')),
      ),
      bottomNavigationBar: const HomeBottomNavBar(currentIndex: 1),
    );
  }
}
