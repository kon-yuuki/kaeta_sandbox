import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaeta_sandbox/data/providers/profiles_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/database.dart';
import 'global_provider.dart';
import '../repositories/category_repository.dart';

part 'category_provider.g.dart';

@riverpod
CategoryRepository categoryRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  return CategoryRepository(db);
}

@riverpod
Stream<List<Category>> categoryList(Ref ref) {
  // 💡 プロフィールの状態を watch する
  final profileAsync = ref.watch(myProfileProvider);

  // 1. プロフィールがまだ読み込み中なら、Provider自体を loading 状態にする
  final profile = profileAsync.valueOrNull;
  if (profileAsync.isLoading || profile == null) {
    // 💡 return Stream.empty() ではなく、プロバイダー自体を待機させるのがコツ
    return const Stream.empty(); 
  }

  // 2. プロフィールが確定したら、リポジトリの watch を開始する
  return ref.watch(categoryRepositoryProvider).watchCategories(
    profile.familyId ?? "",
    profile.id,
  );
}
