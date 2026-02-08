import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_heading.dart';
import '../../../core/widgets/app_list_item.dart';
import '../../../core/widgets/app_text_field.dart';
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
    if (trimmed.isEmpty || trimmed == _initialTeamName) return;

    await ref.read(familiesRepositoryProvider).updateFamilyName(
          familyId: widget.familyId,
          newName: trimmed,
        );
    if (!mounted) return;
    setState(() {
      _initialTeamName = trimmed;
    });
    showTopSnackBar(context, 'チーム名を更新しました');
  }

  Widget _buildMemberAvatar(FamilyMemberWithProfile member) {
    final hasUrl = member.avatarUrl != null && member.avatarUrl!.isNotEmpty;
    final hasPreset =
        member.avatarPreset != null && member.avatarPreset!.isNotEmpty;
    if (hasUrl) {
      return CircleAvatar(backgroundImage: NetworkImage(member.avatarUrl!));
    }
    if (hasPreset) {
      return CircleAvatar(backgroundImage: AssetImage(member.avatarPreset!));
    }
    return const CircleAvatar(child: Icon(Icons.person));
  }

  @override
  Widget build(BuildContext context) {
    final myProfile = ref.watch(myProfileProvider).value;
    final repo = ref.watch(familiesRepositoryProvider);
    final isNameChanged = _teamNameController.text.trim() != _initialTeamName;
    final canSaveName = _teamNameController.text.trim().isNotEmpty && isNameChanged;

    return Scaffold(
      appBar: AppBar(
        title: const Text('チーム'),
      ),
      body: StreamBuilder<List<FamilyMemberWithProfile>>(
        stream: repo.watchFamilyMembers(widget.familyId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final members = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const AppHeading('チーム名', type: AppHeadingType.secondary),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _teamNameController,
                      hintText: 'チーム名を入力',
                      heightType: AppTextFieldHeight.h56SingleLineEdit,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    onPressed: canSaveName ? _saveTeamName : null,
                    child: const Text('完了'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const AppHeading('メンバー', type: AppHeadingType.secondary),
              const SizedBox(height: 8),
              if (members.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('メンバーがいません'),
                )
              else
                ...members.map((member) {
                  final isSelf = member.userId == myProfile?.id;
                  final isOwner = member.userId == widget.ownerId;
                  return AppListItem(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 6,
                    ),
                    leading: _buildMemberAvatar(member),
                    title: Text(member.displayName),
                    subtitle: isOwner
                        ? const Text(
                            'オーナー',
                            style: TextStyle(fontSize: 12),
                          )
                        : null,
                    trailing: isSelf ? const Icon(Icons.chevron_right) : null,
                    onTap: isSelf
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProfileEditScreen(),
                              ),
                            );
                          }
                        : null,
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
