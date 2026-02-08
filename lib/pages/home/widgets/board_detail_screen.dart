import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/board_provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/providers/families_provider.dart';

class BoardDetailScreen extends ConsumerStatefulWidget {
  const BoardDetailScreen({super.key});

  @override
  ConsumerState<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends ConsumerState<BoardDetailScreen> {
  late TextEditingController _controller;
  bool _isEditing = false;

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

  void _markAsRead() {
    final board = ref.read(currentBoardProvider).valueOrNull;
    if (board != null) {
      markBoardAsRead(board.id);
      ref.invalidate(boardUnreadProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final boardAsync = ref.watch(currentBoardProvider);
    final familyId = ref.watch(selectedFamilyIdProvider);

    // 画面表示時に既読にする
    ref.listen(currentBoardProvider, (prev, next) {
      final board = next.valueOrNull;
      if (board != null) _markAsRead();
    });
    // 初回表示時
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAsRead());

    return Scaffold(
      appBar: AppBar(
        title: Text(familyId != null ? '家族の伝言板' : '自分用メモ'),
      ),
      body: boardAsync.when(
        data: (board) {
          final message = board?.message ?? '';
          final updatedAt = board?.updatedAt;

          if (_isEditing) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      hintText: 'メッセージを入力…',
                      autofocus: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          variant: AppButtonVariant.outlined,
                          onPressed: () {
                            setState(() => _isEditing = false);
                          },
                          child: const Text('キャンセル'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          onPressed: () async {
                            await ref
                                .read(boardRepositoryProvider)
                                .upsertBoard(
                                  familyId: familyId,
                                  message: _controller.text,
                                );
                            if (mounted) {
                              setState(() => _isEditing = false);
                            }
                          },
                          child: const Text('保存'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (updatedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      '最終更新: ${_formatDateTime(updatedAt)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      message.isNotEmpty ? message : 'まだメッセージはありません',
                      style: TextStyle(
                        fontSize: 16,
                        color: message.isNotEmpty ? null : Colors.grey[500],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
      floatingActionButton: _isEditing
          ? null
          : FloatingActionButton(
              onPressed: () {
                final currentMessage =
                    boardAsync.valueOrNull?.message ?? '';
                _controller.text = currentMessage;
                setState(() => _isEditing = true);
              },
              child: const Icon(Icons.edit),
            ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
