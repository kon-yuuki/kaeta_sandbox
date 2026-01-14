import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import './global_provider.dart';
import '../repositories/items_repository.dart';

part 'items_provider.g.dart';

@riverpod
ItemsRepository itemsRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  return ItemsRepository(db);
}
