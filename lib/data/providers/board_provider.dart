import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/database.dart';
import '../repositories/board_repository.dart';
import 'global_provider.dart';
import 'profiles_provider.dart';

part 'board_provider.g.dart';

@riverpod
BoardRepository boardRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  return BoardRepository(db);
}

@riverpod
Stream<FamilyBoard?> currentBoard(Ref ref) {
  final repo = ref.watch(boardRepositoryProvider);
  final familyId = ref.watch(
    myProfileProvider.select((p) => p.valueOrNull?.currentFamilyId),
  );

  return repo.watchBoard(familyId);
}

/// 掲示板が未読かどうかを判定するProvider
/// 条件: 家族モード && 自分以外が更新 && 最後に見た時刻より新しい
@riverpod
Future<bool> boardUnread(Ref ref) async {
  final board = ref.watch(currentBoardProvider).valueOrNull;
  if (board == null) return false;

  final currentUserId = Supabase.instance.client.auth.currentUser?.id;
  if (currentUserId == null) return false;

  // 個人ボードなら常に既読
  if (board.familyId == null) return false;

  // 自分が更新したなら既読
  if (board.updatedBy == currentUserId) return false;

  final prefs = await SharedPreferences.getInstance();
  final lastReadMs = prefs.getInt('board_last_read_${board.id}') ?? 0;
  final lastRead = DateTime.fromMillisecondsSinceEpoch(lastReadMs);

  return board.updatedAt.isAfter(lastRead);
}

/// 掲示板の最終編集者名を取得するProvider
@riverpod
Stream<String?> boardUpdaterName(Ref ref) {
  final board = ref.watch(currentBoardProvider).valueOrNull;
  if (board == null || board.updatedBy == null) return Stream.value(null);

  final db = ref.watch(databaseProvider);
  return (db.select(db.profiles)
        ..where((t) => t.id.equals(board.updatedBy!)))
      .watchSingleOrNull()
      .map((p) => p?.displayName);
}

/// 既読にする（詳細画面を開いた時に呼ぶ）
Future<void> markBoardAsRead(String boardId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(
    'board_last_read_$boardId',
    DateTime.now().millisecondsSinceEpoch,
  );
}
