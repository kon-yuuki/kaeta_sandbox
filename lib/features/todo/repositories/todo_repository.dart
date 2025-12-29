import 'package:drift/drift.dart';
import '../../../database/database.dart';

class TodoRepository {
  final MyDatabase db;

  TodoRepository(this.db);

  Stream<List<TodoItem>> watchCompleteItems() {
    return (db.select(db.todoItems)
          ..where((t) => t.isCompleted.equals(true))
          ..orderBy([
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Stream<List<TodoItem>> watchUnCompleteItems() {
    return (db.select(db.todoItems)
          ..where((t) => t.isCompleted.equals(false))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<void> addItem(String title) {
    return db.into(db.todoItems).insert(TodoItemsCompanion.insert(name: title));
  }

  Future<void> deleteItem(TodoItem item) {
    return (db.delete(db.todoItems)..where((t) => t.id.equals(item.id))).go();
  }

  // todo_repository.dart の中に追加してください
  Future<void> toggleItem(TodoItem item) async {
    // 💡 replace ではなく update + write を使うのが、実は一番安全でエラーが起きにくいです
    await (db.update(db.todoItems)..where((t) => t.id.equals(item.id))).write(
      TodoItemsCompanion(isCompleted: Value(!item.isCompleted)),
    );
  }

  Future<void> completeItem(TodoItem item) async {
    await db.transaction(() async {
      await (db.update(db.todoItems)..where((t) => t.id.equals(item.id))).write(
        const TodoItemsCompanion(isCompleted: Value(true)),
      );

      await db
          .into(db.purchaseHistory)
          .insert(
            PurchaseHistoryCompanion.insert(
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

  Stream<List<PurchaseHistoryData>> watchTopPurchaseHistory() {
    return (db.select(db.purchaseHistory)
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.purchaseCount,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(5))
        .watch();
  }

  Future<void> updateItemName(TodoItem item, String newName) async {
    await (db.update(db.todoItems)..where((t) => t.id.equals(item.id))).write(
      TodoItemsCompanion(name: Value(newName)),
    );
  }
}
