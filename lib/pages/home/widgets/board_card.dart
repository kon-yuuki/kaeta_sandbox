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

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Card(
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
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                          child: hasMessage
                              ? Text(
                                  message,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : Text(
                                  'タップして一言メモを書く',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                    if (hasMessage && board != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 28.0, top: 4.0),
                        child: Text(
                          '${updaterName ?? ''}  ${_formatDateTime(board.updatedAt)}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                      ),
                  ],
                ),
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
