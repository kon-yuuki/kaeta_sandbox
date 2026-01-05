import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../database/database.dart';
import './global_provider.dart';
import '../repositories/todo_repository.dart';
import './profiles_provider.dart';

part 'todo_provider.g.dart';


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

final todoSearchQueryProvider = StateProvider<String>((ref) => '');

// todo_provider.dart

@riverpod
Stream<List<TodoItem>> todoList(Ref ref) {
  final repository = ref.watch(todoRepositoryProvider);
  final sortOrder = ref.watch(todoSortOrderProvider);
  final searchQuery = ref.watch(todoSearchQueryProvider);
  
  // 💡 AsyncValue（AsyncData, Loading, Errorを内包する型）を取得
  final profileAsync = ref.watch(myProfileProvider);

  // プロフィールが取得できるまで「待機」させる
  return profileAsync.when(
    data: (profile) {
      // プロフィールが届いたら、その familyId で取得開始
      return repository.watchUnCompleteItems(
        sortOrder,
        searchQuery,
        profile?.familyId ?? "",
      );
    },
    // プロフィール読み込み中は空のストリームを流す（loading状態で維持される）
    loading: () => const Stream.empty(),
    // エラー時は空のストリームを流す
    error: (err, stack) => const Stream.empty(),
  );
}