import 'package:drift/drift.dart';
import '../model/database.dart';

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
  Future<void> updateCategoryName({
    required String id, 
    required String newName
    }) async {
    await db.transaction(() async {
      // 1. カテゴリ本体を更新
      await (db.update(db.categories)..where((t) => t.id.equals(id))).write(
        CategoriesCompanion(name: Value(newName)),
      );

      // 2. スナップショット列（表示名）も同期してズレを防ぐ
      await (db.update(db.items)..where((t) => t.categoryId.equals(id))).write(
        ItemsCompanion(category: Value(newName)),
      );
      await (db.update(db.todoItems)..where((t) => t.categoryId.equals(id))).write(
        TodoItemsCompanion(category: Value(newName)),
      );
    });
  }

  // 削除：特定のカテゴリを消す
  Future<void> deleteCategory(String id) async {
    // 💡 transactionで囲むことで、一連の処理を一つの塊として実行します
    await db.transaction(() async {
      // 1. itemsテーブルの関連カテゴリを解除
      await (db.update(db.items)..where((t) => t.categoryId.equals(id)))
          .write(const ItemsCompanion(
        categoryId: Value(null),
        category: Value('指定なし'),
      ));

      // 2. todoItemsテーブルの関連カテゴリを解除
      await (db.update(db.todoItems)..where((t) => t.categoryId.equals(id)))
          .write(const TodoItemsCompanion(
        categoryId: Value(null),
        category: Value('指定なし'),
      ));

      // 3. 最後にカテゴリ本体を削除
      await (db.delete(db.categories)..where((t) => t.id.equals(id))).go();
    });
  }
}
