import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
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

  Expression<bool> _visibleToCurrentUserFilter(
    $AppNotificationsTable t,
    String userId,
    String? familyId,
  ) {
    final base = t.userId.equals(userId);
    if (familyId == null || familyId.isEmpty) {
      return base;
    }
    // 家族通知では、自分が実行者の通知は表示対象から外す。
    final hideOwnAction = t.actorUserId.isNull() | t.actorUserId.equals(userId).not();
    return base & (t.familyId.equals(familyId) | t.familyId.isNull()) & hideOwnAction;
  }

  Future<void> notifyShoppingCompleted({
    required String itemName,
    required String? familyId,
  }) async {
    final message = '「$itemName」を完了しました！';

    // 個人利用時はローカル通知として追加
    if (familyId == null || familyId.isEmpty) {
      await addNotification(
        message,
        type: NotificationType.shoppingComplete,
        familyId: null,
      );
      return;
    }

    // 家族利用時はサーバー側RPCで家族メンバーへ配信（本人分も作成）
    try {
      await supabase.rpc(
        'notify_family_members',
        params: {
          'p_family_id': familyId,
          'p_message': message,
          'p_type': NotificationType.shoppingComplete,
        },
      );
    } on PostgrestException catch (e) {
      debugPrint(
        'notify_family_members failed: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}',
      );
      // RPC失敗時のフォールバック: 実行者自身の通知だけは残す
      await addNotification(
        message,
        type: NotificationType.shoppingComplete,
        familyId: familyId,
      );
    }
  }

  // 通知を追加
  Future<void> addNotification(
    String message, {
    int type = 0,
    String? familyId,
    String? actorUserId,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await db.into(db.appNotifications).insert(
      AppNotificationsCompanion.insert(
        message: message,
        type: Value(type),
        userId: userId,
        actorUserId: Value(actorUserId ?? userId),
        eventId: Value(const Uuid().v4()),
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
            return _visibleToCurrentUserFilter(t, userId, familyId);
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
            return _visibleToCurrentUserFilter(t, userId, familyId);
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
            final base = t.userId.equals(userId);
            if (familyId == null || familyId.isEmpty) {
              return base;
            }
            return base &
                (t.familyId.equals(familyId) | t.familyId.isNull());
          }))
        .go();
  }

  // 個別の通知を削除
  Future<void> deleteNotification(String id) async {
    await (db.delete(db.appNotifications)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  // 通知リアクション（絵文字）を更新
  Future<void> setNotificationReaction({
    required String notificationId,
    String? reactionEmoji,
  }) async {
    try {
      await supabase.rpc(
        'set_notification_reaction',
        params: {
          'p_notification_id': notificationId,
          'p_emoji': reactionEmoji,
        },
      );
    } on PostgrestException catch (e) {
      debugPrint(
        'set_notification_reaction failed: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}',
      );
      rethrow;
    }
  }

  Stream<List<AppNotificationReaction>> watchReactions(String? familyId) {
    if (familyId == null || familyId.isEmpty) return Stream.value(const []);
    return (db.select(db.appNotificationReactions)
          ..where((t) => t.familyId.equals(familyId)))
        .watch();
  }

  // 未読通知の数を監視（familyIdでフィルタ）
  Stream<int> watchUnreadCount(String? familyId) {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value(0);

    final query = db.selectOnly(db.appNotifications)
      ..addColumns([db.appNotifications.id.count()])
      ..where(() {
        return _visibleToCurrentUserFilter(
              db.appNotifications,
              userId,
              familyId,
            ) &
            db.appNotifications.isRead.equals(false);
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
            return _visibleToCurrentUserFilter(t, userId, familyId) &
                t.isRead.equals(false);
          }))
        .write(const AppNotificationsCompanion(isRead: Value(true)));
  }
}
