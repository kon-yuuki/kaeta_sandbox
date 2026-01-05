import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import './global_provider.dart';
import '../../../database/database.dart';
import '../repositories/profiles_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'profiles_provider.g.dart';

@riverpod
ProfileRepository profileRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  return ProfileRepository(db);
}

@riverpod
Stream<Profile?> myProfile(Ref ref) {
  final db = ref.watch(databaseProvider);
  // 現在ログインしているユーザーのIDを取得
  final userId = Supabase.instance.client.auth.currentUser?.id;

  if (userId == null) {
    return Stream.value(null);
  }

  // Driftを使って自分のプロフィール行を「監視(watch)」します
  return (db.select(db.profiles)..where((t) => t.id.equals(userId))).watchSingleOrNull();
}