import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:powersync/powersync.dart' as ps;

// ==========================================
// 1. PowerSync 用のスキーマ定義
// (Supabaseと同期するための「外向き」の設計図)
// ==========================================
const ps.Schema schema = ps.Schema([
  ps.Table('items', [
    ps.Column.text('name'), // 用途: 商品の表示名 / 値: "牛乳"
    ps.Column.text('category'), // 用途: 表示用カテゴリ名(冗長保持) / 値: "乳製品", "指定なし"
    ps.Column.text('category_id'), // 用途: categories.id 参照 / 値: UUID文字列 or null
    ps.Column.text('reading'), // 用途: かな検索用 / 値: "ぎゅうにゅう"
    ps.Column.integer('purchase_count'), // 用途: 購入回数集計 / 値: 0, 1, 2...
    ps.Column.text('user_id'), // 用途: 作成者のユーザー識別 / 値: auth user id(UUID)
    ps.Column.text('family_id'), // 用途: 家族共有のスコープ / 値: families.id or null(個人利用)
    ps.Column.text('image_url'), // 用途: 商品画像の参照先 / 値: https URL or null
    ps.Column.integer('budget_min_amount'), // 用途: 希望予算の下限 / 値: 200, 500...
    ps.Column.integer('budget_max_amount'), // 用途: 希望予算の上限 / 値: 350, 1000...
    ps.Column.integer('budget_type'), // 用途: 予算単位 / 値: 0=1つあたり, 1=100gあたり
    ps.Column.text('quantity_text'), // 用途: ほしい量の自由入力値 / 値: "2", "500", null
    ps.Column.integer('quantity_unit'), // 用途: ほしい量の単位 / 値: 0=g, 1=mg, 2=ml, null
    ps.Column.integer('quantity_count'), // 用途: ほしい個数 / 値: 1, 2... or null
  ]),

  ps.Table('todo_items', [
    ps.Column.text('item_id'), // 用途: items.id 参照 / 値: UUID文字列 or null
    ps.Column.text('family_id'), // 用途: 家族共有のスコープ / 値: families.id or null(個人利用)
    ps.Column.text('name'), // 用途: 登録時の表示名スナップショット / 値: "牛乳"
    ps.Column.text('category'), // 用途: 登録時のカテゴリ名スナップショット / 値: "乳製品", "指定なし"
    ps.Column.text('category_id'), // 用途: 登録時の categories.id / 値: UUID文字列 or null
    ps.Column.integer('is_completed'), // 用途: 完了状態 / 値: 0=未購入, 1=購入済み
    ps.Column.integer('priority'), // 用途: 並び替え優先度 / 値: 0, 1, 2...
    ps.Column.text('created_at'), // 用途: 作成日時 / 値: ISO8601日時文字列
    ps.Column.text('user_id'), // 用途: 作成者のユーザー識別 / 値: auth user id(UUID)
    ps.Column.integer('budget_min_amount'), // 用途: 登録時点の予算下限 / 値: 200, 500... or null
    ps.Column.integer('budget_max_amount'), // 用途: 登録時点の予算上限 / 値: 350, 1000... or null
    ps.Column.integer('budget_type'), // 用途: 登録時点の予算単位 / 値: 0=1つあたり, 1=100gあたり
    ps.Column.text('completed_at'), // 用途: 完了日時 / 値: ISO8601日時文字列 or null
    ps.Column.text('quantity_text'), // 用途: 登録時点のほしい量の自由入力 / 値: "2", "500", null
    ps.Column.integer('quantity_unit'), // 用途: 登録時点のほしい量の単位 / 値: 0=g, 1=mg, 2=ml, null
    ps.Column.integer('quantity_count'), // 用途: 登録時点のほしい個数 / 値: 1, 2... or null
  ]),
  ps.Table('purchase_history', [
    ps.Column.text('item_id'), // 用途: items.id 参照 / 値: UUID文字列 or null
    ps.Column.text('family_id'), // 用途: 家族共有のスコープ / 値: families.id or null
    ps.Column.text('name'), // 用途: 履歴表示名 / 値: "牛乳"
    ps.Column.text('last_purchased_at'), // 用途: 最終購入日時 / 値: ISO8601日時文字列
    ps.Column.text('user_id'), // 用途: 記録ユーザー識別 / 値: auth user id(UUID)
  ]),
  ps.Table('profiles', [
    ps.Column.text('current_family_id'), // 用途: 現在選択中の家族 / 値: families.id or null
    ps.Column.text('display_name'), // 用途: アプリ上の表示名 / 値: "かつまた"
    ps.Column.text('updated_at'), // 用途: プロフィール更新日時 / 値: ISO8601日時文字列
    ps.Column.integer('onboarding_completed'), // 用途: 初期設定完了状態 / 値: 0=未完了, 1=完了
    ps.Column.text('avatar_preset'), // 用途: プリセット画像キー / 値: "assets/avatar/a.png" or null
    ps.Column.text('avatar_url'), // 用途: カスタム画像URL / 値: https URL or null
  ]),

  ps.Table('families', [
    ps.Column.text('name'), // 用途: 家族グループ名 / 値: "かつまた家"
    ps.Column.text('owner_id'), // 用途: 家族作成者のユーザー識別 / 値: auth user id(UUID)
  ]),

  ps.Table('family_members', [
    ps.Column.text('user_id'), // 用途: メンバーのユーザー識別 / 値: auth user id(UUID)
    ps.Column.text('family_id'), // 用途: 所属する家族識別 / 値: families.id
  ]),

  ps.Table('categories', [
    ps.Column.text('name'), // 用途: カテゴリ表示名 / 値: "野菜", "日用品"
    ps.Column.text('user_id'), // 用途: 作成者のユーザー識別 / 値: auth user id(UUID)
    ps.Column.text('family_id'), // 用途: 家族共有のスコープ / 値: families.id or null
  ]),

  ps.Table('master_items', [
    ps.Column.text('name'), // 用途: サジェスト用のマスタ商品名 / 値: "牛乳"
    ps.Column.text('reading'), // 用途: サジェスト検索用かな / 値: "ぎゅうにゅう"
  ]),

  ps.Table('invitations', [
    ps.Column.text('family_id'), // 用途: 招待先の家族識別 / 値: families.id
    ps.Column.text('inviter_id'), // 用途: 招待作成者のユーザー識別 / 値: auth user id(UUID)
    ps.Column.text('expires_at'), // 用途: 招待コードの有効期限 / 値: ISO8601日時文字列
  ]),

  ps.Table('family_boards', [
    ps.Column.text('family_id'), // 用途: 家族ボードの対象 / 値: families.id or null(個人メモ)
    ps.Column.text('user_id'), // 用途: 個人メモ時の所有者 / 値: auth user id(UUID) or null
    ps.Column.text('message'), // 用途: ボード本文 / 値: "牛乳と卵お願いします"
    ps.Column.text('updated_by'), // 用途: 最終更新者のユーザー識別 / 値: auth user id(UUID) or null
    ps.Column.text('updated_at'), // 用途: 最終更新日時 / 値: ISO8601日時文字列
  ]),
]);

class Items extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // 用途: 商品マスタの主キー / 値: UUID
  TextColumn get name => text()(); // 用途: 商品名 / 値: "牛乳"
  TextColumn get category => text()(); // 用途: 表示用カテゴリ名(冗長保持) / 値: "乳製品", "指定なし"
  TextColumn get categoryId => text().nullable().references(Categories, #id)(); // 用途: categories.id 参照 / 値: UUID or null
  TextColumn get reading => text()(); // 用途: かな検索キー / 値: "ぎゅうにゅう"
  IntColumn get purchaseCount => integer().withDefault(const Constant(0))(); // 用途: 購入頻度集計 / 値: 0,1,2...
  TextColumn get userId => text()(); // 用途: 作成ユーザー識別 / 値: auth user id
  TextColumn get familyId => text().nullable()(); // 用途: 家族共有範囲 / 値: families.id or null
  TextColumn get imageUrl => text().nullable()(); // 用途: 商品画像URL / 値: https URL or null
  IntColumn get budgetMinAmount => integer().nullable()(); // 用途: 予算下限 / 値: 200,500... or null
  IntColumn get budgetMaxAmount => integer().nullable()(); // 用途: 予算上限 / 値: 350,1000... or null
  IntColumn get budgetType => integer().nullable()(); // 用途: 予算単位 / 値: 0=1つあたり,1=100gあたり
  TextColumn get quantityText => text().nullable()(); // 用途: ほしい量の自由入力 / 値: "2","500",null
  IntColumn get quantityUnit => integer().nullable()(); // 用途: ほしい量の単位 / 値: 0=g,1=mg,2=ml,null
  IntColumn get quantityCount => integer().nullable()(); // 用途: ほしい個数 / 値: 1,2... or null

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // 用途: カテゴリ主キー / 値: UUID
  TextColumn get name => text().unique()(); // 用途: カテゴリ表示名 / 値: "野菜"
  TextColumn get userId => text()(); // 用途: 作成ユーザー識別 / 値: auth user id
  TextColumn get familyId => text().nullable()(); // 用途: 家族共有範囲 / 値: families.id or null

  @override
  Set<Column> get primaryKey => {id};
}

class TodoItems extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // 用途: 買い物リスト行の主キー / 値: UUID
  TextColumn get itemId => text().nullable().references(Items, #id)(); // 用途: items.id 参照 / 値: UUID or null
  TextColumn get familyId => text().nullable().references(
    Families,
    #id,
    onDelete: KeyAction.cascade,
  )(); // 用途: 家族共有範囲 / 値: families.id or null
  TextColumn get name => text()(); // 用途: 作成時の表示名スナップショット / 値: "牛乳"
  TextColumn get category => text()(); // 用途: 作成時のカテゴリ名スナップショット / 値: "乳製品"
  TextColumn get categoryId => text().nullable().references(Categories, #id)(); // 用途: 作成時の categories.id / 値: UUID or null
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))(); // 用途: 購入済み状態 / 値: false=未購入,true=購入済み
  IntColumn get priority => integer().withDefault(const Constant(0))(); // 用途: 優先度 / 値: 0,1,2...
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())(); // 用途: 作成日時 / 値: DateTime
  TextColumn get userId => text().references(Profiles, #id, onDelete: KeyAction.cascade)(); // 用途: 作成ユーザー識別 / 値: auth user id
  IntColumn get budgetMinAmount => integer().nullable()(); // 用途: 登録時予算下限 / 値: 200,500... or null
  IntColumn get budgetMaxAmount => integer().nullable()(); // 用途: 登録時予算上限 / 値: 350,1000... or null
  IntColumn get budgetType => integer().nullable()(); // 用途: 登録時予算単位 / 値: 0=1つあたり,1=100gあたり
  DateTimeColumn get completedAt => dateTime().nullable()(); // 用途: 完了日時 / 値: DateTime or null
  TextColumn get quantityText => text().nullable()(); // 用途: 登録時ほしい量の自由入力 / 値: "2","500",null
  IntColumn get quantityUnit => integer().nullable()(); // 用途: 登録時ほしい量の単位 / 値: 0=g,1=mg,2=ml,null
  IntColumn get quantityCount => integer().nullable()(); // 用途: 登録時ほしい個数 / 値: 1,2... or null

  @override
  Set<Column> get primaryKey => {id};
}

class PurchaseHistory extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // 用途: 履歴行の主キー / 値: UUID
  TextColumn get itemId => text().nullable().references(Items, #id)(); // 用途: items.id 参照 / 値: UUID or null
  TextColumn get familyId => text().nullable()(); // 用途: 家族共有範囲 / 値: families.id or null
  TextColumn get name => text().unique()(); // 用途: 履歴表示名 / 値: "牛乳"
  DateTimeColumn get lastPurchasedAt => dateTime()(); // 用途: 最終購入日時 / 値: DateTime
  TextColumn get userId => text()(); // 用途: 記録ユーザー識別 / 値: auth user id

  @override
  Set<Column> get primaryKey => {id};
}

class Profiles extends Table {
  TextColumn get id => text()(); // 用途: ユーザー主キー(Supabase auth user id) / 値: UUID
  TextColumn get currentFamilyId => text().nullable()(); // 用途: 現在選択中の家族 / 値: families.id or null
  TextColumn get displayName => text().nullable()(); // 用途: 表示名 / 値: "かつまた"
  DateTimeColumn get updatedAt => dateTime()(); // 用途: 更新日時 / 値: DateTime
  BoolColumn get onboardingCompleted => boolean().withDefault(const Constant(false))(); // 用途: 初期設定完了状態 / 値: false/true
  TextColumn get avatarPreset => text().nullable()(); // 用途: プリセット画像キー / 値: asset path or null
  TextColumn get avatarUrl => text().nullable()(); // 用途: カスタム画像URL / 値: https URL or null

  @override
  Set<Column> get primaryKey => {id};
}

class Families extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // 用途: 家族主キー / 値: UUID
  TextColumn get name => text()(); // 用途: 家族名 / 値: "かつまた家"
  TextColumn get ownerId => text()(); // 用途: 作成者ユーザー識別 / 値: auth user id

  @override
  Set<Column> get primaryKey => {id};
}

class FamilyMembers extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // 用途: 家族メンバー行の主キー / 値: UUID
  TextColumn get userId => text()(); // 用途: メンバーのユーザー識別 / 値: auth user id
  TextColumn get familyId => text().references(Families, #id)(); // 用途: 所属家族識別 / 値: families.id

  @override
  Set<Column> get primaryKey => {id};
}


class MasterItems extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // 用途: マスタ商品主キー / 値: UUID
  TextColumn get name => text()(); // 用途: サジェスト元の商品名 / 値: "牛乳"
  TextColumn get reading => text()(); // 用途: サジェスト検索用かな / 値: "ぎゅうにゅう"

  @override
  Set<Column> get primaryKey => {id};
}

class Invitations extends Table {
  TextColumn get id => text()(); // 用途: 招待コード主キー / 値: UUID

  // 用途: どの家族への招待か / 値: families.id
  TextColumn get familyId => text().references(Families, #id, onDelete: KeyAction.cascade)();

  // 用途: 招待作成者のユーザー識別 / 値: profiles.id(auth user id)
  TextColumn get inviterId => text().references(Profiles, #id)();

  // 用途: 招待有効期限 / 値: DateTime
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class FamilyBoards extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // 用途: ボード行の主キー / 値: UUID
  TextColumn get familyId => text().nullable()(); // 用途: 家族ボード対象 / 値: families.id or null(個人メモ)
  TextColumn get userId => text().nullable()(); // 用途: 個人メモ所有者 / 値: auth user id or null
  TextColumn get message => text().withDefault(const Constant(''))(); // 用途: ボード本文 / 値: 任意文字列
  TextColumn get updatedBy => text().nullable()(); // 用途: 最終更新者のユーザー識別 / 値: auth user id or null
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())(); // 用途: 最終更新日時 / 値: DateTime

  @override
  Set<Column> get primaryKey => {id};
}

// アプリ内通知（ローカルのみ、同期なし）
class AppNotifications extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // 用途: 通知主キー / 値: UUID
  TextColumn get message => text()(); // 用途: 通知メッセージ / 値: "牛乳を追加しました"
  IntColumn get type => integer().withDefault(const Constant(0))(); // 用途: 通知タイプ / 値: 0=通常, 1=買い物完了
  BoolColumn get isRead => boolean().withDefault(const Constant(false))(); // 用途: 既読状態 / 値: false=未読, true=既読
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())(); // 用途: 作成日時 / 値: DateTime
  TextColumn get userId => text()(); // 用途: 通知対象ユーザー / 値: auth user id
  TextColumn get familyId => text().nullable()(); // 用途: 家族スコープ / 値: families.id or null(個人)

  @override
  Set<Column> get primaryKey => {id};
}
