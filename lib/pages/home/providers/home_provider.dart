import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/model/database.dart';
import '../../../data/providers/global_provider.dart';
import '../../../data/repositories/todo_repository.dart';
import '../../../data/providers/profiles_provider.dart';
import "../../../data/providers/items_provider.dart";
import '../view_models/home_view_model.dart';

part 'home_provider.g.dart';

/// 2. Repository（窓口）を提供する Provider
@riverpod
TodoRepository todoRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final itemsRepo = ref.watch(itemsRepositoryProvider);
  return TodoRepository(db, itemsRepo);
}

/// 3. 並び替え順を管理する Provider
final todoSortOrderProvider = StateProvider<TodoSortOrder>((ref) {
  return TodoSortOrder.createdAt;
});

final todoSearchQueryProvider = StateProvider<String>((ref) => '');

@riverpod
Stream<List<TodoWithMaster>> todoList(Ref ref) {
  final repository = ref.watch(todoRepositoryProvider);
  final sortOrder = ref.watch(todoSortOrderProvider);
  final searchQuery = ref.watch(todoSearchQueryProvider);

  // 💡 AsyncValue そのものではなく、.value で中身を watch する
  final profile = ref.watch(myProfileProvider).valueOrNull;

  // 💡 プロフィールがまだ無いなら、Provider自体を「読み込み中」で止める
  if (profile == null) {
    return const Stream.empty();
  }

  // プロフィールが届いてから、初めてリポジトリを監視しに行く
  return repository.watchUnCompleteItems(
    sortOrder,
    searchQuery,
    profile.currentFamilyId ?? "",
  );
}

@riverpod
Map<String, List<TodoWithMaster>> groupedTodoList(Ref ref) {
  final todoList = ref.watch(todoListProvider).valueOrNull ?? [];

  final Map<String, List<TodoWithMaster>> groups = {};

  for (final item in todoList) {
    final categoryName = item.masterItem.category;

    if (!groups.containsKey(categoryName)) {
      groups[categoryName] = [];
    }

    groups[categoryName]!.add(item);
  }

  return groups;
}

final homeViewModelProvider = Provider((ref) => HomeViewModel(ref));
