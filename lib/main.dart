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
import 'core/app_link_handler.dart';

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
        builder: (context) => const _RootGate(),
      ),
    );
  }
}

class _RootGate extends ConsumerStatefulWidget {
  const _RootGate();

  @override
  ConsumerState<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<_RootGate> {
  bool _didStartAppLinkListener = false;
  final AppLinkHandler _appLinkHandler = AppLinkHandler();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didStartAppLinkListener) return;
    _didStartAppLinkListener = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _appLinkHandler.listen(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
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
  }
}

// オンボーディング判定Widget
class _OnboardingGate extends ConsumerStatefulWidget {
  const _OnboardingGate();

  @override
  ConsumerState<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<_OnboardingGate> {
  bool _initialLoadComplete = false;

  @override
  void initState() {
    super.initState();
    // 初回ロード完了までは少し待つ（PowerSync同期待ち）
    _waitForInitialSync();
  }

  Future<void> _waitForInitialSync() async {
    // PowerSyncの同期を少し待つ
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => _initialLoadComplete = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);

    // 初回ロードが完了していない場合はローディング表示
    if (!_initialLoadComplete) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return profileAsync.when(
      skipLoadingOnReload: true,
      data: (profile) {
        debugPrint('OnboardingGate: profile=$profile, onboardingCompleted=${profile?.onboardingCompleted}');

        // オンボーディング完了済みならホーム画面へ
        if (profile?.onboardingCompleted == true) {
          return const TodoPage();
        }

        // プロフィールがないか、オンボーディング未完了の場合
        return const OnboardingFlow();
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
