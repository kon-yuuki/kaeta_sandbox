import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/model/database.dart';
import '../providers/history_provider.dart';
import '../../../data/providers/profiles_provider.dart';

class HistoryViewModel {
  final Ref ref;
  HistoryViewModel(this.ref);

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
}
