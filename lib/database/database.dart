import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'schema.dart';

part 'database.g.dart';

@DriftDatabase(tables: [TodoItems, PurchaseHistory])
class MyDatabase extends _$MyDatabase {
  MyDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // ① スマホの「このアプリ専用の隠しフォルダ」の場所をシステムに問い合わせる
    final dbFolder = await getApplicationDocumentsDirectory();
    
    // ② そのフォルダの中に「app.db」という名前のファイルを実際に作成する
    final file = File(p.join(dbFolder.path, 'app.db'));
    
    // ③ 作成したファイル（本物のデータが書き込まれる場所）を、Driftに渡す
    return NativeDatabase(file);
  });
}