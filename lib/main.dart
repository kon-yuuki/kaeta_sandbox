import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/todo/views/todo_page.dart';
import 'features/todo/views/login_page.dart';

Future<void> main() async {
  // ① Flutterの初期化
  WidgetsFlutterBinding.ensureInitialized();

  // ② Supabaseを初期化（手動同期ボタンのために残します）
  await Supabase.initialize(
    url: 'https://fkkvqxbzvysimylzedus.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3ZxeGJ6dnlzaW15bHplZHVzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwODcxODQsImV4cCI6MjA4MjY2MzE4NH0.fuE1weK4CkWhy4OFJ-Nwiwimv435985WmtxB9o2dxpU',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  // 💡 PowerSync の初期化、接続、Drift への注入はすべて不要になりました。
  // データベースの作成は todo_provider.dart 側で行われます。

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // 認証イベントを詳細に追跡
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      print("----------------------------------");
      print("【ログ1】認証イベント発生: ${data.event}");
      print("【ログ2】セッションの有無: ${data.session != null}");
      if (data.session != null) {
        print("【ログ3】ログインユーザー: ${data.session!.user.email}");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ... theme等の設定 ...
      home: Builder(
        builder: (context) {
          print("【ログA】MaterialAppの再描画が発生しました");
          return StreamBuilder<AuthState>(
            stream: Supabase.instance.client.auth.onAuthStateChange,
            builder: (context, snapshot) {
              final session = snapshot.data?.session;
              print("【ログB】StreamBuilderが反応: セッション = ${session != null}");

              if (session != null) {
                print("【ログC】TodoPageを表示しようとしています");
                return const TodoPage();
              } else {
                print("【ログD】LoginPageを表示しようとしています");
                return const LoginPage();
              }
            },
          );
        },
      ),
    );
  }
}
