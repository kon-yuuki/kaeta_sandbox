import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../model/database.dart';
import "items_repository.dart";
import 'package:supabase_flutter/supabase_flutter.dart';

class TodoWithMaster {
  final TodoItem todo;
  final Item masterItem;

  TodoWithMaster({required this.todo, required this.masterItem});
}

class PurchaseWithMaster {
  final PurchaseHistoryData history;
  final Item masterItem;

  PurchaseWithMaster({required this.history, required this.masterItem});
}

class TodoRepository {
  final MyDatabase db;
  final ItemsRepository itemsRepo;

  TodoRepository(this.db, this.itemsRepo);

  // --- 1. 取得系 (Stream) ---

  // 未完了アイテムの取得（並び替え対応）
  // 未完了アイテムの取得（Itemsテーブルと結合 ＆ 検索・並び替え対応）
  Stream<List<TodoWithMaster>> watchUnCompleteItems(
    TodoSortOrder order,
    String query,
    String? familyId,
  ) {
    // 1. 結合クエリの作成 (todo_items と items を itemId でガッチャンコする)
    final joinedQuery = db.select(db.todoItems).join([
      innerJoin(db.items, db.items.id.equalsExp(db.todoItems.itemId)),
    ]);

    // 2. フィルタ条件（完了していない ＆ 自分の家族のもの）
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    joinedQuery.where(db.todoItems.isCompleted.equals(false));
    if (familyId != null && familyId.isNotEmpty) {
      // 家族IDがある場合：そのIDと一致するものを探す
      joinedQuery.where(db.todoItems.familyId.equals(familyId));
    } else {
      // 家族IDがない（個人利用）場合：familyId列がNULLのものを探す
      joinedQuery.where(
        db.todoItems.familyId.isNull() & 
        db.todoItems.userId.equals(currentUserId ?? '')
      );
    }

    // 3. 検索条件（キーワードがある場合）
    if (query.isNotEmpty) {
      // 💡 重要：名前はマスターテーブル(db.items)の方を見に行く
      joinedQuery.where(db.items.name.like('%$query%'));
    }

    // 4. 並び替え設定
    joinedQuery.orderBy([
      if (order == TodoSortOrder.priority)
        OrderingTerm(expression: db.todoItems.priority, mode: OrderingMode.desc)
      else
        OrderingTerm(
          expression: db.todoItems.createdAt,
          mode: OrderingMode.desc,
        ),
      // 第2ソート条件として作成日
      OrderingTerm(expression: db.todoItems.createdAt, mode: OrderingMode.desc),
    ]);

    // 5. 実行して結果を TodoWithMaster に詰め替える
    return joinedQuery.watch().map((rows) {
      return rows.map((row) {
        // row からそれぞれのテーブルのデータを取り出す
        final todo = row.readTable(db.todoItems);
        final master = row.readTable(db.items);

        // 新しく作った「セットの箱」に入れて返す
        return TodoWithMaster(todo: todo, masterItem: master);
      }).toList();
    });
  }


  Stream<List<PurchaseWithMaster>> watchTopPurchaseHistory(String? familyId) {
    final joinedQuery = db.select(db.purchaseHistory).join([
      innerJoin(db.items, db.items.id.equalsExp(db.purchaseHistory.itemId)),
    ]);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

   if (familyId == null || familyId.isEmpty) {
      joinedQuery.where(
        db.purchaseHistory.familyId.isNull() & 
        db.purchaseHistory.userId.equals(currentUserId ?? '')
      );
    } else {
      joinedQuery.where(db.purchaseHistory.familyId.equals(familyId));
    }

    joinedQuery.orderBy([
      OrderingTerm(
        expression: db.items.purchaseCount,
        mode: OrderingMode.desc,
      ),
    ]);

    return joinedQuery.watch().map((rows) {
      return rows.map((row) {
        return PurchaseWithMaster(
          history: row.readTable(db.purchaseHistory),
          masterItem: row.readTable(db.items),
        );
      }).toList();
    });
  }

  // --- 2. 書き込み系 (Drift 標準機能) ---

  // アイテム追加
  Future<TodoItem?> addItem({
    required String name,
    required String category,
    required String? categoryId,
    required int priority,
    required String? familyId,
    required String reading,
    String? imageUrl,
  }
  ) async {
    try {
      final id = const Uuid().v4();
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId == null) {
        return null;
      }
      final itemId = await itemsRepo.getOrCreateItemId(
        name: name,
        category: category,
        categoryId: categoryId,
        userId: userId,
        familyId: familyId,
        reading: reading,
        imageUrl: imageUrl,
      );

      final checkItem = await (db.select(
        db.items,
      )..where((t) => t.id.equals(itemId))).getSingleOrNull();

      if (checkItem == null) {
        return null;
      }

      final now = DateTime.now();
      await db
          .into(db.todoItems)
          .insert(
            TodoItemsCompanion.insert(
              id: Value(id),
              itemId: Value(itemId),
              familyId: Value(familyId),
              name: name,
              category: category,
              categoryId: Value(categoryId),
              priority: Value(priority),
              createdAt: Value(now),
              userId: userId,
            ),
          );

      // PowerSyncのSQLiteテーブルにはDriftのDEFAULT句がないため
      // insertReturning/selectではnullエラーになる。直接構築する。
      return TodoItem(
        id: id,
        itemId: itemId,
        familyId: familyId,
        name: name,
        category: category,
        categoryId: categoryId,
        isCompleted: false,
        priority: priority,
        createdAt: now,
        userId: userId,
      );

    } catch (e, stack) {
      print('🚨 致命的なエラーが発生しました: $e');
      print('スタックトレース: $stack');
      return null;
    }
  }

  // アイテム削除
  Future<void> deleteItem(TodoItem item) async {
    await (db.delete(db.todoItems)..where((t) => t.id.equals(item.id))).go();
  }

 Future<void> completeItem(TodoItem item, String? familyId) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;

  if (item.itemId == null) {
    await (db.update(db.todoItems)..where((t) => t.id.equals(item.id))).write(
      const TodoItemsCompanion(isCompleted: Value(true)),
    );
    return;
  }

  await db.transaction(() async {
    // ① TodoItems を「完了」にする
    await (db.update(db.todoItems)..where((t) => t.id.equals(item.id))).write(
      const TodoItemsCompanion(isCompleted: Value(true)),
    );

    // ② Items(マスタ)のカウントアップ
    final masterItem = await (db.select(db.items)..where((t) => t.id.equals(item.itemId!))).getSingle();
    await (db.update(db.items)..where((t) => t.id.equals(item.itemId!))).write(
      ItemsCompanion(
        purchaseCount: Value((masterItem.purchaseCount ?? 0) + 1),
      ),
    );

    // ③ PurchaseHistory の更新 (UPSERT を使わず手動で行う)
    // まず、同じ名前の履歴があるか探す
    final existingHistory = await (db.select(db.purchaseHistory)
          ..where((t) => t.name.equals(item.name)))
        .getSingleOrNull();

    if (existingHistory != null) {
      // すでに履歴があれば UPDATE
      await (db.update(db.purchaseHistory)
            ..where((t) => t.id.equals(existingHistory.id)))
          .write(
        PurchaseHistoryCompanion(
          lastPurchasedAt: Value(DateTime.now()),
          itemId: Value(item.itemId),
          familyId: Value(familyId),
        ),
      );
    } else {
      // 履歴がなければ INSERT
      await db.into(db.purchaseHistory).insert(
        PurchaseHistoryCompanion.insert(
          id: Value(const Uuid().v4()), // 新しいID
          itemId: Value(item.itemId),
          familyId: Value(familyId),
          name: item.name,
          lastPurchasedAt: DateTime.now(),
          userId: userId,
        ),
      );
    }
  });
}

// アイテム名の更新
  Future<void> updateItemName(
    TodoItem item,
    String category,
    String? categoryId,
    String newName,
    int priority,
  ) async {

    await (db.update(db.todoItems)..where((t) => t.id.equals(item.id))).write(
      TodoItemsCompanion(
        name: Value(newName), 
        category: Value(category),
        categoryId: Value(categoryId),
        priority: Value(priority)
        ),
    );
    if (item.itemId != null) {
        await (db.update(db.items)..where((t) => t.id.equals(item.itemId!))).write(
          ItemsCompanion(
            name: Value(newName),
            category:Value(category),
            categoryId: Value(categoryId)),
        );
      }
  }
}
