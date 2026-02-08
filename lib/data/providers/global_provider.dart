import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:powersync/powersync.dart';
import '../model/database.dart';
import '../../../main.dart';

part 'global_provider.g.dart';

// プロジェクトに1つ。全テーブルで使い回す「土台」
@riverpod
PowerSyncDatabase powerSync(Ref ref) => db;

@Riverpod(keepAlive: true)
MyDatabase database(Ref ref) {
  final psDb = ref.watch(powerSyncProvider);
  return MyDatabase(psDb);
}
