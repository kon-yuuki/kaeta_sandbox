import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return boardAsync.when(
      skipLoadingOnReload: true,
      data: (board) {
        final message = board?.message ?? '';
        final hasMessage = message.isNotEmpty;

        return Card(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!hasMessage) ...[
                    Image.asset(
                      'assets/images/common/message-square-share.png',
                      width: 28,
                      height: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'ひとことを更新…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF3E506B),
                          fontSize: 46 / 3,
                          height: 1.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ] else ...[
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _BoardUpdaterAvatar(profile: updaterProfile),
                        if (isUnread)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${updaterName ?? '未設定'}  ${_formatDateTime(board!.updatedAt)}',
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                            style: const TextStyle(height: 1.0),
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
      return CircleAvatar(
        radius: 10,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
    if (hasPreset) {
      return CircleAvatar(
        radius: 10,
        backgroundImage: AssetImage(avatarPreset),
      );
    }
    return const CircleAvatar(
      radius: 10,
      backgroundColor: Color(0xFFF48A8A),
      child: Icon(Icons.person, size: 12, color: Colors.white),
    );
  }
}
