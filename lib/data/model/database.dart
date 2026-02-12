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
  int get schemaVersion => 8;

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

  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}
