import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/board_provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/model/database.dart';
import '../../../data/providers/families_provider.dart';

class BoardDetailScreen extends ConsumerStatefulWidget {
  const BoardDetailScreen({super.key});

  @override
  ConsumerState<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends ConsumerState<BoardDetailScreen> {
  late final TextEditingController _updateController;

  @override
  void initState() {
    super.initState();
    _updateController = TextEditingController();
  }

  @override
  void dispose() {
    _updateController.dispose();
    super.dispose();
  }

  void _markAsRead() {
    final board = ref.read(currentBoardProvider).valueOrNull;
    if (board != null) {
      markBoardAsRead(board.id);
      ref.invalidate(boardUnreadProvider);
    }
  }

  Future<void> _openUpdateModal(String currentMessage) async {
    _updateController.text = currentMessage;
    var text = currentMessage;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (modalContext) {
        final modalColors = AppColors.of(modalContext);
        return StatefulBuilder(
          builder: (dialogContext, setModalState) {
            final bottomInset = MediaQuery.of(dialogContext).viewInsets.bottom;
            final canSubmit = text.trim().isNotEmpty;
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SizedBox(
                height: MediaQuery.sizeOf(dialogContext).height * 0.72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        const Expanded(
                          child: Text(
                            'ひとこと掲示板を更新',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    Divider(height: 1, color: modalColors.borderLow),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                        child: Column(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _updateController,
                                maxLength: 200,
                                maxLines: null,
                                expands: true,
                                textAlignVertical: TextAlignVertical.top,
                                onChanged: (value) => setModalState(() => text = value),
                                decoration: InputDecoration(
                                  hintText: '伝えておきたいひとこと...',
                                  hintStyle: TextStyle(
                                    color: modalColors.textMedium,
                                    fontSize: 28 / 2,
                                  ),
                                  border: InputBorder.none,
                                  counterText: '${text.length} / 200文字',
                                  counterStyle: TextStyle(
                                    color: modalColors.textAccentSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: TextStyle(
                                  color: modalColors.textHigh,
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: AppButton(
                                onPressed: canSubmit
                                    ? () async {
                                        await ref.read(boardRepositoryProvider).upsertBoard(
                                              familyId: ref.read(selectedFamilyIdProvider),
                                              message: text.trim(),
                                            );
                                        if (!dialogContext.mounted) return;
                                        Navigator.pop(dialogContext);
                                      }
                                    : null,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  backgroundColor: canSubmit
                                      ? modalColors.accentPrimary
                                      : modalColors.borderMedium,
                                ),
                                child: const Text(
                                  '更新する',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final boardAsync = ref.watch(currentBoardProvider);
    final updaterName = ref.watch(boardUpdaterNameProvider).valueOrNull;
    final updaterProfile = ref.watch(boardUpdaterProfileProvider).valueOrNull;

    // 画面表示時に既読にする
    ref.listen(currentBoardProvider, (prev, next) {
      final board = next.valueOrNull;
      if (board != null) _markAsRead();
    });
    // 初回表示時
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAsRead());

    return Scaffold(
      backgroundColor: colors.surfaceHighOnInverse,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 26),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'ひとこと掲示板',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: boardAsync.when(
        data: (board) {
          final message = board?.message ?? '';
          final hasMessage = message.trim().isNotEmpty;
          final updatedAt = board?.updatedAt;
          final canReset = hasMessage;

          if (!hasMessage) {
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/comment/img-CommentView.png',
                            width: 140,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '掲示板は未記入です',
                            style: TextStyle(
                              color: colors.textHigh,
                              fontSize: 34 / 2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'いまの目次・予定の状況など\n伝えておきたいことを自由に残せます',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textLow,
                              fontSize: 24 / 2,
                              fontWeight: FontWeight.w500,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.surfaceHighOnInverse,
                    border: Border(top: BorderSide(color: colors.borderLow)),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        variant: AppButtonVariant.outlined,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          side: BorderSide(color: colors.borderMedium),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          _openUpdateModal(message);
                        },
                        child: const Text(
                          '更新する',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: _BoardUpdaterAvatar(profile: updaterProfile),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Text(
                                  updaterName ?? 'みさき',
                                  style: TextStyle(
                                    color: colors.textHigh,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (updatedAt != null)
                                  Text(
                                    _formatTime(updatedAt),
                                    style: TextStyle(
                                      color: colors.textMedium,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: TextStyle(
                          color: colors.textHigh,
                          fontSize: 33 / 2,
                          fontWeight: FontWeight.w500,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.surfaceHighOnInverse,
                  border: Border(top: BorderSide(color: colors.borderLow)),
                ),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'リセットすると前の内容は削除されます',
                        style: TextStyle(
                          color: colors.textMedium,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          variant: AppButtonVariant.outlined,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            side: BorderSide(color: colors.borderMedium),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            _openUpdateModal(message);
                          },
                          child: const Text(
                            '編集する',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          tone: AppButtonTone.danger,
                          onPressed: canReset
                              ? () async {
                                  final shouldReset = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) {
                                      final dialogColors = AppColors.of(dialogContext);
                                      return Dialog(
                                        insetPadding: const EdgeInsets.symmetric(horizontal: 48),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '最新の掲示板をリセット',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: dialogColors.textHigh,
                                                  fontSize: 34 / 2,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'リセットしてよろしいですか？',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: dialogColors.textHigh,
                                                  fontSize: 28 / 2,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              SizedBox(
                                                width: double.infinity,
                                                child: AppButton(
                                                  onPressed: () => Navigator.pop(dialogContext, true),
                                                  style: FilledButton.styleFrom(
                                                    minimumSize: const Size.fromHeight(56),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(14),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'リセットする',
                                                    style: TextStyle(fontWeight: FontWeight.w700),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              AppButton(
                                                variant: AppButtonVariant.text,
                                                onPressed: () => Navigator.pop(dialogContext, false),
                                                child: const Text('キャンセル'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                  if (shouldReset != true) return;
                                  await ref.read(boardRepositoryProvider).upsertBoard(
                                        familyId: ref.read(selectedFamilyIdProvider),
                                        message: '',
                                      );
                                }
                              : null,
                          child: const Text(
                            'リセット',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _BoardUpdaterAvatar extends StatelessWidget {
  const _BoardUpdaterAvatar({required this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?.avatarUrl;
    final avatarPreset = profile?.avatarPreset;
    final hasUrl = avatarUrl != null && avatarUrl.isNotEmpty;
    final hasPreset = avatarPreset != null && avatarPreset.isNotEmpty;

    if (hasUrl) {
      return CircleAvatar(
        radius: 14,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
    if (hasPreset) {
      return CircleAvatar(
        radius: 14,
        backgroundImage: AssetImage(avatarPreset),
      );
    }
    return const CircleAvatar(
      radius: 14,
      backgroundColor: Color(0xFFF48A8A),
      child: Icon(Icons.person, size: 17, color: Colors.white),
    );
  }
}
