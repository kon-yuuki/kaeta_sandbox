import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConnector extends PowerSyncBackendConnector {
  final SupabaseClient supabase;

  SupabaseConnector(this.supabase);

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final session = supabase.auth.currentSession;
    if (session == null) return null;

    return PowerSyncCredentials(
      endpoint: 'ここにPowerSyncのInstance URLを貼り付けてください',
      token: session.accessToken,
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    // 💡 あとで「スマホでの変更をSupabaseへ送る」処理をここに書きます
  }
}