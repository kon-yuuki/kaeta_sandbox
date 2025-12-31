import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../database/database.dart';

class TodoRepository {
  final MyDatabase db;

  TodoRepository(this.db);

  // --- 1. 取得系 (Stream) ---

  // 未完了アイテムの取得（並び替え対応）
  Stream<List<TodoItem>> watchUnCompleteItems(TodoSortOrder order) {
    return (db.select(db.todoItems)
          ..where((t) => t.isCompleted.equals(false))
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

    // 1. ローカル (Drift) に保存
    await db.into(db.todoItems).insert(
      TodoItemsCompanion.insert(
        id: Value(id),
        name: title,
        priority: Value(priority),
        createdAt: Value(DateTime.now()),
      ),
    );

    // 2. クラウド (Supabase) に送信
    try {
      await Supabase.instance.client.from('todo_items').insert({
        'id': id,
        'name': title,
        'priority': priority,
        'is_completed': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Supabaseへの追加に失敗しました（オフラインの可能性があります）: $e');
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
  Future<void> completeItem(TodoItem item) async {
    await db.transaction(() async {
      // 1. Todoを完了状態にする
      await (db.update(db.todoItems)..where((t) => t.id.equals(item.id))).write(
        const TodoItemsCompanion(isCompleted: Value(true)),
      );

      // 2. 購入履歴へ保存（同じ名前があればカウントアップ）
      await db.into(db.purchaseHistory).insert(
            PurchaseHistoryCompanion.insert(
              id: Value(const Uuid().v4()),
              name: item.name,
              purchaseCount: const Value(1),
              lastPurchasedAt: DateTime.now(),
            ),
            onConflict: DoUpdate(
              (old) => PurchaseHistoryCompanion.custom(
                purchaseCount: old.purchaseCount + const Constant(1),
                lastPurchasedAt: Constant(DateTime.now()),
              ),
              target: [db.purchaseHistory.name],
            ),
          );
    });
  }

  // アイテム名の更新
  Future<void> updateItemName(TodoItem item, String newName, int priority) async {
    await (db.update(db.todoItems)..where((t) => t.id.equals(item.id))).write(
      TodoItemsCompanion(name: Value(newName), priority: Value(priority)),
    );
  }

  // --- 3. 手動同期系 (Supabase) ---

  Future<void> testFetchFromSupabase() async {
    final supabase = Supabase.instance.client;
    try {
      final List<Map<String, dynamic>> data = await supabase.from('todo_items').select();

      for (var row in data) {
        await db.into(db.todoItems).insertOnConflictUpdate(
          TodoItemsCompanion.insert(
            id: Value(row['id']),
            name: row['name'],
            priority: Value(row['priority'] ?? 0),
            isCompleted: Value(row['is_completed'] ?? false),
          ),
        );
      }
      print('手動同期が完了しました！');
    } catch (e) {
      print('同期エラー: $e');
    }
  }
}