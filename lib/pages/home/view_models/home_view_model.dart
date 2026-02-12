import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/model/database.dart';
import '../providers/home_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../../data/providers/notifications_provider.dart';
import 'package:image_picker/image_picker.dart';
import "../../../data/providers/items_provider.dart";
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeViewModel {
  final Ref ref;
  HomeViewModel(this.ref);

  

  Future<void> deleteTodo(TodoItem item) async {
    // Repositoryを取得して削除を実行する「だけ」の仕事
    final repository = ref.read(todoRepositoryProvider);
    await repository.deleteItem(item);
  }

  Future<({String message, bool allCompleted})> completeTodo(TodoItem item) async {
    final repository = ref.read(todoRepositoryProvider);
    final notificationsRepository = ref.read(notificationsRepositoryProvider);
    final profile = ref.read(myProfileProvider).value;
    final familyId = profile?.currentFamilyId;
    await repository.completeItem(item, familyId);
    await notificationsRepository.notifyShoppingCompleted(
      itemName: item.name,
      familyId: familyId,
    );
    final remaining = await repository.countUncompletedItems(familyId);
    return (
      message: '「${item.name}」を完了しました！',
      allCompleted: remaining == 0,
    );
  }

  Future<String> uncompleteTodo(TodoItem item) async {
    final repository = ref.read(todoRepositoryProvider);
    await repository.uncompleteItem(item);
    return '「${item.name}」を未購入に戻しました';
  }

  Future<({String message, TodoItem? todoItem})?> addTodo({
    required String text,
    required String category,
    required String? categoryId,
    required String reading,
    required int priority,
    XFile? image,
    int? budgetMinAmount,
    int? budgetMaxAmount,
    int? budgetType,
    String? quantityText,
    int? quantityUnit,
    int? quantityCount,
  }) async {
    if (text.isEmpty) return null;
    String? imageUrl;

    final repository = ref.read(todoRepositoryProvider);
    final profile = ref.read(myProfileProvider).value;

    if (image != null) {
      imageUrl = await ref.read(itemsRepositoryProvider).uploadItemImage(image);
    }

    final todoItem = await repository.addItem(
      name: text,
      category: category,
      categoryId: categoryId,
      priority: priority,
      familyId: profile?.currentFamilyId,
      reading: reading,
      imageUrl: imageUrl,
      budgetMinAmount: budgetMinAmount,
      budgetMaxAmount: budgetMaxAmount,
      budgetType: budgetType,
      quantityText: quantityText,
      quantityUnit: quantityUnit,
      quantityCount: quantityCount,
    );

    if (todoItem == null) return null;
    return (message: '「$text」をリストに追加しました！', todoItem: todoItem);
  }

  Future<void> updateTodo(
    TodoItem item,
    String category,
    String? categoryId,
    String newName,
    int newPriority, {
    XFile? image,
    bool removeImage = false,
    int? budgetMinAmount,
    int? budgetMaxAmount,
    int? budgetType,
    bool removeBudget = false,
    String? quantityText,
    int? quantityUnit,
    int? quantityCount,
    bool removeQuantity = false,
  }) async {
    String? imageUrl;
    if (image != null) {
      imageUrl = await ref.read(itemsRepositoryProvider).uploadItemImage(image);
    }
    final repository = ref.read(todoRepositoryProvider);
    await repository.updateItemName(
      item,
      category,
      categoryId,
      newName,
      newPriority,
      imageUrl: imageUrl,
      removeImage: removeImage,
      budgetMinAmount: budgetMinAmount,
      budgetMaxAmount: budgetMaxAmount,
      budgetType: budgetType,
      removeBudget: removeBudget,
      quantityText: quantityText,
      quantityUnit: quantityUnit,
      quantityCount: quantityCount,
      removeQuantity: removeQuantity,
    );
  }

  // 入力中に過去のマスタからアイテムを検索する
Future<Item?> searchItemByReading(String reading) async {
  if (reading.isEmpty) return null;

  // 現在のユーザー情報を取得
  final profile = ref.read(myProfileProvider).value;
  final userId = Supabase.instance.client.auth.currentUser?.id;
  
  if (userId == null) return null;

  // リポジトリに検索を依頼
  return await ref.read(itemsRepositoryProvider).findItemByReading(
    reading,
    userId,
    profile?.currentFamilyId,
  );
}

// 履歴から再追加する
Future<TodoItem?> addFromHistory(Item masterItem) async {
  final repository = ref.read(todoRepositoryProvider);
  final profile = ref.read(myProfileProvider).value;

  final added = await repository.addItem(
    name: masterItem.name,
    category: masterItem.category,
    categoryId: masterItem.categoryId,
    priority: 0,
    familyId: profile?.currentFamilyId,
    reading: masterItem.reading,
    imageUrl: masterItem.imageUrl,
    budgetMinAmount: masterItem.budgetMinAmount,
    budgetMaxAmount: masterItem.budgetMaxAmount,
    budgetType: masterItem.budgetType,
    quantityText: masterItem.quantityText,
    quantityUnit: masterItem.quantityUnit,
  );

  return added;
}

Future<List<dynamic>> getSuggestions(String prefix) async {
  if (prefix.isEmpty) return [];
  final profile = ref.read(myProfileProvider).value;
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];

  return await ref.read(itemsRepositoryProvider).searchItemsByReadingPrefix(
    prefix,
    userId,
    profile?.currentFamilyId,
  );
}

Future<void> initializeData() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;

  await ref.read(itemsRepositoryProvider).processPendingReadings();
}
}
