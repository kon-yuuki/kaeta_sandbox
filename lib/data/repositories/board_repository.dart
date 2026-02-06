import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../model/database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BoardRepository {
  final MyDatabase db;
  BoardRepository(this.db);

  /// 現在のモードに応じた掲示板を監視
  /// familyId != null → 家族ボード、null → 個人ボード
  Stream<FamilyBoard?> watchBoard(String? familyId) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return Stream.value(null);

    if (familyId != null && familyId.isNotEmpty) {
      return (db.select(db.familyBoards)
            ..where((t) => t.familyId.equals(familyId)))
          .watchSingleOrNull();
    } else {
      return (db.select(db.familyBoards)
            ..where((t) => t.userId.equals(userId) & t.familyId.isNull()))
          .watchSingleOrNull();
    }
  }

  /// 掲示板のメッセージを更新（なければ作成）
  Future<void> upsertBoard({
    required String? familyId,
    required String message,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final now = DateTime.now();

    // 既存のボードを探す
    FamilyBoard? existing;
    if (familyId != null && familyId.isNotEmpty) {
      existing = await (db.select(db.familyBoards)
            ..where((t) => t.familyId.equals(familyId)))
          .getSingleOrNull();
    } else {
      existing = await (db.select(db.familyBoards)
            ..where((t) => t.userId.equals(userId) & t.familyId.isNull()))
          .getSingleOrNull();
    }

    if (existing != null) {
      await (db.update(db.familyBoards)
            ..where((t) => t.id.equals(existing!.id)))
          .write(FamilyBoardsCompanion(
        message: Value(message),
        updatedBy: Value(userId),
        updatedAt: Value(now),
      ));
    } else {
      await db.into(db.familyBoards).insert(
        FamilyBoardsCompanion.insert(
          id: Value(const Uuid().v4()),
          familyId: Value(familyId),
          userId: Value(userId),
          message: Value(message),
          updatedBy: Value(userId),
          updatedAt: Value(now),
        ),
      );
    }
  }
}
