import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../database/database.dart';

class CategoryRepository {
  final MyDatabase db;
  CategoryRepository(this.db);

  Stream<List<Category>> watchCategories(String familyId, String userId) {
    final query = db.select(db.categories);

    query.where((t) {
      if (familyId.isNotEmpty) {
        return t.familyId.equals(familyId);
      } else {
        return t.userId.equals(userId) & t.familyId.isNull();
      }
    });

    return query.watch();
  }

  Future<void> addCategory({
    required String name,
    required String userId,
    String? familyId,
  }) async {
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name,
            userId: userId,
            familyId: Value(familyId),
          ),
        );
  }

  // 更新：名前を書き換える
Future<void> updateCategoryName(String id, String newName) async {
  await (db.update(db.categories)..where((t) => t.id.equals(id))).write(
    CategoriesCompanion(name: Value(newName)),
  );
}

// 削除：特定のカテゴリを消す
Future<void> deleteCategory(String id) async {
  await (db.delete(db.categories)..where((t) => t.id.equals(id))).go();
}
}
