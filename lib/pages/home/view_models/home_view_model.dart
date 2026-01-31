import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/model/database.dart';
import '../providers/home_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../../data/services/notification_service.dart';
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

  Future<void> completeTodo(TodoItem item) async {
    final repository = ref.read(todoRepositoryProvider);
    final profile = ref.read(myProfileProvider).value;

    // 2. 完了処理を実行
    await repository.completeItem(item, profile?.familyId);

    // 3. 通知処理をここに移管（Screenからコピペ）
    NotificationService().showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'タスクを完了しました',
      body: '「${item.name}」を完了しました！', // item.name を直接使えます
    );
  }

  Future<void> addTodo({
    required String text,
    required String category,
    required String? categoryId,
    required String reading,
    required int priority,
    XFile? image,
  }) async {
    if (text.isEmpty) return;
    String? imageUrl;

    final repository = ref.read(todoRepositoryProvider);
    final profile = ref.read(myProfileProvider).value;

    if (image != null) {
      imageUrl = await ref.read(itemsRepositoryProvider).uploadItemImage(image);
    }

    // ① Repositoryへの保存（渡された引数とprofileから取得したfamilyIdを使用）
    await repository.addItem(
      name: text,
      category: category,
      categoryId: categoryId,
      priority: priority,
      familyId: profile?.familyId,
      reading: reading,
      imageUrl: imageUrl,
    );

    // ② 通知の表示（Screen のロジックをそのまま移動）
    NotificationService().showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'タスクを追加しました',
      body: '「$text」をリストに保存しました！',
    );
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
    profile?.familyId,
  );
}

// 履歴から再追加する
Future<void> addFromHistory(Item masterItem) async {
  final repository = ref.read(todoRepositoryProvider);
  final profile = ref.read(myProfileProvider).value;

  await repository.addItem(
    name: masterItem.name,
    category: masterItem.category,
    categoryId: masterItem.categoryId,
    priority: 0, // 履歴からはとりあえず優先度「普通」で追加
    familyId: profile?.familyId,
    reading: masterItem.reading,
    imageUrl: masterItem.imageUrl, // 既存の画像URLを引き継ぐ
  );

  NotificationService().showNotification(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: 'リストに追加しました',
    body: '「${masterItem.name}」を再追加しました。',
  );
}

Future<List<dynamic>> getSuggestions(String prefix) async {
  if (prefix.isEmpty) return [];
  final profile = ref.read(myProfileProvider).value;
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];

  return await ref.read(itemsRepositoryProvider).searchItemsByReadingPrefix(
    prefix,
    userId,
    profile?.familyId,
  );
}

Future<void> initializeData() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;

  await ref.read(itemsRepositoryProvider).processPendingReadings();
}
}
