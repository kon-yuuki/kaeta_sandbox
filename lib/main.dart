import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:powersync/powersync.dart';
import 'pages/home/home_screen.dart';
import 'pages/login/view/login_screen.dart';
import 'pages/onboarding/onboarding_flow.dart';
import 'data/model/schema.dart' as ps_schema;
import 'data/model/powersync_connector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'data/services/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'core/app_config.dart';
import 'data/providers/profiles_provider.dart';
import 'core/theme/app_colors.dart';

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

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Kaeta!",
      theme: ThemeData(
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: lightAppColors.surfaceTertiary,
        appBarTheme: AppBarTheme(
          backgroundColor: lightAppColors.surfaceHighOnInverse,
          surfaceTintColor: lightAppColors.surfaceHighOnInverse,
          elevation: .1,
          shadowColor: Colors.black,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: lightAppColors.accentPrimary,
          surface: lightAppColors.surfaceHighOnInverse,
          primary: lightAppColors.accentPrimary,
        ),
        cardColor: lightAppColors.surfaceHighOnInverse,
        extensions: const <ThemeExtension<dynamic>>[
          lightAppColors,
        ],
      ),
      home: Builder(
        builder: (context) {
          return StreamBuilder<AuthState>(
            stream: Supabase.instance.client.auth.onAuthStateChange,
            builder: (context, snapshot) {
              final session = snapshot.data?.session;
              final user = Supabase.instance.client.auth.currentUser;

              if (session != null) {
                if (!db.connected) {
                  db.connect(
                    connector: SupabaseConnector(Supabase.instance.client),
                  );
                }

                // ゲストユーザーはオンボーディングをスキップ
                if (user?.isAnonymous == true) {
                  return const TodoPage();
                }

                // 通常ユーザーはオンボーディング判定
                return const _OnboardingGate();
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

// オンボーディング判定Widget
class _OnboardingGate extends ConsumerWidget {
  const _OnboardingGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);

    return profileAsync.when(
      data: (profile) {
        // プロフィールがない場合はオンボーディング
        if (profile == null) {
          return const OnboardingFlow();
        }

        // オンボーディング未完了の場合
        if (profile.onboardingCompleted != true) {
          return const OnboardingFlow();
        }

        // オンボーディング完了済みならホーム画面へ
        return const TodoPage();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) {
        debugPrint('OnboardingGate error: $e');
        debugPrint('Stack trace: $st');
        return Scaffold(
          body: Center(child: Text('エラーが発生しました: $e')),
        );
      },
    );
  }
}
