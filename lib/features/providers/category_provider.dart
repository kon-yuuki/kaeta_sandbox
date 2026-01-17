import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaeta_sandbox/features/providers/profiles_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../database/database.dart';
import './global_provider.dart';
import '../repositories/category_repository.dart';

part 'category_provider.g.dart';

@riverpod
CategoryRepository categoryRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  return CategoryRepository(db);
}

@riverpod
Stream<List<Category>> categoryList(Ref ref) {
  final profileAsync = ref.watch(myProfileProvider);

  return profileAsync.when(
    data: (profile) {
      if (profile == null) return Stream.value([]);

      return ref.watch(categoryRepositoryProvider).watchCategories(
        profile.familyId ?? "",
        profile.id,
      );
    },
    loading: ()=> Stream.value([]),
    error: (_, __)=> Stream.value([]),
  );
}
