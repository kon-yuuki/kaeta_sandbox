import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/database.dart';

// 通知タイプ
class NotificationType {
  static const int normal = 0;        // 通常通知（30日保持）
  static const int shoppingComplete = 1; // 買い物完了（7日保持）
}

class NotificationsRepository {
  final MyDatabase db;
  final supabase = Supabase.instance.client;

  NotificationsRepository(this.db);

  // 通知を追加
  Future<void> addNotification(
    String message, {
    int type = 0,
    String? familyId,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await db.into(db.appNotifications).insert(
      AppNotificationsCompanion.insert(
        message: message,
        type: Value(type),
        userId: userId,
        familyId: Value(familyId),
      ),
    );

    // 古い通知を自動削除
    await _cleanupOldNotifications();
  }

  // 通知一覧を監視（familyIdでフィルタ）
  Stream<List<AppNotification>> watchNotifications(String? familyId) {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value([]);

    return (db.select(db.appNotifications)
          ..where((t) {
            if (familyId == null) {
              return t.userId.equals(userId) & t.familyId.isNull();
            } else {
              return t.userId.equals(userId) & t.familyId.equals(familyId);
            }
          })
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  // 通知一覧を取得
  Future<List<AppNotification>> getNotifications(String? familyId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    return (db.select(db.appNotifications)
          ..where((t) {
            if (familyId == null) {
              return t.userId.equals(userId) & t.familyId.isNull();
            } else {
              return t.userId.equals(userId) & t.familyId.equals(familyId);
            }
          })
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  // 古い通知を削除
  Future<void> _cleanupOldNotifications() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final now = DateTime.now();

    // 通常通知: 30日以上前のものを削除
    final normalCutoff = now.subtract(const Duration(days: 30));
    await (db.delete(db.appNotifications)
          ..where((t) =>
              t.userId.equals(userId) &
              t.type.equals(NotificationType.normal) &
              t.createdAt.isSmallerThanValue(normalCutoff)))
        .go();

    // 買い物完了通知: 7日以上前のものを削除
    final shoppingCutoff = now.subtract(const Duration(days: 7));
    await (db.delete(db.appNotifications)
          ..where((t) =>
              t.userId.equals(userId) &
              t.type.equals(NotificationType.shoppingComplete) &
              t.createdAt.isSmallerThanValue(shoppingCutoff)))
        .go();
  }

  // すべての通知を削除（familyIdでフィルタ）
  Future<void> clearAllNotifications(String? familyId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await (db.delete(db.appNotifications)
          ..where((t) {
            if (familyId == null) {
              return t.userId.equals(userId) & t.familyId.isNull();
            } else {
              return t.userId.equals(userId) & t.familyId.equals(familyId);
            }
          }))
        .go();
  }

  // 個別の通知を削除
  Future<void> deleteNotification(String id) async {
    await (db.delete(db.appNotifications)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  // 未読通知の数を監視（familyIdでフィルタ）
  Stream<int> watchUnreadCount(String? familyId) {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value(0);

    final query = db.selectOnly(db.appNotifications)
      ..addColumns([db.appNotifications.id.count()])
      ..where(() {
        final base = db.appNotifications.userId.equals(userId) &
            db.appNotifications.isRead.equals(false);
        if (familyId == null) {
          return base & db.appNotifications.familyId.isNull();
        } else {
          return base & db.appNotifications.familyId.equals(familyId);
        }
      }());

    return query.watchSingle().map((row) {
      return row.read(db.appNotifications.id.count()) ?? 0;
    });
  }

  // すべての通知を既読にする（familyIdでフィルタ）
  Future<void> markAllAsRead(String? familyId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await (db.update(db.appNotifications)
          ..where((t) {
            final base = t.userId.equals(userId) & t.isRead.equals(false);
            if (familyId == null) {
              return base & t.familyId.isNull();
            } else {
              return base & t.familyId.equals(familyId);
            }
          }))
        .write(const AppNotificationsCompanion(isRead: Value(true)));
  }
}
