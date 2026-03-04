import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notification_service.dart';

class DeviceTokensRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> upsertCurrentDeviceToken({required String userId}) async {
    try {
      final token = await NotificationService().getCurrentPushToken();
      if (token == null || token.isEmpty) {
        debugPrint('FCM token is empty. Skip device token upsert.');
        return;
      }

      await _supabase.from('device_tokens').upsert({
        'user_id': userId,
        'fcm_token': token,
        'platform': 'ios',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,fcm_token');
      debugPrint('Upserted device_tokens row. userId=$userId');
    } catch (e, st) {
      debugPrint('Failed to upsert device token. userId=$userId error=$e');
      debugPrint('$st');
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
