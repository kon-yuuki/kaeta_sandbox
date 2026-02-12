import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '/core/app_config.dart';

/// Supabase と PowerSync を繋ぐコネクター
class SupabaseConnector extends PowerSyncBackendConnector {
  final SupabaseClient supabase;
  Future<void>? _refreshFuture;

  SupabaseConnector(this.supabase);

  /// PowerSync サーバーへのログイン情報を取得
  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    await _refreshFuture;
    final session = supabase.auth.currentSession;
    if (session == null) return null;

    return PowerSyncCredentials(
      endpoint: AppConfig.powerSyncUrl,
      token: session.accessToken,
    );
  }

  /// 認証失敗時にセッションをリフレッシュする
  @override
  void invalidateCredentials() {
    _refreshFuture = supabase.auth
        .refreshSession()
        .timeout(const Duration(seconds: 5))
        .then((_) => null, onError: (_) => null);
  }

  /// 💡 重要：スマホでの変更を Supabase へ書き戻す処理
  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    final rest = supabase.rest;
    try {
      for (var op in transaction.crud) {
        final table = rest.from(op.table);
        if (op.op == UpdateType.put) {
          var data = Map<String, dynamic>.of(op.opData!);
          data['id'] = op.id;
          // purchase_history はユーザー単位で重複解決する。
          // name単独だと他ユーザーの行と衝突してRLS違反になるため、
          // name,user_id を競合キーにする。
          if (op.table == 'purchase_history') {
            await table.upsert(data, onConflict: 'name,user_id');
          } else {
            // 💡 user_id は Supabase 側のデフォルト値(auth.uid())に任せるか、
            // 明示的に入れる場合はここで追加します
            await table.upsert(data);
          }
        } else if (op.op == UpdateType.patch) {
          await table.update(op.opData!).eq('id', op.id);
        } else if (op.op == UpdateType.delete) {
          await table.delete().eq('id', op.id);
        }
      }
      await transaction.complete();
    } on PostgrestException catch (e) {
      debugPrint(
        'PowerSync upload failed: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}',
      );
      rethrow;
    }
  }
}
