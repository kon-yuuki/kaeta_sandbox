class AppConfig {
  // --- Supabase関連 ---
  // main.dart で使用
  //プロジェクトURLのスラッグを用いて
  //https://スラッグ.supabase.co
  static const String supabaseUrl = 'https://fkkvqxbzvysimylzedus.supabase.co';

  //ダッシュボード>/settings/api-keys/legacy
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3ZxeGJ6dnlzaW15bHplZHVzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwODcxODQsImV4cCI6MjA4MjY2MzE4NH0.fuE1weK4CkWhy4OFJ-Nwiwimv435985WmtxB9o2dxpU';

  // --- PowerSync関連 ---
  // powersync_connector.dart で使用
  //ダッシュボード>project>ヘッダーのConnectボタンを押したモーダル内(Instance URL)
  static const String powerSyncUrl = 'https://6954c9ea7e2a07e6df81a108.powersync.journeyapps.com';

  // --- メモ：アカウント切り替え時に手動更新が必要な場所 ---
  // 1. ios/Runner/Info.plist の CFBundleURLSchemes (Google Auth用)
}