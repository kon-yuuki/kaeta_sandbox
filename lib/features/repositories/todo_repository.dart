import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../database/database.dart';
import "./items_repository.dart";
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
    joinedQuery.where(db.todoItems.isCompleted.equals(false));
    if (familyId != null && familyId.isNotEmpty) {
      // 家族IDがある場合：そのIDと一致するものを探す
      joinedQuery.where(db.todoItems.familyId.equals(familyId));
    } else {
      // 家族IDがない（個人利用）場合：familyId列がNULLのものを探す
      joinedQuery.where(db.todoItems.familyId.isNull());
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

  // 購入履歴のトップ10取得
  // todo_repository.dart

  // 💡 戻り値の型を PurchaseWithMaster に変更
  // 購入履歴のトップ10取得
  Stream<List<PurchaseWithMaster>> watchTopPurchaseHistory(String? familyId) {
    // Itemsテーブルと結合
    final joinedQuery = db.select(db.purchaseHistory).join([
      innerJoin(db.items, db.items.id.equalsExp(db.purchaseHistory.itemId)),
    ]);

   if (familyId == null || familyId.isEmpty) {
      joinedQuery.where(db.purchaseHistory.familyId.isNull());
    } else {
      joinedQuery.where(db.purchaseHistory.familyId.equals(familyId));
    }

    joinedQuery.orderBy([
      OrderingTerm(
        expression: db.purchaseHistory.purchaseCount,
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
  Future<void> addItem(
    String title,
    String category,
    String? categoryId,
    int priority,
    String? familyId,
    String reading,
  ) async {
    try {
      final id = const Uuid().v4();
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId == null) {
        return;
      }
      final itemId = await itemsRepo.getOrCreateItemId(
        name: title,
        category: category,
        categoryId: categoryId,
        userId: userId,
        familyId: familyId,
        reading: reading,
      );

      // 💡 重要：ここで一度、Itemsテーブルに本当にそのIDがあるか「再確認」する
      final checkItem = await (db.select(
        db.items,
      )..where((t) => t.id.equals(itemId))).getSingleOrNull();

      if (checkItem == null) {
        return;
      }

      await db
          .into(db.todoItems)
          .insert(
            TodoItemsCompanion.insert(
              id: Value(id),
              itemId: Value(itemId),
              familyId: Value(familyId),
              name: title,
              category: category,
              categoryId: Value(categoryId),
              priority: Value(priority),
              createdAt: Value(DateTime.now()),
              userId: userId,
            ),
          );


    } catch (e, stack) {
      print('🚨 致命的なエラーが発生しました: $e');
      print('スタックトレース: $stack');
    }
  }

  // アイテム削除
  Future<void> deleteItem(TodoItem item) async {
    await (db.delete(db.todoItems)..where((t) => t.id.equals(item.id))).go();
  }

  // 完了状態の切り替え
  Future<void> toggleItem(TodoItem item) async {
    await (db.update(db.todoItems)..where((t) => t.id.equals(item.id))).write(
      TodoItemsCompanion(isCompleted: Value(!item.isCompleted)),
    );
  }

  // アイテムを完了し、履歴に反映させる
  // アイテムを完了し、履歴に反映させる
  Future<void> completeItem(TodoItem item, String? familyId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await db.transaction(() async {
      // ① TodoItems（買い物リスト）を「完了」にする
      await (db.update(db.todoItems)..where((t) => t.id.equals(item.id))).write(
        const TodoItemsCompanion(isCompleted: Value(true)),
      );

      // ② 履歴テーブルに「同じアイテム」が既にないか探す
      final query = db.select(db.purchaseHistory);

      if (item.itemId != null) {
        query.where((t) => t.itemId.equals(item.itemId!));
      } else {
        query.where((t) => t.name.equals(item.name));
      }

      final existing = await query.getSingleOrNull();

      if (existing != null) {
        // ③-A すでに履歴があれば、回数を +1 する
        await (db.update(
          db.purchaseHistory,
        )..where((t) => t.id.equals(existing.id))).write(
          PurchaseHistoryCompanion(
            purchaseCount: Value(existing.purchaseCount + 1),
            lastPurchasedAt: Value(DateTime.now()),
            itemId: Value(item.itemId),
          ),
        );
      } else {
        // ③-B まだ履歴に一度も登場していなければ、新しく作る
        await db
            .into(db.purchaseHistory)
            .insert(
              PurchaseHistoryCompanion.insert(
                id: Value(const Uuid().v4()),
                itemId: Value(item.itemId), // マスターIDを紐付け
                familyId: Value(familyId),
                name: item.name,
                purchaseCount: const Value(1),
                lastPurchasedAt: DateTime.now(),
                userId: userId,
              ),
            );
      }
    });
  }

  // アイテム名の更新
// アイテム名の更新
  Future<void> updateItemName(
    TodoItem item,
    String newName,
    int priority,
  ) async {

    await (db.update(db.todoItems)..where((t) => t.id.equals(item.id))).write(
      TodoItemsCompanion(name: Value(newName), priority: Value(priority)),
    );
    if (item.itemId != null) {
        await (db.update(db.items)..where((t) => t.id.equals(item.itemId!))).write(
          ItemsCompanion(name: Value(newName)),
        );
      }
  }
}
