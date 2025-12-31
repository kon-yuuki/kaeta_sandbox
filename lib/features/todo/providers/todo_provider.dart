import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../database/database.dart';
import '../repositories/todo_repository.dart';

part 'todo_provider.g.dart';

/// 1. データベースのインスタンスを提供する Provider
/// PowerSync を使わない場合は、ここで直接 MyDatabase を生成して返せます。
@riverpod
MyDatabase database(Ref ref) {
  // 💡 直接インスタンスを作成して返します
  final db = MyDatabase();
  
  // アプリ終了時に適切に DB を閉じるための処理
  ref.onDispose(() => db.close());
  
  return db;
}

/// 2. Repository（窓口）を提供する Provider
@riverpod
TodoRepository todoRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  return TodoRepository(db);
}

/// 3. 並び替え順を管理する Provider
final todoSortOrderProvider = StateProvider<TodoSortOrder>((ref) {
  return TodoSortOrder.createdAt;
});