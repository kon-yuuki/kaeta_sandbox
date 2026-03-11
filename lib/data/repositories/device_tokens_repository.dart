import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notification_service.dart';
import 'push_debug_log_repository.dart';

class DeviceTokensRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final PushDebugLogRepository _pushDebugLogRepository =
      PushDebugLogRepository();

  Future<void> upsertCurrentDeviceToken({required String userId}) async {
    try {
      await _pushDebugLogRepository.log(
        userId: userId,
        step: 'get_token_start',
        status: 'started',
        source: 'device_tokens_repository',
      );

      final tokenResult = await NotificationService()
          .getCurrentPushTokenWithDiagnostics();
      final token = tokenResult.token;
      if (token == null || token.isEmpty) {
        debugPrint('FCM token is empty. Skip device token upsert.');
        await _pushDebugLogRepository.log(
          userId: userId,
          step: 'get_token_result',
          status: 'empty',
          error:
              'reason=${tokenResult.reason ?? 'unknown'},'
              'permission=${tokenResult.permissionStatus},'
              'firebase_initialized=${tokenResult.firebaseInitialized},'
              'apns_token_present=${tokenResult.apnsTokenPresent}',
          source: 'device_tokens_repository',
        );
        return;
      }

      final tokenPrefix = token.substring(
        0,
        token.length > 16 ? 16 : token.length,
      );
      debugPrint(
        'Device token upsert target. userId=$userId tokenPrefix=$tokenPrefix',
      );
      await _pushDebugLogRepository.log(
        userId: userId,
        step: 'get_token_result',
        status: 'ok',
        tokenPrefix: tokenPrefix,
        source: 'device_tokens_repository',
      );

      await _supabase.from('device_tokens').upsert({
        'user_id': userId,
        'fcm_token': token,
        'platform': 'ios',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,fcm_token');
      debugPrint('Upserted device_tokens row. userId=$userId');
      await _pushDebugLogRepository.log(
        userId: userId,
        step: 'upsert_device_tokens',
        status: 'ok',
        tokenPrefix: tokenPrefix,
        source: 'device_tokens_repository',
      );
    } catch (e, st) {
      debugPrint('Failed to upsert device token. userId=$userId error=$e');
      debugPrint('$st');
      await _pushDebugLogRepository.log(
        userId: userId,
        step: 'upsert_device_tokens',
        status: 'error',
        error: e.toString(),
        source: 'device_tokens_repository',
      );
      rethrow;
    }
  }

  Future<void> deleteCurrentDeviceToken({required String userId}) async {
    try {
      final token = await NotificationService().getCurrentPushToken();
      if (token == null || token.isEmpty) return;

      await _supabase
          .from('device_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('fcm_token', token);
      debugPrint('Deleted device_tokens row. userId=$userId');
    } catch (e, st) {
      debugPrint('Failed to delete device token. userId=$userId error=$e');
      debugPrint('$st');
    }
  }
}
