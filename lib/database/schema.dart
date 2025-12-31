import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

// --- Drift 用のテーブル定義 ---
// PowerSync に依存しない、純粋な Drift のテーブル構成に戻します。

class TodoItems extends Table {
  // PowerSync を使わない場合も UUID を主キーにしておくと、
  // 後で手動同期や再連携をするときに Supabase と紐付けやすくて便利です。
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  
  TextColumn get name => text().withLength(min: 1, max: 50)();
  
  // Drift 標準の boolean 型に戻します
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  
  IntColumn get priority => integer().withDefault(const Constant(0))();
  
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

class PurchaseHistory extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  
  // name をユニーク（重複不可）にしたい場合は、ここで設定しておくと 
  // insertOnConflictUpdate が正しく機能します。
  TextColumn get name => text().unique()();
  
  IntColumn get purchaseCount => integer().withDefault(const Constant(1))();
  
  DateTimeColumn get lastPurchasedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}