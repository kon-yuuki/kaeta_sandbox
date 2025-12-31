import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/todo/views/todo_page.dart';

Future<void> main() async {
  // ① Flutterの初期化
  WidgetsFlutterBinding.ensureInitialized();

  // ② Supabaseを初期化（手動同期ボタンのために残します）
  await Supabase.initialize(
    url: 'https://fkkvqxbzvysimylzedus.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3ZxeGJ6dnlzaW15bHplZHVzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwODcxODQsImV4cCI6MjA4MjY2MzE4NH0.fuE1weK4CkWhy4OFJ-Nwiwimv435985WmtxB9o2dxpU',
  );

  // 💡 PowerSync の初期化、接続、Drift への注入はすべて不要になりました。
  // データベースの作成は todo_provider.dart 側で行われます。

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kaeta!',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TodoPage(),
    );
  }
}