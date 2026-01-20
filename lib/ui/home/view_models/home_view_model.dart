import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/model/database.dart';
import '../providers/home_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../../data/serviecs/notification_service.dart';

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

  // lib/ui/home/view_models/home_view_model.dart

  Future<void> addTodo({
    required String text, // editNameController.text を受け取る
    required String category,
    required String? categoryId,
    required int selectedPriority,
  }) async {
    if (text.isEmpty) return;

    final repository = ref.read(todoRepositoryProvider);
    final profile = ref.read(myProfileProvider).value;

    // ① Repositoryへの保存（渡された引数とprofileから取得したfamilyIdを使用）
    await repository.addItem(
      text,
      category,
      categoryId,
      selectedPriority,
      profile?.familyId,
      text, // reading用
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
    int newPriority
    ) async {
    final repository = ref.read(todoRepositoryProvider);
    await repository.updateItemName(item, category,categoryId,newName,newPriority);
  }

}

