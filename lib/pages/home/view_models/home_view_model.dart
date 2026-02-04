import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/model/database.dart';
import '../providers/home_provider.dart';
import '../../../data/providers/profiles_provider.dart';
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

  Future<String> completeTodo(TodoItem item) async {
    final repository = ref.read(todoRepositoryProvider);
    final profile = ref.read(myProfileProvider).value;
    await repository.completeItem(item, profile?.currentFamilyId);
    return '「${item.name}」を完了しました！';
  }

  Future<({String message, TodoItem? todoItem})?> addTodo({
    required String text,
    required String category,
    required String? categoryId,
    required String reading,
    required int priority,
    XFile? image,
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
    );

    return (message: '「$text」をリストに追加しました！', todoItem: todoItem);
  }

  Future<void> updateTodo(
    TodoItem item,
    String category,
    String? categoryId,
    String newName,
    int newPriority,
  ) async {
    final repository = ref.read(todoRepositoryProvider);
    await repository.updateItemName(
      item,
      category,
      categoryId,
      newName,
      newPriority,
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
Future<String> addFromHistory(Item masterItem) async {
  final repository = ref.read(todoRepositoryProvider);
  final profile = ref.read(myProfileProvider).value;

  await repository.addItem(
    name: masterItem.name,
    category: masterItem.category,
    categoryId: masterItem.categoryId,
    priority: 0,
    familyId: profile?.currentFamilyId,
    reading: masterItem.reading,
    imageUrl: masterItem.imageUrl,
  );

  return '「${masterItem.name}」を再追加しました！';
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
