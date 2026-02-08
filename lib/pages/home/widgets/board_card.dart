import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
              padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.campaign, color: Colors.orange, size: 20),
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
                              board != null && hasMessage
                                  ? '${updaterName ?? '未設定'}  ${_formatDateTime(board.updatedAt)}'
                                  : 'タップして一言メモを書く',
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
                            hasMessage
                                ? Text(
                                    message,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textHeightBehavior: const TextHeightBehavior(
                                      applyHeightToFirstAscent: false,
                                      applyHeightToLastDescent: false,
                                    ),
                                    style: const TextStyle(height: 1.0),
                                  )
                                : Text(
                                    'メッセージはまだありません',
                                    textHeightBehavior: const TextHeightBehavior(
                                      applyHeightToFirstAscent: false,
                                      applyHeightToLastDescent: false,
                                    ),
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      height: 1.0,
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
