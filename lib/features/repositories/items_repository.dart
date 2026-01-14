import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../database/database.dart';

class ItemsRepository {
  final MyDatabase db;
  ItemsRepository(this.db);

  // 名前からアイテムを探し、なければ作成してIDを返す (Get or Create)
  Future<String> getOrCreateItemId({
    required String name,
    required String category,
    required String userId,
    String? familyId,
  }) async {
    // 1. 既存チェック（同じ家族内、または個人の同じ名前があるか）
    final query = db.select(db.items)..where((t) => t.name.equals(name));
    
    if (familyId != null && familyId.isNotEmpty) {
      query.where((t) => t.familyId.equals(familyId));
    } else {
      query.where((t) => t.userId.equals(userId) & t.familyId.isNull());
    }

    final existing = await query.getSingleOrNull();
    if (existing != null) return existing.id;

    // 2. なければ新規作成
    final id = const Uuid().v4();
    await db.into(db.items).insert(
          ItemsCompanion.insert(
            id: Value(id),
            name: name,
            category: category,
            reading: '', // 索引用の読み（空でもOK）
            userId: userId,
            familyId: Value(familyId),
          ),
        );
    return id;
  }
}