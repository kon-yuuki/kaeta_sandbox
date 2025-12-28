import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../database/database.dart';
import '../repositories/todo_repository.dart';

// これを書くことで、後で build_runner が Provider のコードを自動生成してくれます
part 'todo_provider.g.dart';

// 1. データベースのインスタンスを提供する Provider
// アプリ全体で一つのデータベースを使い回すための設定です
@riverpod
MyDatabase database(Ref ref) {
  return MyDatabase();
}

// 2. Repository（窓口）を提供する Provider
// 先ほど作った TodoRepository を、いつでも呼べるようにします
@riverpod
TodoRepository todoRepository(Ref ref) {
  // 上で作った database プロバイダーから DB のインスタンスを借りてきます
  final db = ref.watch(databaseProvider);
  return TodoRepository(db);
}