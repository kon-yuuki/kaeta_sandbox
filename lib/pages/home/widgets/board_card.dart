import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/model/database.dart';
import '../../../data/providers/board_provider.dart';
import 'board_detail_screen.dart';

class BoardCard extends ConsumerWidget {
  const BoardCard({super.key});

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardAsync = ref.watch(currentBoardProvider);
    final isUnread = ref.watch(boardUnreadProvider).valueOrNull ?? false;
    final updaterName = ref.watch(boardUpdaterNameProvider).valueOrNull;
    final updaterProfile = ref.watch(boardUpdaterProfileProvider).valueOrNull;
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final emptyMessageStyle = typography.std14R160.copyWith(
      color: colors.textLow,
    );
    final updaterNameStyle = typography.jaOnl12B100.copyWith(
      color: colors.textHigh,
    );
    final updatedTimeStyle = typography.egOnl12M140.copyWith(
      color: colors.textLow,
      height: 1.0,
    );
    final messageStyle = typography.std14R160.copyWith(color: colors.textHigh);

    return boardAsync.when(
      skipLoadingOnReload: true,
      data: (board) {
        final message = board?.message ?? '';
        final hasMessage = message.isNotEmpty;

        return Card(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: hasMessage && isUnread
                ? BorderSide(color: colors.borderAccentPrimary, width: 2)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              if (board != null) {
                await markBoardAsRead(board.id);
                ref.invalidate(boardUnreadProvider);
              }
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BoardDetailScreen(),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hasMessage) ...[
                    Image.asset(
                      'assets/images/common/message-square-share.png',
                      width: 20,
                      height: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ひとことを更新…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: emptyMessageStyle,
                      ),
                    ),
                  ] else ...[
                    _BoardUpdaterAvatar(profile: updaterProfile),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Text(
                                  updaterName ?? '未設定',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textHeightBehavior: const TextHeightBehavior(
                                    applyHeightToFirstAscent: false,
                                    applyHeightToLastDescent: false,
                                  ),
                                  style: updaterNameStyle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDateTime(board!.updatedAt),
                                textHeightBehavior: const TextHeightBehavior(
                                  applyHeightToFirstAscent: false,
                                  applyHeightToLastDescent: false,
                                ),
                                style: updatedTimeStyle,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                            style: messageStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
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
      return CircleAvatar(radius: 16, backgroundImage: NetworkImage(avatarUrl));
    }
    if (hasPreset) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: AssetImage(avatarPreset),
      );
    }
    return const CircleAvatar(
      radius: 16,
      backgroundColor: Color(0xFFF48A8A),
      child: Icon(Icons.person, size: 18, color: Colors.white),
    );
  }
}
