import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:powersync/powersync.dart';
import 'features/todo/views/todo_page.dart';
import 'features/todo/views/login_page.dart';
import 'database/schema.dart' as ps_schema;
import 'database/powersync_connector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'features/notification/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'core/app_config.dart';

late final PowerSyncDatabase db;


Future<void> main() async {
  // ① Flutterの初期化
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

  await NotificationService().init();

  final dir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(dir.path, 'powersync.db');

  // ② Supabaseを初期化（手動同期ボタンのために残します）
  await Supabase.initialize(
    url: 'https://fkkvqxbzvysimylzedus.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3ZxeGJ6dnlzaW15bHplZHVzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwODcxODQsImV4cCI6MjA4MjY2MzE4NH0.fuE1weK4CkWhy4OFJ-Nwiwimv435985WmtxB9o2dxpU',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  db = PowerSyncDatabase(schema: ps_schema.schema, path: dbPath);
  await db.initialize();

  db.connect(connector: SupabaseConnector(Supabase.instance.client));

  // debugPaintSizeEnabled = true;//有効化するとウィジェットが可視化される
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
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          return StreamBuilder<AuthState>(
            stream: Supabase.instance.client.auth.onAuthStateChange,
            builder: (context, snapshot) {
              final session = snapshot.data?.session;

              if (session != null) {
                if (!db.connected) {
                  db.connect(
                    connector: SupabaseConnector(Supabase.instance.client),
                  );
                }
                return const TodoPage();
              } else {
                return const LoginPage();
              }
            },
          );
        },
      ),
    );
  }
}
