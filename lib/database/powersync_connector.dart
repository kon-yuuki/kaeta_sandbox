import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      // 💡 前のステップで控えた PowerSync の Instance URL
      endpoint: 'https://6954c9ea7e2a07e6df81a108.powersync.journeyapps.com', 
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
          // 💡 user_id は Supabase 側のデフォルト値(auth.uid())に任せるか、
          // 明示的に入れる場合はここで追加します
          await table.upsert(data);
        } else if (op.op == UpdateType.patch) {
          await table.update(op.opData!).eq('id', op.id);
        } else if (op.op == UpdateType.delete) {
          await table.delete().eq('id', op.id);
        }
      }
      await transaction.complete();
    } on PostgrestException catch (e) {
      // 致命的なエラー（型違いなど）の場合は、その変更を破棄してキューを進める
      // そうしないと同期がそこで止まってしまうためです
      if (e.code == '42501' || e.code?.startsWith('23') == true) {
        await transaction.complete();
      } else {
        rethrow;
      }
    }
  }
}