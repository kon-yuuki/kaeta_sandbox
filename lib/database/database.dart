import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'schema.dart';
import 'package:uuid/uuid.dart';

part 'database.g.dart';

enum TodoSortOrder {
  priority,  // 重要度順
  createdAt, // 作成日順
}

@DriftDatabase(tables: [TodoItems, PurchaseHistory])
class MyDatabase extends _$MyDatabase {
  // 💡 コンストラクタを標準の形に戻します（PowerSyncDatabase を受け取らない）
  MyDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

// 💡 データベースファイルを作成して接続する標準の関数
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // アプリのドキュメントフォルダを取得
    final dbFolder = await getApplicationDocumentsDirectory();
    // ファイル名（なんでもOKですが、不整合を避けるため以前と違う名前にするか、アプリを削除してください）
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}