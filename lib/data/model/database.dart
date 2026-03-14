import 'package:drift/drift.dart';
import 'schema.dart';
import 'package:uuid/uuid.dart';
import 'package:powersync/powersync.dart' hide Table;
import 'package:drift_sqlite_async/drift_sqlite_async.dart';

part 'database.g.dart';

enum TodoSortOrder {
  priority, // 重要度順
  createdAt, // 作成日順
}

@DriftDatabase(
  tables: [
    Items,
    Categories,
    TodoItems,
    PurchaseHistory,
    Profiles,
    MasterItems,
    Families,
    FamilyMembers,
    Invitations,
    FamilyBoards,
    AppNotifications,
    AppNotificationReactions,
  ],
)
class MyDatabase extends _$MyDatabase {
  MyDatabase(PowerSyncDatabase db) : super(SqliteAsyncDriftConnection(db));

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            if (!await _tableExists('app_notifications')) {
              await m.createTable(appNotifications);
            }
          }
          if (from < 3) {
            // 既存DBで重複追加にならないように存在確認してから追加する
            if (!await _columnExists('app_notifications', 'is_read')) {
              await m.addColumn(appNotifications, appNotifications.isRead);
            }
          }
          if (from < 4) {
            if (!await _columnExists('app_notifications', 'family_id')) {
              await m.addColumn(appNotifications, appNotifications.familyId);
            }
          }
          if (from < 5) {
            if (!await _columnExists('app_notifications', 'actor_user_id')) {
              await m.addColumn(appNotifications, appNotifications.actorUserId);
            }
          }
          if (from < 6) {
            if (!await _columnExists('app_notifications', 'reaction_emoji')) {
              await m.addColumn(appNotifications, appNotifications.reactionEmoji);
            }
          }
          if (from < 7) {
            if (!await _columnExists('app_notifications', 'event_id')) {
              await m.addColumn(appNotifications, appNotifications.eventId);
            }
          }
          if (from < 8) {
            if (!await _tableExists('app_notification_reactions')) {
              await m.createTable(appNotificationReactions);
            }
          }
          if (from < 9) {
            // categories.name のグローバル unique 制約を外すため再作成
            await customStatement('PRAGMA foreign_keys = OFF;');
            await customStatement('''
              CREATE TABLE categories_new (
                id TEXT NOT NULL PRIMARY KEY,
                name TEXT NOT NULL,
                user_id TEXT NOT NULL,
                family_id TEXT NULL
              );
            ''');
            await customStatement('''
              INSERT INTO categories_new (id, name, user_id, family_id)
              SELECT id, name, user_id, family_id FROM categories;
            ''');
            final categoriesType = await _sqliteObjectType('categories');
            if (categoriesType == 'view') {
              await customStatement('DROP VIEW categories;');
            } else {
              await customStatement('DROP TABLE categories;');
            }
            await customStatement(
              'ALTER TABLE categories_new RENAME TO categories;',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_categories_user_family_name ON categories(user_id, family_id, name);',
            );
            await customStatement('PRAGMA foreign_keys = ON;');
          }
          if (from < 10) {
            if (!await _columnExists('family_members', 'created_at')) {
              await customStatement(
                "ALTER TABLE family_members ADD COLUMN created_at TEXT NOT NULL DEFAULT (datetime('now'));",
              );
            }
          }
          if (from < 11) {
            // 同一スコープ(user_id + family_id + name)の重複を解消してから一意制約を張る。
            // family_id が null のケースも含めるため ifnull で正規化する。
            await customStatement('''
              DELETE FROM categories
              WHERE rowid NOT IN (
                SELECT MIN(rowid)
                FROM categories
                GROUP BY user_id, ifnull(family_id, ''), name
              );
            ''');
            await customStatement('''
              CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_scope_name_unique
              ON categories(user_id, ifnull(family_id, ''), name);
            ''');
          }
          if (from < 12) {
            await customStatement('PRAGMA foreign_keys = OFF;');

            await customStatement('''
              CREATE TABLE items_new (
                id TEXT NOT NULL PRIMARY KEY,
                name TEXT NOT NULL,
                category TEXT NOT NULL,
                category_id TEXT NULL,
                reading TEXT NOT NULL,
                purchase_count INTEGER NOT NULL DEFAULT 0,
                user_id TEXT NULL,
                family_id TEXT NULL,
                image_url TEXT NULL,
                budget_min_amount INTEGER NULL,
                budget_max_amount INTEGER NULL,
                budget_type INTEGER NULL,
                quantity_text TEXT NULL,
                quantity_unit INTEGER NULL,
                quantity_count INTEGER NULL
              );
            ''');
            await customStatement('''
              INSERT INTO items_new (
                id, name, category, category_id, reading, purchase_count,
                user_id, family_id, image_url, budget_min_amount,
                budget_max_amount, budget_type, quantity_text,
                quantity_unit, quantity_count
              )
              SELECT
                id, name, category, category_id, reading, purchase_count,
                user_id, family_id, image_url, budget_min_amount,
                budget_max_amount, budget_type, quantity_text,
                quantity_unit, quantity_count
              FROM items;
            ''');
            final itemsType = await _sqliteObjectType('items');
            if (itemsType == 'view') {
              await customStatement('DROP VIEW items;');
            } else {
              await customStatement('DROP TABLE items;');
            }
            await customStatement('ALTER TABLE items_new RENAME TO items;');

            await customStatement('''
              CREATE TABLE categories_new (
                id TEXT NOT NULL PRIMARY KEY,
                name TEXT NOT NULL,
                user_id TEXT NULL,
                family_id TEXT NULL
              );
            ''');
            await customStatement('''
              INSERT INTO categories_new (id, name, user_id, family_id)
              SELECT id, name, user_id, family_id FROM categories;
            ''');
            final categoriesType = await _sqliteObjectType('categories');
            if (categoriesType == 'view') {
              await customStatement('DROP VIEW categories;');
            } else {
              await customStatement('DROP TABLE categories;');
            }
            await customStatement(
              'ALTER TABLE categories_new RENAME TO categories;',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_categories_user_family_name ON categories(user_id, family_id, name);',
            );
            await customStatement('''
              CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_scope_name_unique
              ON categories(ifnull(user_id, ''), ifnull(family_id, ''), name);
            ''');

            await customStatement('''
              CREATE TABLE todo_items_new (
                id TEXT NOT NULL PRIMARY KEY,
                item_id TEXT NULL,
                family_id TEXT NULL,
                name TEXT NOT NULL,
                category TEXT NOT NULL,
                category_id TEXT NULL,
                is_completed INTEGER NOT NULL DEFAULT 0,
                priority INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                user_id TEXT NULL,
                budget_min_amount INTEGER NULL,
                budget_max_amount INTEGER NULL,
                budget_type INTEGER NULL,
                completed_at TEXT NULL,
                quantity_text TEXT NULL,
                quantity_unit INTEGER NULL,
                quantity_count INTEGER NULL
              );
            ''');
            await customStatement('''
              INSERT INTO todo_items_new (
                id, item_id, family_id, name, category, category_id,
                is_completed, priority, created_at, user_id,
                budget_min_amount, budget_max_amount, budget_type,
                completed_at, quantity_text, quantity_unit, quantity_count
              )
              SELECT
                id, item_id, family_id, name, category, category_id,
                is_completed, priority, created_at, user_id,
                budget_min_amount, budget_max_amount, budget_type,
                completed_at, quantity_text, quantity_unit, quantity_count
              FROM todo_items;
            ''');
            final todoItemsType = await _sqliteObjectType('todo_items');
            if (todoItemsType == 'view') {
              await customStatement('DROP VIEW todo_items;');
            } else {
              await customStatement('DROP TABLE todo_items;');
            }
            await customStatement(
              'ALTER TABLE todo_items_new RENAME TO todo_items;',
            );

            await customStatement('''
              CREATE TABLE purchase_history_new (
                id TEXT NOT NULL PRIMARY KEY,
                item_id TEXT NULL,
                family_id TEXT NULL,
                name TEXT NOT NULL UNIQUE,
                last_purchased_at TEXT NOT NULL,
                user_id TEXT NULL
              );
            ''');
            await customStatement('''
              INSERT INTO purchase_history_new (
                id, item_id, family_id, name, last_purchased_at, user_id
              )
              SELECT
                id, item_id, family_id, name, last_purchased_at, user_id
              FROM purchase_history;
            ''');
            final purchaseHistoryType = await _sqliteObjectType(
              'purchase_history',
            );
            if (purchaseHistoryType == 'view') {
              await customStatement('DROP VIEW purchase_history;');
            } else {
              await customStatement('DROP TABLE purchase_history;');
            }
            await customStatement(
              'ALTER TABLE purchase_history_new RENAME TO purchase_history;',
            );

            await customStatement('PRAGMA foreign_keys = ON;');
          }
        },
      );

  Future<bool> _tableExists(String tableName) async {
    final result = await customSelect(
      'SELECT name FROM sqlite_master WHERE type = ? AND name = ?',
      variables: [
        Variable.withString('table'),
        Variable.withString(tableName),
      ],
    ).get();
    return result.isNotEmpty;
  }

  Future<bool> _columnExists(String tableName, String columnName) async {
    final result = await customSelect("PRAGMA table_info('$tableName')").get();
    return result.any((row) => row.read<String>('name') == columnName);
  }

  Future<String?> _sqliteObjectType(String objectName) async {
    final result = await customSelect(
      'SELECT type FROM sqlite_master WHERE name = ? LIMIT 1',
      variables: [Variable.withString(objectName)],
    ).getSingleOrNull();
    return result?.read<String>('type');
  }

  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}
