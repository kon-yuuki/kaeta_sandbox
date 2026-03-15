import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_config.dart';

class PushDebugLogRepository {
  Future<void> log({
    required String userId,
    required String step,
    String? status,
    String? error,
    String? tokenPrefix,
    String? source,
  }) async {
    if (!AppConfig.enablePushDebugLogging) return;

    try {
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint(
          'Skip push_debug_logs write without current user. '
          'requestedUserId=$userId step=$step source=$source',
        );
        return;
      }
      if (currentUserId != userId) {
        debugPrint(
          'Skip push_debug_logs write due to user mismatch. '
          'requestedUserId=$userId currentUserId=$currentUserId step=$step source=$source',
        );
        return;
      }
      await supabase.from('push_debug_logs').insert({
        'user_id': userId,
        'step': step,
        'status': status,
        'error': error,
        'token_prefix': tokenPrefix,
        'source': source,
      });
    } catch (e) {
      // Debug logの失敗は本処理を止めない
      debugPrint(
        'Failed to write push_debug_logs: userId=$userId step=$step source=$source error=$e',
      );
    }
  }
}
