import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:powersync/powersync.dart' as ps;

// 1. アイテムマスター（読み・購入回数を管理）
class Items extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()(); // 表示名
  TextColumn get reading => text()(); // 読み（ここに索引を貼る）
  IntColumn get totalCount => integer().withDefault(const Constant(0))();
  TextColumn get familyId => text().nullable()();

 @override
  Set<Column> get primaryKey => {id};
}

Index get itemsReadingIdx => Index('items_reading_idx', 'CREATE INDEX items_reading_idx ON items (reading);');

// 2. 未完了アイテム（現在の買い物リスト）
class TodoItems extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get itemId => text()(); // Items.id を参照
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get familyId => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// 3. 購入履歴
class PurchaseHistory extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get itemId => text()(); // Items.id を参照
  DateTimeColumn get purchasedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get familyId => text()();

  @override
  Set<Column> get primaryKey => {id};
}


const ps.Schema schema = ps.Schema([
  ps.Table('items', [
    ps.Column.text('name'),
    ps.Column.text('reading'),
    ps.Column.integer('total_count'),
    ps.Column.text('family_id'),
  ], indexes: [
    ps.Index('reading', [ps.IndexedColumn('reading')])
  ]),

  ps.Table('todo_items', [
    ps.Column.text('item_id'),
    ps.Column.integer('is_completed'),
    ps.Column.text('family_id'),
    ps.Column.text('created_at'),
  ]),

  ps.Table('purchase_history', [
    ps.Column.text('item_id'),
    ps.Column.text('purchased_at'),
    ps.Column.text('family_id'),
  ]),
]);