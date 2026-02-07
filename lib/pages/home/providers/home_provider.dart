import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/model/database.dart';
import '../../../data/providers/global_provider.dart';
import '../../../data/repositories/todo_repository.dart';
import '../../../data/providers/profiles_provider.dart';
import "../../../data/providers/items_provider.dart";
import '../../../data/providers/category_provider.dart';
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

  // 💡 プロフィール全体ではなく currentFamilyId だけを監視して無駄なリビルドを防ぐ
  final familyId = ref.watch(
    myProfileProvider.select((p) => p.valueOrNull?.currentFamilyId),
  );

  // プロフィールが届いてから、初めてリポジトリを監視しに行く
  return repository.watchUnCompleteItems(
    sortOrder,
    searchQuery,
    familyId ?? "",
  );
}

@riverpod
Map<String, List<TodoWithMaster>> groupedTodoList(Ref ref) {
  final todoList = ref.watch(todoListProvider).valueOrNull ?? [];
  final categories = ref.watch(categoryListProvider).valueOrNull ?? [];
  final categoryNameById = <String, String>{
    for (final c in categories) c.id: c.name,
  };

  final Map<String, List<TodoWithMaster>> groups = {};

  for (final item in todoList) {
    final resolvedName = item.todo.categoryId != null
        ? categoryNameById[item.todo.categoryId!]
        : null;
    final categoryName = (resolvedName != null && resolvedName.isNotEmpty)
        ? resolvedName
        : (item.todo.category.isNotEmpty ? item.todo.category : '指定なし');

    if (!groups.containsKey(categoryName)) {
      groups[categoryName] = [];
    }

    groups[categoryName]!.add(item);
  }

  return groups;
}

final homeViewModelProvider = Provider((ref) => HomeViewModel(ref));

// AddSheetのドラフト状態を保持するProvider
final addSheetDraftNameProvider = StateProvider<String>((ref) => '');
final addSheetDraftPriorityProvider = StateProvider<int>((ref) => 0);
final addSheetDraftCategoryIdProvider = StateProvider<String?>((ref) => null);
final addSheetDraftCategoryNameProvider = StateProvider<String>((ref) => '指定なし');
final addSheetDraftBudgetMinAmountProvider = StateProvider<int>((ref) => 0);
final addSheetDraftBudgetMaxAmountProvider = StateProvider<int>((ref) => 0);
final addSheetDraftBudgetTypeProvider = StateProvider<int>((ref) => 0);
final addSheetDraftQuantityTextProvider = StateProvider<String?>((ref) => null);
final addSheetDraftQuantityUnitProvider = StateProvider<int?>((ref) => null);
final addSheetDiscardOnCloseProvider = StateProvider<bool>((ref) => false);

// 今日買ったアイテムの表示トグル
final showTodayCompletedProvider = StateProvider<bool>((ref) => false);

@riverpod
Stream<List<TodoWithMaster>> todayCompletedList(Ref ref) {
  final repository = ref.watch(todoRepositoryProvider);
  // currentFamilyId だけを監視して無駄なリビルドを防ぐ
  final familyId = ref.watch(
    myProfileProvider.select((p) => p.valueOrNull?.currentFamilyId),
  );

  return repository.watchTodayCompletedItems(
    familyId ?? "",
  );
}
