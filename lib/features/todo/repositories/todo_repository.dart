import 'package:drift/drift.dart';
import '../../../database/database.dart';

class TodoRepository {
  final MyDatabase db;

  TodoRepository(this.db);

  Stream<List<TodoItem>> watchAllItems() {
    return db.select(db.todoItems).watch();
  }

  Future<void> addItem(String title) {
    return db.into(db.todoItems).insert(TodoItemsCompanion.insert(name: title));
  }

  Future<void> deleteItem(TodoItem item) {
    return (db.delete(db.todoItems)..where((t) => t.id.equals(item.id))).go();
  }
}
