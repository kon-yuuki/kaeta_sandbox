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
            await m.createTable(appNotifications);
          }
          if (from < 3) {
            // isReadカラムを追加（既存テーブルがある場合）
            await m.addColumn(appNotifications, appNotifications.isRead);
          }
          if (from < 4) {
            // familyIdカラムを追加
            await m.addColumn(appNotifications, appNotifications.familyId);
          }
        },
      );

  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}
