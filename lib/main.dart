import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:powersync/powersync.dart';
import 'features/views/top_page.dart';
import 'features/views/login_page.dart';
import 'database/schema.dart' as ps_schema;
import 'database/powersync_connector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'features/notification/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'core/app_config.dart';
import 'package:flutter/rendering.dart';

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
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  db = PowerSyncDatabase(schema: ps_schema.schema, path: dbPath);
  await db.initialize();

  db.connect(connector: SupabaseConnector(Supabase.instance.client));

  //ウィジェットを可視化する
  // debugPaintSizeEnabled = true;

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
      // debugShowMaterialGrid:true,
      
      title: "Kaeta!",
      theme: ThemeData(
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white, 
          surfaceTintColor: Colors.white, 
          elevation: .1,
          shadowColor: Colors.black,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2ECCA1),
          surface: Colors.white, 
        ),
      ),
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
