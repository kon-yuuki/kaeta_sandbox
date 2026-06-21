import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../data/providers/board_provider.dart';
import '../../../data/providers/notifications_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_alert_dialog.dart';
import '../../../core/widgets/app_bottom_action_sheet.dart';
import '../../../core/widgets/app_bottom_sheet_header.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'todo_editor_app_bar.dart';
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
    var shouldReopen = true;

    while (context.mounted && shouldReopen) {
      shouldReopen = false;
      final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: false,
        backgroundColor: Colors.white,
        builder: (modalContext) {
          return StatefulBuilder(
            builder: (dialogContext, setModalState) {
              final bottomInset = MediaQuery.of(dialogContext).viewInsets.bottom;
              final modalColors = AppColors.of(dialogContext);
              final modalTypography = AppTypography.of(dialogContext);
              final trimmedCurrentMessage = currentMessage.trim();
              final trimmedText = _updateController.text.trim();
              final canSubmit =
                  trimmedText.isNotEmpty &&
                  trimmedText != trimmedCurrentMessage;

              Future<void> requestCloseWithConfirm() async {
                if (trimmedText == trimmedCurrentMessage) {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop('discard');
                  }
                  return;
                }
                final shouldDiscard = await showDiscardChangesConfirmDialog(
                  context: dialogContext,
                );
                if (shouldDiscard && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop('discard');
                }
              }

              Future<void> submit() async {
                final familyId = ref.read(selectedFamilyIdProvider);
                final profile = ref.read(myProfileProvider).valueOrNull;
                final actorName =
                    profile?.displayName?.trim().isNotEmpty == true
                    ? profile!.displayName!.trim()
                    : 'メンバー';
                final nextMessage = trimmedText;
                final hasChanged = nextMessage != trimmedCurrentMessage;

                debugPrint(
                  'F12 board update: familyId=$familyId, actorName=$actorName, hasChanged=$hasChanged, current="$trimmedCurrentMessage", next="$nextMessage"',
                );

                await ref.read(boardRepositoryProvider).upsertBoard(
                  familyId: familyId,
                  message: nextMessage,
                );

                debugPrint(
                  'F12 board upsert completed: familyId=$familyId, next="$nextMessage"',
                );

                if (hasChanged && familyId != null && familyId.isNotEmpty) {
                  debugPrint(
                    'F12 board notify start: familyId=$familyId, actorName=$actorName',
                  );
                  await ref
                      .read(notificationsRepositoryProvider)
                      .notifyBoardUpdated(
                        actorName: actorName,
                        boardMessage: nextMessage,
                        familyId: familyId,
                      );
                  debugPrint(
                    'F12 board notify completed: familyId=$familyId',
                  );
                } else {
                  debugPrint(
                    'F12 board notify skipped: hasChanged=$hasChanged, familyId=$familyId',
                  );
                }
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(nextMessage);
              }

              return Container(
                decoration: BoxDecoration(
                  color: modalColors.surfaceHighOnInverse,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SizedBox(
                  height: MediaQuery.sizeOf(dialogContext).height * 0.72,
                  child: Column(
                    children: [
                      AppBottomSheetHeader(
                        title: 'ひとこと掲示板を更新',
                        onBack: requestCloseWithConfirm,
                        trailing: AppBottomSheetSaveButton(
                          enabled: canSubmit,
                          label: '保存',
                          onPressed: submit,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            24,
                            16,
                            24 + bottomInset,
                          ),
                          child: TextField(
                            controller: _updateController,
                            maxLength: 200,
                            maxLengthEnforcement: MaxLengthEnforcement.none,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            onChanged: (_) => setModalState(() {}),
                            decoration: InputDecoration(
                              hintText: '伝えておきたいひとこと...',
                              hintStyle: modalTypography.std16R160.copyWith(
                                color: modalColors.textMedium,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              counterText: '',
                            ),
                            style: modalTypography.std16R160.copyWith(
                              color: modalColors.textHigh,
                            ),
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

      if (result == 'discard') {
        break;
      }

      if (result != null) {
        break;
      }

      if (_updateController.text.trim() == currentMessage.trim()) {
        break;
      }

      if (!context.mounted) break;
      final shouldDiscard = await showDiscardChangesConfirmDialog(
        context: context,
      );
      if (!context.mounted) break;
      if (!shouldDiscard) {
        shouldReopen = true;
      }
    }
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
      appBar: const TodoEditorAppBar(
        title: 'ひとこと掲示板',
        showFamilyToggle: false,
      ),
      body: boardAsync.when(
        data: (board) {
          final typography = Theme.of(context).extension<AppTypography>()!;
          final updaterNameStyle = typography.jaOnl12B100.copyWith(
            color: colors.textHigh,
          );
          final updatedTimeStyle = typography.egOnl12M140.copyWith(
            color: colors.textLow,
            height: 1.0,
          );
          final messageStyle = typography.std16R175.copyWith(
            color: colors.textHigh,
          );
          final message = board?.message ?? '';
          final hasMessage = message.trim().isNotEmpty;
          final updatedAt = board?.updatedAt;
          final canReset = hasMessage;

          if (!hasMessage) {
            return Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 100, 16, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/comment/img-CommentView.png',
                          width: 121,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '掲示板は未記入です',
                          style: typography.std18R160.copyWith(
                            color: colors.textHigh,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'いまの目次・予定の状況など\n伝えておきたいことを自由に残せます',
                          textAlign: TextAlign.center,
                          style: typography.std14R160.copyWith(
                            color: colors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: colors.surfaceHighOnInverse,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
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
                          _BoardUpdaterAvatar(profile: updaterProfile),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: Text(
                                    updaterName ?? '未設定',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textHeightBehavior:
                                        const TextHeightBehavior(
                                          applyHeightToFirstAscent: false,
                                          applyHeightToLastDescent: false,
                                        ),
                                    style: updaterNameStyle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (updatedAt != null)
                                  Text(
                                    _formatDateTime(updatedAt),
                                    textHeightBehavior:
                                        const TextHeightBehavior(
                                          applyHeightToFirstAscent: false,
                                          applyHeightToLastDescent: false,
                                        ),
                                    style: updatedTimeStyle,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 0),
                      Padding(
                        padding: const EdgeInsets.only(left: 36),
                        child: Transform.translate(
                          offset: const Offset(0, -8),
                          child: Text(
                            message,
                            style: messageStyle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AppBottomActionSheet(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/circle-alert.svg',
                            width: 15,
                            height: 15,
                            colorFilter: ColorFilter.mode(
                              colors.alert,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'リセットすると前の内容は削除されます',
                            style: typography.jaOnl11M100.copyWith(
                              color: colors.textMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          variant: AppButtonVariant.outlined,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(60),
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
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(60),
                          ),
                          onPressed: canReset
                              ? () async {
                                  final shouldReset = await showAppConfirmDialog(
                                    context: context,
                                    title: '最新の掲示板をリセット',
                                    message: 'リセットしてよろしいですか？',
                                    confirmLabel: 'リセットする',
                                    cancelLabel: 'キャンセル',
                                  );
                                  if (!shouldReset) return;
                                  await ref.read(boardRepositoryProvider).upsertBoard(
                                        familyId: ref.read(selectedFamilyIdProvider),
                                        message: '',
                                      );
                                }
                              : null,
                          child: const Text(
                            'リセットする',
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

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
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
