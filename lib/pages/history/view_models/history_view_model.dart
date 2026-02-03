import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/model/database.dart';
import '../providers/history_provider.dart';
import '../../../data/providers/profiles_provider.dart';
import '../../../data/services/notification_service.dart';

class HistoryViewModel {
  final Ref ref;
  HistoryViewModel(this.ref);

  // 履歴から再追加する
  Future<void> addFromHistory(Item masterItem) async {
    final repository = ref.read(todoRepositoryProvider);
    final profile = ref.read(myProfileProvider).value;

    await repository.addItem(
      name: masterItem.name,
      category: masterItem.category,
      categoryId: masterItem.categoryId,
      priority: 0, // 履歴からはとりあえず優先度「普通」で追加
      familyId: profile?.currentFamilyId,
      reading: masterItem.reading,
      imageUrl: masterItem.imageUrl, // 既存の画像URLを引き継ぐ
    );

    NotificationService().showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'リストに追加しました',
      body: '「${masterItem.name}」を再追加しました。',
    );
  }
}
