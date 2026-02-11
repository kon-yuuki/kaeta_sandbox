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
  ],
)
class MyDatabase extends _$MyDatabase {
  MyDatabase(PowerSyncDatabase db) : super(SqliteAsyncDriftConnection(db));

  @override
  int get schemaVersion => 4;

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
