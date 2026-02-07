import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:powersync/powersync.dart' as ps;

// ==========================================
// 1. PowerSync 用のスキーマ定義
// (Supabaseと同期するための「外向き」の設計図)
// ==========================================
const ps.Schema schema = ps.Schema([
  ps.Table('items', [
    ps.Column.text('name'), // アイテム名
    ps.Column.text('category'), // 表示用カテゴリ名
    ps.Column.text('category_id'), // categories.id 参照
    ps.Column.text('reading'), // かな読み（検索用）
    ps.Column.integer('purchase_count'), // 購入回数
    ps.Column.text('user_id'), // 作成ユーザーID
    ps.Column.text('family_id'), // 共有先家族ID（個人ならnull）
    ps.Column.text('image_url'), // 商品画像URL
    ps.Column.integer('budget_amount'), // 予算の数値（例: 300）
    ps.Column.integer('budget_type'), // 予算の基準単位（0: 1つあたり, 1: 100gあたり）
    ps.Column.text('quantity_text'), // ほしい量の入力値（例: "2", "500"）
    ps.Column.integer('quantity_unit'), // ほしい量の単位（0:g, 1:mg, 2:ml）
    ps.Column.integer('quantity_count'), // 個数
  ]),

  ps.Table('todo_items', [
    ps.Column.text('item_id'), // items.id 参照
    ps.Column.text('family_id'), // 共有先家族ID（個人ならnull）
    ps.Column.text('name'), // 作成時の表示名スナップショット
    ps.Column.text('category'), // 作成時のカテゴリ名スナップショット
    ps.Column.text('category_id'), // 作成時の categories.id スナップショット
    ps.Column.integer('is_completed'), // 完了フラグ（0/1）
    ps.Column.integer('priority'), // 優先度
    ps.Column.text('created_at'), // 作成日時
    ps.Column.text('user_id'), // 作成ユーザーID
    ps.Column.integer('budget_amount'), // Todo作成時点の予算数値を保持
    ps.Column.integer('budget_type'), // Todo作成時点の予算基準単位（0: 1つあたり, 1: 100gあたり）
    ps.Column.text('completed_at'), // 完了日時
    ps.Column.text('quantity_text'), // Todo作成時点のほしい量の入力値
    ps.Column.integer('quantity_unit'), // Todo作成時点のほしい量の単位（0:g, 1:mg, 2:ml）
    ps.Column.integer('quantity_count'), // Todo作成時点の個数
  ]),
  ps.Table('purchase_history', [
    ps.Column.text('item_id'), // items.id 参照
    ps.Column.text('family_id'), // 家族ID（個人ならnull）
    ps.Column.text('name'), // 表示名
    ps.Column.text('last_purchased_at'), // 最終購入日時
    ps.Column.text('user_id'), // 記録ユーザーID
  ]),
  ps.Table('profiles', [
    ps.Column.text('current_family_id'), // 現在選択中の家族ID
    ps.Column.text('display_name'), // 表示名
    ps.Column.text('updated_at'), // 更新日時
    ps.Column.integer('onboarding_completed'), // オンボーディング完了フラグ（0/1）
    ps.Column.text('avatar_preset'), // プリセットアバターのアセットパス
    ps.Column.text('avatar_url'), // カスタムアバターURL
  ]),

  ps.Table('families', [
    ps.Column.text('name'), // 家族名
    ps.Column.text('owner_id'), // オーナーユーザーID
  ]),

  ps.Table('family_members', [
    ps.Column.text('user_id'), // 所属ユーザーID
    ps.Column.text('family_id'), // 所属家族ID
  ]),

  ps.Table('categories', [
    ps.Column.text('name'), // カテゴリ名
    ps.Column.text('user_id'), // 作成ユーザーID
    ps.Column.text('family_id'), // 家族ID（個人ならnull）
  ]),

  ps.Table('master_items', [
    ps.Column.text('name'), // マスタ商品名
    ps.Column.text('reading'), // マスタ商品のかな読み
  ]),

  ps.Table('invitations', [
    ps.Column.text('family_id'), // 招待先家族ID
    ps.Column.text('inviter_id'), // 招待作成者ユーザーID
    ps.Column.text('expires_at'), // 有効期限
  ]),

  ps.Table('family_boards', [
    ps.Column.text('family_id'), // 家族ID（個人メモならnull）
    ps.Column.text('user_id'), // 個人メモ所有者ID
    ps.Column.text('message'), // 伝言本文
    ps.Column.text('updated_by'), // 最終更新者ID
    ps.Column.text('updated_at'), // 最終更新日時
  ]),
]);

class Items extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // PK
  TextColumn get name => text()(); // アイテム名
  TextColumn get category => text()(); // 表示用カテゴリ名
  TextColumn get categoryId => text().nullable().references(Categories, #id)(); // categories.id 参照
  TextColumn get reading => text()(); // かな読み（検索用）
  IntColumn get purchaseCount => integer().withDefault(const Constant(0))(); // 購入回数
  TextColumn get userId => text()(); // 作成ユーザーID
  TextColumn get familyId => text().nullable()(); // 共有先家族ID（個人ならnull）
  TextColumn get imageUrl => text().nullable()(); // 商品画像URL
  IntColumn get budgetAmount => integer().nullable()(); // 予算の数値（例: 300）
  IntColumn get budgetType => integer().nullable()(); // 予算の基準単位（0: 1つあたり, 1: 100gあたり）
  TextColumn get quantityText => text().nullable()(); // ほしい量の入力値（例: "2", "500"）
  IntColumn get quantityUnit => integer().nullable()(); // ほしい量の単位（0:g, 1:mg, 2:ml）
  IntColumn get quantityCount => integer().nullable()(); // 個数

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // PK
  TextColumn get name => text().unique()(); // カテゴリ名
  TextColumn get userId => text()(); // 作成ユーザーID
  TextColumn get familyId => text().nullable()(); // 家族ID（個人ならnull）

  @override
  Set<Column> get primaryKey => {id};
}

class TodoItems extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // PK
  TextColumn get itemId => text().nullable().references(Items, #id)(); // items.id 参照
  TextColumn get familyId => text().nullable().references(
    Families,
    #id,
    onDelete: KeyAction.cascade,
  )(); // 共有先家族ID（個人ならnull）
  TextColumn get name => text()(); // 作成時の表示名スナップショット
  TextColumn get category => text()(); // 作成時のカテゴリ名スナップショット
  TextColumn get categoryId => text().nullable().references(Categories, #id)(); // 作成時の categories.id
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))(); // 完了フラグ
  IntColumn get priority => integer().withDefault(const Constant(0))(); // 優先度
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())(); // 作成日時
  TextColumn get userId => text().references(Profiles, #id, onDelete: KeyAction.cascade)(); // 作成ユーザーID
  IntColumn get budgetAmount => integer().nullable()(); // Todo作成時点の予算数値を保持
  IntColumn get budgetType => integer().nullable()(); // Todo作成時点の予算基準単位（0: 1つあたり, 1: 100gあたり）
  DateTimeColumn get completedAt => dateTime().nullable()(); // 完了日時
  TextColumn get quantityText => text().nullable()(); // Todo作成時点のほしい量の入力値
  IntColumn get quantityUnit => integer().nullable()(); // Todo作成時点のほしい量の単位（0:g, 1:mg, 2:ml）
  IntColumn get quantityCount => integer().nullable()(); // Todo作成時点の個数

  @override
  Set<Column> get primaryKey => {id};
}

class PurchaseHistory extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // PK
  TextColumn get itemId => text().nullable().references(Items, #id)(); // items.id 参照
  TextColumn get familyId => text().nullable()(); // 家族ID（個人ならnull）
  TextColumn get name => text().unique()(); // 表示名
  DateTimeColumn get lastPurchasedAt => dateTime()(); // 最終購入日時
  TextColumn get userId => text()(); // 記録ユーザーID

  @override
  Set<Column> get primaryKey => {id};
}

class Profiles extends Table {
  TextColumn get id => text()(); // Supabase auth user id（PK）
  TextColumn get currentFamilyId => text().nullable()(); // 現在選択中の家族ID
  TextColumn get displayName => text().nullable()(); // 表示名
  DateTimeColumn get updatedAt => dateTime()(); // 更新日時
  BoolColumn get onboardingCompleted => boolean().withDefault(const Constant(false))(); // オンボーディング完了フラグ
  TextColumn get avatarPreset => text().nullable()(); // プリセットアバターのアセットパス
  TextColumn get avatarUrl => text().nullable()(); // カスタムアバターURL

  @override
  Set<Column> get primaryKey => {id};
}

class Families extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // PK
  TextColumn get name => text()(); // 家族名
  TextColumn get ownerId => text()(); // オーナーユーザーID

  @override
  Set<Column> get primaryKey => {id};
}

class FamilyMembers extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // PK
  TextColumn get userId => text()(); // 所属ユーザーID
  TextColumn get familyId => text().references(Families, #id)(); // 所属家族ID

  @override
  Set<Column> get primaryKey => {id};
}


class MasterItems extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // PK
  TextColumn get name => text()(); // マスタ商品名
  TextColumn get reading => text()(); // マスタ商品のかな読み

  @override
  Set<Column> get primaryKey => {id};
}

class Invitations extends Table {
  TextColumn get id => text()(); // 招待コード（UUID, PK）

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
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // PK
  TextColumn get familyId => text().nullable()(); // 家族ID（個人メモならnull）
  TextColumn get userId => text().nullable()(); // 個人メモ所有者ID
  TextColumn get message => text().withDefault(const Constant(''))(); // 伝言本文
  TextColumn get updatedBy => text().nullable()(); // 最終更新者ID
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())(); // 最終更新日時

  @override
  Set<Column> get primaryKey => {id};
}
