import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/database.dart' as db_model;
import 'global_provider.dart';
import 'profiles_provider.dart';
import '../repositories/families_repository.dart';

part 'families_provider.g.dart';

@riverpod
FamiliesRepository familiesRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  return FamiliesRepository(db);
}

// 自分が所属している家族のリストを取得するProvider
@riverpod
Stream<List<db_model.Family>> joinedFamilies(Ref ref) {
  final repo = ref.watch(familiesRepositoryProvider);
  return repo.watchJoinedFamilies();
}

// 現在選択されている家族IDを文字列として提供するProvider
@riverpod
String? selectedFamilyId(Ref ref) {
  // 自分のプロフィールを監視
  final profileAsync = ref.watch(myProfileProvider);
  
  // プロフィールデータがあればそのIDを、なければ null（個人モード）を返す
  return profileAsync.when(
    data: (profile) => profile?.currentFamilyId,
    loading: () => null,
    error: (_, __) => null,
  );
  
}
