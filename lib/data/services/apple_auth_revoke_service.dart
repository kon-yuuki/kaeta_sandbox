import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppleAuthRevokeService {
  AppleAuthRevokeService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<void> storeAuthorizationCode(String authorizationCode) async {
    if (authorizationCode.trim().isEmpty) return;
    try {
      await _supabase.functions.invoke(
        'apple-auth-revoke',
        body: {'action': 'store', 'authorizationCode': authorizationCode},
      );
    } catch (e) {
      debugPrint('apple-auth-revoke store failed: $e');
    }
  }

  Future<void> revokeCurrentUserToken({bool rethrowOnError = false}) async {
    try {
      await _supabase.functions.invoke(
        'apple-auth-revoke',
        body: {'action': 'revoke'},
      );
    } catch (e) {
      debugPrint('apple-auth-revoke revoke failed: $e');
      if (rethrowOnError) rethrow;
    }
  }
}
