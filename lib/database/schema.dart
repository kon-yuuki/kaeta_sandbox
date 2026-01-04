import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:powersync/powersync.dart' as ps;

// ==========================================
// 1. PowerSync 用のスキーマ定義
// (Supabaseと同期するための「外向き」の設計図)
// ==========================================
const ps.Schema schema = ps.Schema([
  ps.Table('todo_items', [
    ps.Column.text('name'),
    ps.Column.integer('is_completed'),
    ps.Column.integer('priority'),
    ps.Column.text('created_at'), // Supabaseのカラム名と一致させる
    ps.Column.text('user_id'),
  ]),
  ps.Table('purchase_history', [
    ps.Column.text('name'),
    ps.Column.integer('purchase_count'),
    ps.Column.text('last_purchased_at'),
    ps.Column.text('user_id'),
  ]),
]);

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

  TextColumn get userId => text()();

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
  TextColumn get userId => text()();

  @override
  Set<Column> get primaryKey => {id};
}