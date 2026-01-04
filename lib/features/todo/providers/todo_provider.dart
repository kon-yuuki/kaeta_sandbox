import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../database/database.dart';
import 'package:powersync/powersync.dart';
import '../repositories/todo_repository.dart';
import '../../../main.dart';

part 'todo_provider.g.dart';

@riverpod
PowerSyncDatabase powerSync(Ref ref) {
  // main.dart で late final db = PowerSyncDatabase(...) と定義している前提です
  return db; 
}

/// 1. データベースのインスタンスを提供する Provider
/// PowerSync を使わない場合は、ここで直接 MyDatabase を生成して返せます。
// @riverpod
// MyDatabase database(Ref ref) {
//   final db = MyDatabase();
  
//   // アプリ終了時に適切に DB を閉じるための処理
//   ref.onDispose(() => db.close());
  
//   return db;
// }

@riverpod
MyDatabase database(Ref ref) {
  // 1. PowerSync のインスタンスを取得
  final psDb = ref.watch(powerSyncProvider);
  
  // 2. PowerSync を渡して MyDatabase を作成（これでエラーが消えます！）
  final driftDb = MyDatabase(psDb);
  
  // アプリ終了時に適切に DB を閉じる
  ref.onDispose(() => driftDb.close());
  
  return driftDb;
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