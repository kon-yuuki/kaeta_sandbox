import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../model/database.dart';
import 'push_debug_log_repository.dart';

// 通知タイプ
class NotificationType {
  static const int normal = 0; // 通常通知（30日保持）
  static const int shoppingComplete = 1; // 買い物完了（7日保持）
  static const int shoppingAllCompleted = 2; // 買い物全件完了（7日保持）
  static const int reminder = 3; // アプリ内リマインド（30日保持）
}

class _QueuedNotificationRequest {
  const _QueuedNotificationRequest({
    required this.id,
    required this.primaryRpc,
    required this.params,
    required this.familyId,
    required this.logStep,
    this.fallbackRpc,
    this.fallbackParams,
    this.attemptCount = 0,
    this.lastError,
    this.createdAtIso8601,
    this.lastAttemptAtIso8601,
  });

  final String id;
  final String primaryRpc;
  final Map<String, dynamic> params;
  final String familyId;
  final String logStep;
  final String? fallbackRpc;
  final Map<String, dynamic>? fallbackParams;
  final int attemptCount;
  final String? lastError;
  final String? createdAtIso8601;
  final String? lastAttemptAtIso8601;

  Map<String, dynamic> toJson() => {
    'id': id,
    'primaryRpc': primaryRpc,
    'params': params,
    'familyId': familyId,
    'logStep': logStep,
    'fallbackRpc': fallbackRpc,
    'fallbackParams': fallbackParams,
    'attemptCount': attemptCount,
    'lastError': lastError,
    'createdAtIso8601': createdAtIso8601,
    'lastAttemptAtIso8601': lastAttemptAtIso8601,
  };

  factory _QueuedNotificationRequest.fromJson(Map<String, dynamic> json) {
    return _QueuedNotificationRequest(
      id: json['id']?.toString() ?? const Uuid().v4(),
      primaryRpc: json['primaryRpc']?.toString() ?? 'notify_family_members',
      params: Map<String, dynamic>.from(json['params'] as Map? ?? const {}),
      familyId: json['familyId']?.toString() ?? '',
      logStep: json['logStep']?.toString() ?? 'notify_family_members_generic',
      fallbackRpc: json['fallbackRpc']?.toString(),
      fallbackParams: json['fallbackParams'] == null
          ? null
          : Map<String, dynamic>.from(json['fallbackParams'] as Map),
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      lastError: json['lastError']?.toString(),
      createdAtIso8601: json['createdAtIso8601']?.toString(),
      lastAttemptAtIso8601: json['lastAttemptAtIso8601']?.toString(),
    );
  }

  _QueuedNotificationRequest copyWith({
    int? attemptCount,
    String? lastError,
    String? lastAttemptAtIso8601,
  }) {
    return _QueuedNotificationRequest(
      id: id,
      primaryRpc: primaryRpc,
      params: params,
      familyId: familyId,
      logStep: logStep,
      fallbackRpc: fallbackRpc,
      fallbackParams: fallbackParams,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      createdAtIso8601: createdAtIso8601,
      lastAttemptAtIso8601: lastAttemptAtIso8601 ?? this.lastAttemptAtIso8601,
    );
  }
}

class NotificationsRepository {
  final MyDatabase db;
  final supabase = Supabase.instance.client;
  final _pushDebugLogRepository = PushDebugLogRepository();
  static const _queuedNotificationRequestsKey =
      'queued_family_notification_requests_v1';
  static const _batchedItemAddedRpc =
      'notify_family_members_item_added_batched';
  static const _shoppingAllCompletedRpc =
      'notify_family_members_shopping_all_completed';
  static const _shoppingCompletedRpc =
      'notify_family_members_shopping_completed_batched';
  static const _itemEditedRpc = 'notify_family_members_item_edited';
  static const _itemDeletedRpc = 'notify_family_members_item_deleted';
  static const _boardUpdatedRpc = 'notify_family_members_board_updated';
  static const _teamJoinedRpc = 'notify_family_members_team_joined';
  static const _teamLeftRpc = 'notify_family_members_team_left';
  static const _teamDeletedRpc = 'notify_family_members_team_deleted';
  static const _removedFromTeamRpc = 'notify_user_removed_from_team';
  Future<void>? _flushInFlight;

  NotificationsRepository(this.db);

  Future<void> _logQueueEvent({
    required String step,
    required String status,
    String? error,
    String? familyId,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _pushDebugLogRepository.log(
      userId: userId,
      step: step,
      status: status,
      error: error == null ? familyId : 'familyId=$familyId, $error',
      source: 'notifications_queue',
    );
  }

  Future<List<_QueuedNotificationRequest>> _loadQueuedRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_queuedNotificationRequestsKey) ?? [];
    final requests = <_QueuedNotificationRequest>[];
    for (final raw in rawItems) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) continue;
        requests.add(_QueuedNotificationRequest.fromJson(decoded));
      } catch (_) {
        // 壊れた1件で全キューを止めない。
      }
    }
    return requests;
  }

  Future<void> _saveQueuedRequests(
    List<_QueuedNotificationRequest> requests,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _queuedNotificationRequestsKey,
      requests.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  bool _isTransientRpcError(Object error) {
    return error is SocketException ||
        error is TimeoutException ||
        error is ClientException;
  }

  Future<void> _enqueueQueuedRequest(_QueuedNotificationRequest request) async {
    final requests = await _loadQueuedRequests();
    final duplicateIndex = requests.indexWhere(
      (item) =>
          item.primaryRpc == request.primaryRpc &&
          item.familyId == request.familyId &&
          mapEquals(item.params, request.params),
    );
    if (duplicateIndex >= 0) {
      requests[duplicateIndex] = requests[duplicateIndex].copyWith(
        attemptCount: requests[duplicateIndex].attemptCount,
        lastError: request.lastError,
        lastAttemptAtIso8601: request.lastAttemptAtIso8601,
      );
    } else {
      requests.add(request);
    }
    await _saveQueuedRequests(requests);
    await _logQueueEvent(
      step: '${request.logStep}_queued',
      status: 'pending',
      error: request.lastError,
      familyId: request.familyId,
    );
  }

  Future<void> _sendFamilyRpc({
    required String primaryRpc,
    required Map<String, dynamic> params,
    required String familyId,
    required String logStep,
    String? fallbackRpc,
    Map<String, dynamic>? fallbackParams,
  }) async {
    try {
      await supabase.rpc(primaryRpc, params: params);
    } on PostgrestException catch (e) {
      if (fallbackRpc != null && _isMissingRpc(e)) {
        await supabase.rpc(fallbackRpc, params: fallbackParams ?? params);
        return;
      }
      rethrow;
    } on Object catch (e) {
      if (!_isTransientRpcError(e)) rethrow;

      final request = _QueuedNotificationRequest(
        id: const Uuid().v4(),
        primaryRpc: primaryRpc,
        params: params,
        familyId: familyId,
        logStep: logStep,
        fallbackRpc: fallbackRpc,
        fallbackParams: fallbackParams,
        lastError: e.toString(),
        createdAtIso8601: DateTime.now().toIso8601String(),
        lastAttemptAtIso8601: DateTime.now().toIso8601String(),
      );
      await _enqueueQueuedRequest(request);
    }
  }

  Future<void> flushQueuedNotifications() {
    final inFlight = _flushInFlight;
    if (inFlight != null) return inFlight;

    final future = _flushQueuedNotificationsImpl();
    _flushInFlight = future;
    return future.whenComplete(() {
      if (identical(_flushInFlight, future)) {
        _flushInFlight = null;
      }
    });
  }

  Future<void> _flushQueuedNotificationsImpl() async {
    final requests = await _loadQueuedRequests();
    if (requests.isEmpty) return;

    final remaining = <_QueuedNotificationRequest>[];
    for (final request in requests) {
      try {
        await _sendFamilyRpc(
          primaryRpc: request.primaryRpc,
          params: request.params,
          familyId: request.familyId,
          logStep: request.logStep,
          fallbackRpc: request.fallbackRpc,
          fallbackParams: request.fallbackParams,
        );
        await _logQueueEvent(
          step: '${request.logStep}_flush',
          status: 'sent',
          familyId: request.familyId,
        );
      } on PostgrestException catch (e) {
        await _logFamilyNotifyFailure(
          step: request.logStep,
          error: e,
          familyId: request.familyId,
        );
      } on Object catch (e) {
        if (_isTransientRpcError(e)) {
          remaining.add(
            request.copyWith(
              attemptCount: request.attemptCount + 1,
              lastError: e.toString(),
              lastAttemptAtIso8601: DateTime.now().toIso8601String(),
            ),
          );
          continue;
        }
        await _logQueueEvent(
          step: '${request.logStep}_flush',
          status: 'dropped',
          error: e.toString(),
          familyId: request.familyId,
        );
      }
    }

    await _saveQueuedRequests(remaining);
  }

  Future<void> _logFamilyNotifyFailure({
    required String step,
    required PostgrestException error,
    required String? familyId,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _pushDebugLogRepository.log(
      userId: userId,
      step: step,
      status: 'error',
      error:
          'familyId=$familyId, code=${error.code}, message=${error.message}, details=${error.details}, hint=${error.hint}',
      source: 'notifications_repository',
    );
  }

  Expression<bool> _visibleToCurrentUserFilter(
    $AppNotificationsTable t,
    String userId,
    String? familyId,
  ) {
    final base = t.userId.equals(userId);
    if (familyId == null || familyId.isEmpty) {
      return base & t.familyId.isNull();
    }
    // 家族通知では、自分が実行者の通知は表示対象から外す。
    final hideOwnAction =
        t.actorUserId.isNull() | t.actorUserId.equals(userId).not();
    return base & t.familyId.equals(familyId) & hideOwnAction;
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
      await _notifyShoppingCompletedForFamily(
        familyId: familyId,
        message: message,
        completedCount: 1,
      );
    } on PostgrestException catch (e) {
      debugPrint(
        'notify_family_members failed: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}',
      );
      await _logFamilyNotifyFailure(
        step: 'notify_family_members_shopping_complete',
        error: e,
        familyId: familyId,
      );
    }
  }

  Future<void> _notifyShoppingCompletedForFamily({
    required String familyId,
    required String message,
    required int completedCount,
  }) async {
    await _sendFamilyRpc(
      primaryRpc: _shoppingCompletedRpc,
      params: {
        'p_family_id': familyId,
        'p_message': message,
        'p_type': NotificationType.shoppingComplete,
        'p_completed_count': completedCount,
      },
      familyId: familyId,
      logStep: 'notify_family_members_shopping_complete',
      fallbackRpc: 'notify_family_members',
      fallbackParams: {
        'p_family_id': familyId,
        'p_message': message,
        'p_type': NotificationType.shoppingComplete,
      },
    );
  }

  Future<void> notifyShoppingAdded({
    required String itemName,
    required String? familyId,
  }) async {
    final message = '「$itemName」をリストに追加しました！';

    if (familyId == null || familyId.isEmpty) {
      await addNotification(
        message,
        type: NotificationType.normal,
        familyId: null,
      );
      return;
    }

    try {
      await _notifyShoppingAddedForFamily(familyId: familyId, message: message);
    } on PostgrestException catch (e) {
      debugPrint(
        'notify_family_members(add) failed: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}',
      );
      await _logFamilyNotifyFailure(
        step: 'notify_family_members_shopping_added',
        error: e,
        familyId: familyId,
      );
    }
  }

  Future<void> _notifyShoppingAddedForFamily({
    required String familyId,
    required String message,
  }) async {
    await _sendFamilyRpc(
      primaryRpc: _batchedItemAddedRpc,
      params: {
        'p_family_id': familyId,
        'p_message': message,
        'p_type': NotificationType.normal,
      },
      familyId: familyId,
      logStep: 'notify_family_members_shopping_added',
      fallbackRpc: 'notify_family_members',
      fallbackParams: {
        'p_family_id': familyId,
        'p_message': message,
        'p_type': NotificationType.normal,
      },
    );
  }

  bool _isMissingRpc(PostgrestException error) {
    final code = error.code?.toUpperCase();
    if (code == 'PGRST202' || code == '42883') {
      return true;
    }

    final message = error.message.toLowerCase();
    return message.contains('could not find the function') ||
        message.contains('function public.$_batchedItemAddedRpc') ||
        message.contains('does not exist');
  }

  Future<void> notifyShoppingAllCompleted({
    required String? familyId,
    required String firstItemName,
    required int completedCount,
  }) async {
    const message = '買い物リストのアイテムがすべて購入されました！';

    if (familyId == null || familyId.isEmpty) {
      await addNotification(
        message,
        type: NotificationType.shoppingAllCompleted,
        familyId: null,
      );
      return;
    }

    try {
      await _notifyShoppingAllCompletedForFamily(
        familyId: familyId,
        message: message,
        firstItemName: firstItemName,
        completedCount: completedCount,
      );
    } on PostgrestException catch (e) {
      debugPrint(
        'notify_family_members(all completed) failed: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}',
      );
      await _logFamilyNotifyFailure(
        step: 'notify_family_members_shopping_all_completed',
        error: e,
        familyId: familyId,
      );
    }
  }

  Future<void> notifyItemEdited({
    required String itemName,
    required String? familyId,
  }) async {
    final message = '「$itemName」を編集しました';

    if (familyId == null || familyId.isEmpty) {
      await addNotification(
        message,
        type: NotificationType.normal,
        familyId: null,
      );
      return;
    }

    try {
      await _notifyItemEditedForFamily(
        familyId: familyId,
        message: message,
        itemName: itemName,
      );
    } on PostgrestException catch (e) {
      debugPrint(
        'notify_family_members(item edited) failed: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}',
      );
      await _logFamilyNotifyFailure(
        step: 'notify_family_members_item_edited',
        error: e,
        familyId: familyId,
      );
    }
  }

  Future<void> notifyItemDeleted({
    required String itemName,
    required String? familyId,
  }) async {
    final message = '「$itemName」を削除しました';

    if (familyId == null || familyId.isEmpty) {
      await addNotification(
        message,
        type: NotificationType.normal,
        familyId: null,
      );
      return;
    }

    try {
      await _notifyItemDeletedForFamily(
        familyId: familyId,
        message: message,
        itemName: itemName,
      );
    } on PostgrestException catch (e) {
      debugPrint(
        'notify_family_members(item deleted) failed: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}',
      );
      await _logFamilyNotifyFailure(
        step: 'notify_family_members_item_deleted',
        error: e,
        familyId: familyId,
      );
    }
  }

  Future<void> notifyTeamJoined({required String familyId}) async {
    const message = 'チームに参加しました';
    try {
      await _sendFamilyRpc(
        primaryRpc: _teamJoinedRpc,
        params: {
          'p_family_id': familyId,
          'p_message': message,
          'p_type': NotificationType.normal,
        },
        familyId: familyId,
        logStep: 'notify_family_members_team_joined',
        fallbackRpc: 'notify_family_members',
        fallbackParams: {
          'p_family_id': familyId,
          'p_message': message,
          'p_type': NotificationType.normal,
        },
      );
    } on PostgrestException catch (e) {
      debugPrint(
        'notify_family_members(team joined) failed: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}',
      );
      await _logFamilyNotifyFailure(
        step: 'notify_family_members_team_joined',
        error: e,
        familyId: familyId,
      );
    }
  }

  Future<void> notifyTeamLeft({required String familyId}) async {
    const message = 'チームを退出しました';
    try {
      await _sendFamilyRpc(
        primaryRpc: _teamLeftRpc,
        params: {
          'p_family_id': familyId,
          'p_message': message,
          'p_type': NotificationType.normal,
        },
        familyId: familyId,
        logStep: 'notify_family_members_team_left',
        fallbackRpc: 'notify_family_members',
        fallbackParams: {
          'p_family_id': familyId,
          'p_message': message,
          'p_type': NotificationType.normal,
        },
      );
    } on PostgrestException catch (e) {
      debugPrint(
        'notify_family_members(team left) failed: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}',
      );
      await _logFamilyNotifyFailure(
        step: 'notify_family_members_team_left',
        error: e,
        familyId: familyId,
      );
    }
  }

  Future<void> notifyTeamDeleted({required String familyId}) async {
    const message = 'チームを削除しました';
    try {
      await _sendFamilyRpc(
        primaryRpc: _teamDeletedRpc,
        params: {
          'p_family_id': familyId,
          'p_message': message,
          'p_type': NotificationType.normal,
        },
        familyId: familyId,
        logStep: 'notify_family_members_team_deleted',
        fallbackRpc: 'notify_family_members',
        fallbackParams: {
          'p_family_id': familyId,
          'p_message': message,
          'p_type': NotificationType.normal,
        },
      );
    } on PostgrestException catch (e) {
      debugPrint(
        'notify_family_members(team deleted) failed: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}',
      );
      await _logFamilyNotifyFailure(
        step: 'notify_family_members_team_deleted',
        error: e,
        familyId: familyId,
      );
    }
  }

  Future<void> notifyRemovedFromTeam({
    required String familyId,
    required String removedUserId,
    required String teamName,
  }) async {
    try {
      await _sendFamilyRpc(
        primaryRpc: _removedFromTeamRpc,
        params: {
          'p_family_id': familyId,
          'p_removed_user_id': removedUserId,
          'p_team_name': teamName,
          'p_type': NotificationType.normal,
        },
        familyId: familyId,
        logStep: 'notify_user_removed_from_team',
      );
    } on PostgrestException catch (e) {
      debugPrint(
        'notify_user_removed_from_team failed: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}',
      );
      await _logFamilyNotifyFailure(
        step: 'notify_user_removed_from_team',
        error: e,
        familyId: familyId,
      );
    }
  }

  Future<void> _notifyShoppingAllCompletedForFamily({
    required String familyId,
    required String message,
    required String firstItemName,
    required int completedCount,
  }) async {
    await _sendFamilyRpc(
      primaryRpc: _shoppingAllCompletedRpc,
      params: {
        'p_family_id': familyId,
        'p_message': message,
        'p_type': NotificationType.shoppingAllCompleted,
        'p_first_item_name': firstItemName,
        'p_completed_count': completedCount,
      },
      familyId: familyId,
      logStep: 'notify_family_members_shopping_all_completed',
      fallbackRpc: 'notify_family_members',
      fallbackParams: {
        'p_family_id': familyId,
        'p_message': message,
        'p_type': NotificationType.shoppingAllCompleted,
      },
    );
  }

  Future<void> _notifyItemEditedForFamily({
    required String familyId,
    required String message,
    required String itemName,
  }) async {
    await _sendFamilyRpc(
      primaryRpc: _itemEditedRpc,
      params: {
        'p_family_id': familyId,
        'p_message': message,
        'p_type': NotificationType.normal,
        'p_item_name': itemName,
      },
      familyId: familyId,
      logStep: 'notify_family_members_item_edited',
      fallbackRpc: 'notify_family_members',
      fallbackParams: {
        'p_family_id': familyId,
        'p_message': message,
        'p_type': NotificationType.normal,
      },
    );
  }

  Future<void> _notifyItemDeletedForFamily({
    required String familyId,
    required String message,
    required String itemName,
  }) async {
    await _sendFamilyRpc(
      primaryRpc: _itemDeletedRpc,
      params: {
        'p_family_id': familyId,
        'p_message': message,
        'p_type': NotificationType.normal,
        'p_item_name': itemName,
      },
      familyId: familyId,
      logStep: 'notify_family_members_item_deleted',
      fallbackRpc: 'notify_family_members',
      fallbackParams: {
        'p_family_id': familyId,
        'p_message': message,
        'p_type': NotificationType.normal,
      },
    );
  }

  Future<void> notifyBoardUpdated({
    required String actorName,
    required String boardMessage,
    required String? familyId,
  }) async {
    final trimmed = boardMessage.trim();
    final preview = trimmed.length > 20 ? trimmed.substring(0, 20) : trimmed;
    final suffix = trimmed.length > 20 ? '…' : '';
    final message = '$actorNameさんがひとことを更新: $preview$suffix';

    debugPrint(
      'F12 notifyBoardUpdated called: familyId=$familyId, actorName=$actorName, trimmed="$trimmed", message="$message"',
    );

    if (familyId == null || familyId.isEmpty) {
      debugPrint('F12 notifyBoardUpdated local notification path');
      await addNotification(
        message,
        type: NotificationType.normal,
        familyId: null,
      );
      return;
    }

    try {
      debugPrint(
        'F12 notifyBoardUpdated rpc start: familyId=$familyId, type=${NotificationType.normal}',
      );
      await _sendFamilyRpc(
        primaryRpc: _boardUpdatedRpc,
        params: {
          'p_family_id': familyId,
          'p_message': message,
          'p_type': NotificationType.normal,
          'p_board_message': trimmed,
        },
        familyId: familyId,
        logStep: 'notify_family_members_board_updated',
        fallbackRpc: 'notify_family_members',
        fallbackParams: {
          'p_family_id': familyId,
          'p_message': message,
          'p_type': NotificationType.normal,
        },
      );
      debugPrint('F12 notifyBoardUpdated rpc success: familyId=$familyId');
    } on PostgrestException catch (e) {
      debugPrint(
        'notify_family_members(board updated) failed: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}',
      );
      await _logFamilyNotifyFailure(
        step: 'notify_family_members_board_updated',
        error: e,
        familyId: familyId,
      );
      rethrow;
    }
  }

  Future<void> publishNotification({
    required String message,
    int type = NotificationType.normal,
    String? familyId,
    String? actorUserId,
  }) async {
    if (familyId == null || familyId.isEmpty) {
      await addNotification(
        message,
        type: type,
        familyId: null,
        actorUserId: actorUserId,
      );
      return;
    }

    try {
      await _sendFamilyRpc(
        primaryRpc: 'notify_family_members',
        params: {'p_family_id': familyId, 'p_message': message, 'p_type': type},
        familyId: familyId,
        logStep: 'notify_family_members_generic',
      );
    } on PostgrestException catch (e) {
      debugPrint(
        'notify_family_members(generic) failed: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}',
      );
      await _logFamilyNotifyFailure(
        step: 'notify_family_members_generic',
        error: e,
        familyId: familyId,
      );
      rethrow;
    }
  }

  // 通知を追加
  Future<void> addNotification(
    String message, {
    int type = 0,
    String? familyId,
    String? actorUserId,
    String? title,
    String? body,
    String? eventId,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    if (eventId != null && eventId.isNotEmpty) {
      final existing = await (db.select(db.appNotifications)..where(
            (t) => t.userId.equals(userId) & t.eventId.equals(eventId),
          ))
          .getSingleOrNull();
      if (existing != null) return;
    }

    await db
        .into(db.appNotifications)
        .insert(
          AppNotificationsCompanion.insert(
            message: message,
            title: Value(title),
            body: Value(body),
            type: Value(type),
            userId: userId,
            actorUserId: Value(actorUserId ?? userId),
            eventId: Value(
              eventId != null && eventId.isNotEmpty ? eventId : const Uuid().v4(),
            ),
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
    await (db.delete(db.appNotifications)..where(
          (t) =>
              t.userId.equals(userId) &
              (t.type.equals(NotificationType.normal) |
                  t.type.equals(NotificationType.reminder)) &
              t.createdAt.isSmallerThanValue(normalCutoff),
        ))
        .go();

    // 買い物系通知: 7日以上前のものを削除
    final shoppingCutoff = now.subtract(const Duration(days: 7));
    await (db.delete(db.appNotifications)..where(
          (t) =>
              t.userId.equals(userId) &
              (t.type.equals(NotificationType.shoppingComplete) |
                  t.type.equals(NotificationType.shoppingAllCompleted)) &
              t.createdAt.isSmallerThanValue(shoppingCutoff),
        ))
        .go();
  }

  // すべての通知を削除（familyIdでフィルタ）
  Future<void> clearAllNotifications(String? familyId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await (db.delete(db.appNotifications)..where((t) {
          return _visibleToCurrentUserFilter(t, userId, familyId);
        }))
        .go();
  }

  // 個別の通知を削除
  Future<void> deleteNotification(String id) async {
    await (db.delete(db.appNotifications)..where((t) => t.id.equals(id))).go();
  }

  // 通知リアクション（絵文字）を更新
  Future<void> setNotificationReaction({
    required String notificationId,
    String? reactionEmoji,
  }) async {
    try {
      await supabase.rpc(
        'set_notification_reaction',
        params: {'p_notification_id': notificationId, 'p_emoji': reactionEmoji},
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
    return (db.select(
      db.appNotificationReactions,
    )..where((t) => t.familyId.equals(familyId))).watch();
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

    await (db.update(db.appNotifications)..where((t) {
          return _visibleToCurrentUserFilter(t, userId, familyId) &
              t.isRead.equals(false);
        }))
        .write(const AppNotificationsCompanion(isRead: Value(true)));
  }

  Future<void> markEventAsRead(String eventId) async {
    if (eventId.isEmpty) return;
    await (db.update(db.appNotifications)
          ..where((t) => t.eventId.equals(eventId) & t.isRead.equals(false)))
        .write(const AppNotificationsCompanion(isRead: Value(true)));
  }
}
