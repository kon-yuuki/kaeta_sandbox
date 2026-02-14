import 'package:drift/drift.dart';
import '../model/database.dart';

class CategoryLimitExceededException implements Exception {
  const CategoryLimitExceededException(this.limit);

  final int limit;

  @override
  String toString() => 'カテゴリは最大$limit件までです';
}

class DuplicateCategoryNameException implements Exception {
  const DuplicateCategoryNameException(this.name);

  final String name;

  @override
  String toString() => 'カテゴリ「$name」は既に存在します';
}

class CategoryRepository {
  static const int freePlanCategoryLimit = 3;
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

  Future<Category> addCategory({
    required String name,
    required String userId,
    String? familyId,
  }) async {
    final normalizedFamilyId = (familyId != null && familyId.trim().isNotEmpty)
        ? familyId.trim()
        : null;

    final countExp = db.categories.id.count();
    final countQuery = db.selectOnly(db.categories)..addColumns([countExp]);
    if (normalizedFamilyId != null) {
      countQuery.where(db.categories.familyId.equals(normalizedFamilyId));
    } else {
      countQuery.where(
        db.categories.userId.equals(userId) & db.categories.familyId.isNull(),
      );
    }
    final existingCount = (await countQuery.getSingle()).read(countExp) ?? 0;
    if (existingCount >= freePlanCategoryLimit) {
      throw const CategoryLimitExceededException(freePlanCategoryLimit);
    }

    final duplicateExists = await _existsCategoryNameInScope(
      name: name,
      userId: userId,
      familyId: normalizedFamilyId,
    );
    if (duplicateExists) {
      throw DuplicateCategoryNameException(name.trim());
    }

    return db.into(db.categories).insertReturning(
      CategoriesCompanion.insert(
        name: name,
        userId: userId,
        familyId: Value(normalizedFamilyId),
      ),
    );
  }

  // 更新：名前を書き換える
  Future<void> updateCategoryName({
    required String id, 
    required String newName
    }) async {
    final target = await (db.select(
      db.categories,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (target == null) return;

    final duplicateExists = await _existsCategoryNameInScope(
      name: newName,
      userId: target.userId,
      familyId: target.familyId,
      excludingCategoryId: id,
    );
    if (duplicateExists) {
      throw DuplicateCategoryNameException(newName.trim());
    }

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

  Future<bool> _existsCategoryNameInScope({
    required String name,
    required String userId,
    String? familyId,
    String? excludingCategoryId,
  }) async {
    final normalizedFamilyId = (familyId != null && familyId.trim().isNotEmpty)
        ? familyId.trim()
        : null;
    final normalizedName = _normalizeCategoryName(name);

    final query = db.select(db.categories)
      ..where((t) {
        final sameScope = normalizedFamilyId != null
            ? t.familyId.equals(normalizedFamilyId)
            : t.userId.equals(userId) & t.familyId.isNull();
        if (excludingCategoryId != null && excludingCategoryId.isNotEmpty) {
          return sameScope & t.id.equals(excludingCategoryId).not();
        }
        return sameScope;
      });
    final scopedCategories = await query.get();

    return scopedCategories.any(
      (category) => _normalizeCategoryName(category.name) == normalizedName,
    );
  }

  String _normalizeCategoryName(String value) {
    return value.trim().toLowerCase();
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
