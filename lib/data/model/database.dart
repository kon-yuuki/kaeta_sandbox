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
  ],
)
class MyDatabase extends _$MyDatabase {
  MyDatabase(PowerSyncDatabase db) : super(SqliteAsyncDriftConnection(db));

  @override
  int get schemaVersion => 1;

  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}
