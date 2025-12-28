import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
export 'package:uuid/uuid.dart';

class TodoItems extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();

  TextColumn get name => text().withLength(min: 1, max: 50)();

  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class PurchaseHistory extends Table {
  TextColumn get name => text()();

  IntColumn get purchaseCount => integer().withDefault(const Constant(1))();

  DateTimeColumn get lastPurchasedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {name};
}
