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
    ps.Column.integer('purchase_count'),
    ps.Column.text('user_id'),
    ps.Column.text('family_id'),
    ps.Column.text('image_url'),
    ps.Column.integer('budget_amount'),
    ps.Column.integer('budget_type'),
    ps.Column.text('quantity_text'),
    ps.Column.integer('quantity_unit'),
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
    ps.Column.integer('budget_amount'),
    ps.Column.integer('budget_type'),
    ps.Column.text('completed_at'),
    ps.Column.text('quantity_text'),
    ps.Column.integer('quantity_unit'),
  ]),
  ps.Table('purchase_history', [
    ps.Column.text('item_id'),
    ps.Column.text('family_id'),
    ps.Column.text('name'),
    ps.Column.text('last_purchased_at'),
    ps.Column.text('user_id'),
  ]),
  ps.Table('profiles', [
    ps.Column.text('current_family_id'),
    ps.Column.text('display_name'),
    ps.Column.text('updated_at'),
    ps.Column.integer('onboarding_completed'),
    ps.Column.text('avatar_preset'),
    ps.Column.text('avatar_url'),
  ]),

  ps.Table('families', [
    ps.Column.text('name'),
    ps.Column.text('owner_id'),
  ]),

  ps.Table('family_members', [
    ps.Column.text('user_id'),
    ps.Column.text('family_id'),
  ]),

  ps.Table('categories', [
    ps.Column.text('name'),
    ps.Column.text('user_id'),
    ps.Column.text('family_id'),
  ]),

  ps.Table('master_items', [
    ps.Column.text('name'),
    ps.Column.text('reading'),
  ]),

  ps.Table('invitations', [
    ps.Column.text('family_id'),
    ps.Column.text('inviter_id'),
    ps.Column.text('expires_at'),
  ]),

  ps.Table('family_boards', [
    ps.Column.text('family_id'),
    ps.Column.text('user_id'),
    ps.Column.text('message'),
    ps.Column.text('updated_by'),
    ps.Column.text('updated_at'),
  ]),
]);

class Items extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get reading => text()();
  IntColumn get purchaseCount => integer().withDefault(const Constant(0))();
  TextColumn get userId => text()();
  TextColumn get familyId => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  IntColumn get budgetAmount => integer().nullable()();
  IntColumn get budgetType => integer().nullable()();
  TextColumn get quantityText => text().nullable()();
  IntColumn get quantityUnit => integer().nullable()();

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
 TextColumn get familyId => text().nullable().references(
        Families, 
        #id, 
        onDelete: KeyAction.cascade, 
      )();
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  TextColumn get userId => text().references(Profiles, #id, onDelete: KeyAction.cascade)();
  IntColumn get budgetAmount => integer().nullable()();
  IntColumn get budgetType => integer().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get quantityText => text().nullable()();
  IntColumn get quantityUnit => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PurchaseHistory extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get itemId => text().nullable().references(Items, #id)();
  TextColumn get familyId => text().nullable()();
  TextColumn get name => text().unique()();
  DateTimeColumn get lastPurchasedAt => dateTime()();
  TextColumn get userId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get currentFamilyId => text().nullable()();
  TextColumn get displayName => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get onboardingCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get avatarPreset => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Families extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();
  TextColumn get ownerId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class FamilyMembers extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get userId => text()(); 
  TextColumn get familyId => text().references(Families, #id)(); // 家族ID

  @override
  Set<Column> get primaryKey => {id};
}


class MasterItems extends Table {
   TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();
  TextColumn get reading => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Invitations extends Table {
  TextColumn get id => text()(); // 招待コード (UUID)

  // どの家族への招待か
  TextColumn get familyId => text().references(Families, #id, onDelete: KeyAction.cascade)();

  // 誰が招待したか
  TextColumn get inviterId => text().references(Profiles, #id)();

  // 7日間の有効期限を管理するための日付
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class FamilyBoards extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get familyId => text().nullable()();
  TextColumn get userId => text().nullable()();
  TextColumn get message => text().withDefault(const Constant(''))();
  TextColumn get updatedBy => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}


