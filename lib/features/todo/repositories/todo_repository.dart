import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../database/database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TodoRepository {
  final MyDatabase db;

  TodoRepository(this.db);

  // --- 1. 取得系 (Stream) ---

  // 未完了アイテムの取得（並び替え対応）
  Stream<List<TodoItem>> watchUnCompleteItems(TodoSortOrder order,String query) {
    return (db.select(db.todoItems)
          ..where((t) => t.isCompleted.equals(false))
          ..where((t) {
            if (query.isEmpty) {
              return const Constant(true); // 検索ワードが空なら全件表示
            } else {
              // 💡 名前に query が含まれるものを部分一致検索
              return t.name.like('%$query%');
            }
          })
          ..orderBy([
            (t) {
              if (order == TodoSortOrder.priority) {
                return OrderingTerm(expression: t.priority, mode: OrderingMode.desc);
              } else {
                return OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc);
              }
            },
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  // 完了済みアイテムの取得
  Stream<List<TodoItem>> watchCompleteItems() {
    return (db.select(db.todoItems)
          ..where((t) => t.isCompleted.equals(true))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  // 購入履歴のトップ10取得
  Stream<List<PurchaseHistoryData>> watchTopPurchaseHistory() {
    return (db.select(db.purchaseHistory)
          ..orderBy([
            (t) => OrderingTerm(expression: t.purchaseCount, mode: OrderingMode.desc),
          ])
          ..limit(10))
        .watch();
  }

  // --- 2. 書き込み系 (Drift 標準機能) ---

  // アイテム追加
 // アイテム追加
  Future<void> addItem(String title, int priority) async {
    final id = const Uuid().v4(); // IDを事前に生成
    final userId = Supabase.instance.client.auth.currentUser?.id; // ID取得
    if (userId == null) return;

    // 1. ローカル (Drift) に保存
    await db.into(db.todoItems).insert(
      TodoItemsCompanion.insert(
        id: Value(id),
        name: title,
        priority: Value(priority),
        createdAt: Value(DateTime.now()),
        userId: userId,
      ),
    );
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
  Future<void> completeItem(TodoItem item) async {
    final userId = Supabase.instance.client.auth.currentUser?.id; // ID取得
    if (userId == null) return;
    await db.transaction(() async {
      // 1. Todoを完了状態にする
      await (db.update(db.todoItems)..where((t) => t.id.equals(item.id))).write(
        const TodoItemsCompanion(isCompleted: Value(true)),
      );

      // 2. 既存の履歴があるか名前で検索
      final existing = await (db.select(db.purchaseHistory)
            ..where((t) => t.name.equals(item.name)))
          .getSingleOrNull();

      if (existing != null) {
        // A. すでに履歴がある場合は「更新」
        await (db.update(db.purchaseHistory)
              ..where((t) => t.id.equals(existing.id)))
            .write(
          PurchaseHistoryCompanion(
            purchaseCount: Value(existing.purchaseCount + 1),
            lastPurchasedAt: Value(DateTime.now()),
          ),
        );
      } else {
        // B. まだ履歴がない場合は「新規挿入」
        await db.into(db.purchaseHistory).insert(
              PurchaseHistoryCompanion.insert(
                id: Value(const Uuid().v4()),
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
  Future<void> updateItemName(TodoItem item, String newName, int priority) async {
    await (db.update(db.todoItems)..where((t) => t.id.equals(item.id))).write(
      TodoItemsCompanion(name: Value(newName), priority: Value(priority)),
    );
  }

  // --- 3. 手動同期系 (Supabase) ---

  // Future<void> testFetchFromSupabase() async {
  //   final supabase = Supabase.instance.client;
  //   try {
  //     final List<Map<String, dynamic>> data = await supabase.from('todo_items').select();

  //     for (var row in data) {
  //       await db.into(db.todoItems).insertOnConflictUpdate(
  //         TodoItemsCompanion.insert(
  //           id: Value(row['id']),
  //           name: row['name'],
  //           priority: Value(row['priority'] ?? 0),
  //           isCompleted: Value(row['is_completed'] ?? false),
  //         ),
  //       );
  //     }
  //     print('手動同期が完了しました！');
  //   } catch (e) {
  //     print('同期エラー: $e');
  //   }
  // }
}