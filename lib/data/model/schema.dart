import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:powersync/powersync.dart' as ps;

// ==========================================
// 1. PowerSync 用のスキーマ定義
// (Supabaseと同期するための「外向き」の設計図)
// ==========================================
const ps.Schema schema = ps.Schema([
  ps.Table('items', [
    ps.Column.text('name'),
    ps.Column.text('category'),
    ps.Column.text('category_id'),
    ps.Column.text('reading'),
    ps.Column.integer('total_count'),
    ps.Column.text('user_id'),
    ps.Column.text('family_id'),
    ps.Column.text('image_url'),
  ]),

  ps.Table('todo_items', [
    ps.Column.text('item_id'),
    ps.Column.text('family_id'),
    ps.Column.text('name'),
    ps.Column.text('category'),
    ps.Column.text('category_id'),
    ps.Column.integer('is_completed'),
    ps.Column.integer('priority'),
    ps.Column.text('created_at'),
    ps.Column.text('user_id'),
  ]),
  ps.Table('purchase_history', [
    ps.Column.text('item_id'),
    ps.Column.text('family_id'),
    ps.Column.text('name'),
    ps.Column.integer('purchase_count'),
    ps.Column.text('last_purchased_at'),
    ps.Column.text('user_id'),
  ]),
  ps.Table('profiles', [
    ps.Column.text('family_id'),
    ps.Column.text('display_name'),
    ps.Column.text('updated_at'),
  ]),

  ps.Table('categories', [
    ps.Column.text('name'),
    ps.Column.text('user_id'),
    ps.Column.text('family_id'),
  ]),
]);

class Items extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get reading => text()();
  IntColumn get totalCount => integer().withDefault(const Constant(0)).nullable()();
  TextColumn get userId => text()();
  TextColumn get familyId => text().nullable()();
  TextColumn get imageUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text().unique()();
  TextColumn get userId => text()();
  TextColumn get familyId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class TodoItems extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get itemId => text().nullable().references(Items, #id)();
  TextColumn get familyId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
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
  TextColumn get itemId => text().nullable().references(Items, #id)();
  TextColumn get familyId => text().nullable()();

  TextColumn get name => text().unique()();

  IntColumn get purchaseCount => integer().withDefault(const Constant(1))();

  DateTimeColumn get lastPurchasedAt => dateTime()();

  TextColumn get userId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Profiles extends Table {
  TextColumn get id => text()(); // auth.users の ID と一致するため clientDefault は不要
  TextColumn get familyId => text().nullable()(); // まだ家族に属していない場合は null になるため
  TextColumn get displayName => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
