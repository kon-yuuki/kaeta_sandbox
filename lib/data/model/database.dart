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
  int get schemaVersion => 11;

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
