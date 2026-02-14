import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/common_app_bar.dart';
import '../../../core/snackbar_helper.dart';
import '../../../data/providers/families_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../../data/repositories/families_repository.dart';
import 'profile_edit_screen.dart';

class FamilyMembersScreen extends ConsumerStatefulWidget {
  const FamilyMembersScreen({
    super.key,
    required this.familyId,
    required this.familyName,
    required this.ownerId,
  });

  final String familyId;
  final String familyName;
  final String ownerId;

  @override
  ConsumerState<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends ConsumerState<FamilyMembersScreen> {
  late final TextEditingController _teamNameController;
  late String _initialTeamName;
  bool _isEditingTeamName = false;

  @override
  void initState() {
    super.initState();
    _initialTeamName = widget.familyName;
    _teamNameController = TextEditingController(text: widget.familyName);
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    super.dispose();
  }

  Future<void> _saveTeamName() async {
    final trimmed = _teamNameController.text.trim();
    if (trimmed.isEmpty || trimmed == _initialTeamName) {
      setState(() => _isEditingTeamName = false);
      return;
    }

    await ref.read(familiesRepositoryProvider).updateFamilyName(
          familyId: widget.familyId,
          newName: trimmed,
        );
    if (!mounted) return;
    setState(() {
      _initialTeamName = trimmed;
      _isEditingTeamName = false;
    });
    showTopSnackBar(context, 'チーム名を更新しました');
  }

  Future<void> _shareInvite() async {
    final info = await ref
        .read(familiesRepositoryProvider)
        .getInviteLinkInfo(widget.familyId);
    if (info == null || !mounted) return;
    final text = buildInviteShareText(
      groupName: _initialTeamName,
      inviteUrl: info.url,
      expiresAt: info.expiresAt,
      inviteId: info.inviteId,
      groupLabel: 'チーム',
    );
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      text,
      subject: 'チームへの招待',
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : Rect.zero,
    );
  }

  Future<void> _confirmDeleteTeam() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 44),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'チームを削除する',
                style: TextStyle(
                  color: Color(0xFF2C3844),
                  fontSize: 28 / 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '全メンバーがアクセスできなくなり、\n'
                'すべてのデータが失われます。あなた\n'
                'たのアカウントは残り、新しいチー\n'
                'ムを作成できます。\n'
                'この操作は取り消せません。よろし\n'
                'いですか？',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF2C3844),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2F3F52),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '削除する',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text(
                  'キャンセル',
                  style: TextStyle(
                    color: Color(0xFF2C3844),
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (ok != true) return;

    await ref.read(familiesRepositoryProvider).deleteFamily(widget.familyId);
    if (!mounted) return;
    showTopSnackBar(context, 'チームを削除しました');
    Navigator.pop(context);
  }

  Future<void> _confirmRemoveMember(FamilyMemberWithProfile member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 44),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'メンバーを退出させる',
                style: TextStyle(
                  color: Color(0xFF2C3844),
                  fontSize: 28 / 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'もう一度招待するまでメンバーは\n'
                'チームにアクセスできなくなります。\n'
                'この操作は取り消せません。よろし\n'
                'いですか？',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF2C3844),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2F3F52),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '退出させる',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text(
                  'キャンセル',
                  style: TextStyle(
                    color: Color(0xFF2C3844),
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (ok != true) return;

    await ref.read(familiesRepositoryProvider).removeMemberFromFamily(
          familyId: widget.familyId,
          memberUserId: member.userId,
        );
    if (!mounted) return;
    showTopSnackBar(context, 'メンバーを退出させました');
  }

  Widget _buildMemberAvatar(FamilyMemberWithProfile member) {
    final hasUrl = member.avatarUrl != null && member.avatarUrl!.isNotEmpty;
    final hasPreset =
        member.avatarPreset != null && member.avatarPreset!.isNotEmpty;
    if (hasUrl) {
      return CircleAvatar(radius: 16, backgroundImage: NetworkImage(member.avatarUrl!));
    }
    if (hasPreset) {
      return CircleAvatar(radius: 16, backgroundImage: AssetImage(member.avatarPreset!));
    }
    return const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18));
  }

  @override
  Widget build(BuildContext context) {
    final myProfile = ref.watch(myProfileProvider).value;
    final repo = ref.watch(familiesRepositoryProvider);
    final isOwnerUser = (Supabase.instance.client.auth.currentUser?.id ?? '') == widget.ownerId;

    return Scaffold(
      appBar: const CommonAppBar(showBackButton: true, title: 'チーム'),
      body: StreamBuilder<List<FamilyMemberWithProfile>>(
        stream: repo.watchFamilyMembers(widget.familyId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final members = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
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
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: _isEditingTeamName
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _teamNameController,
                              autofocus: true,
                              style: const TextStyle(
                                color: Color(0xFF2C3844),
                                fontSize: 24 / 2,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _saveTeamName,
                            icon: const Icon(Icons.check, color: Color(0xFF2ECCA1)),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              _initialTeamName,
                              style: const TextStyle(
                                color: Color(0xFF2C3844),
                                fontSize: 24 / 2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: isOwnerUser
                                ? () => setState(() => _isEditingTeamName = true)
                                : null,
                            icon: Icon(
                              Icons.edit_outlined,
                              color: isOwnerUser
                                  ? const Color(0xFF687A95)
                                  : const Color(0xFFB7C2D2),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'メンバー',
                  style: TextStyle(
                    color: Color(0xFF687A95),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < members.length; i++) ...[
                      _memberRow(
                        member: members[i],
                        isSelf: members[i].userId == myProfile?.id,
                        isOwner: members[i].userId == widget.ownerId,
                        canManage: isOwnerUser,
                      ),
                      if (i < members.length - 1)
                        const Divider(height: 1, color: Color(0xFFE6EBF2)),
                    ],
                    const Divider(height: 1, color: Color(0xFFE6EBF2)),
                    InkWell(
                      onTap: _shareInvite,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
              if (isOwnerUser) ...[
                const SizedBox(height: 34),
                Center(
                  child: TextButton(
                    onPressed: _confirmDeleteTeam,
                    child: const Text(
                      'チームを削除する',
                      style: TextStyle(
                        color: Color(0xFFCC2E59),
                        fontSize: 26 / 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _memberRow({
    required FamilyMemberWithProfile member,
    required bool isSelf,
    required bool isOwner,
    required bool canManage,
  }) {
    return InkWell(
      onTap: isSelf
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
              );
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _buildMemberAvatar(member),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName,
                    style: const TextStyle(
                      color: Color(0xFF2C3844),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isOwner)
                    const Text(
                      'オーナー',
                      style: TextStyle(
                        color: Color(0xFF687A95),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelf)
              const Icon(Icons.chevron_right, color: Color(0xFF687A95))
            else
              IconButton(
                onPressed: canManage
                    ? () => _confirmRemoveMember(member)
                    : null,
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: canManage
                      ? const Color(0xFF687A95)
                      : const Color(0xFFB7C2D2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
