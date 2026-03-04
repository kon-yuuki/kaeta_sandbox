import 'dart:io';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:powersync/powersync.dart';
import 'pages/home/home_screen.dart';
import 'pages/onboarding/onboarding_flow.dart';
import 'pages/start/view/start_screen.dart';
import 'data/model/schema.dart' as ps_schema;
import 'data/model/powersync_connector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'data/services/notification_service.dart';
import 'data/repositories/device_tokens_repository.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'core/app_config.dart';
import 'data/providers/profiles_provider.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_typography.dart';
import 'core/app_link_handler.dart';
import 'pages/invite/providers/invite_flow_provider.dart';

late final PowerSyncDatabase db;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background push: ${message.messageId}');
}

Future<void> _deletePowerSyncFiles(String dbPath) async {
  final files = [
    File(dbPath),
    File('$dbPath-wal'),
    File('$dbPath-shm'),
    File('$dbPath-journal'),
  ];
  for (final file in files) {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

Future<PowerSyncDatabase> _initializePowerSyncDatabase(String dbPath) async {
  var instance = PowerSyncDatabase(schema: ps_schema.schema, path: dbPath);
  try {
    await instance.initialize();
    return instance;
  } catch (e) {
    final message = e.toString();
    final isSchemaReplaceError =
        message.contains('powersync_replace_schema') ||
        message.contains('SQL logic error');
    if (!isSchemaReplaceError) rethrow;

    debugPrint('PowerSync schema replacement failed. Recreating local db: $e');
    await _deletePowerSyncFiles(dbPath);
    instance = PowerSyncDatabase(schema: ps_schema.schema, path: dbPath);
    await instance.initialize();
    return instance;
  }
}

Future<void> main() async {
  // ① Flutterの初期化
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

  await NotificationService().init();
  if (Platform.isIOS) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await NotificationService().initPushMessaging();
    } catch (e, st) {
      debugPrint('Firebase init failed on iOS: $e');
      debugPrint('$st');
    }
  }

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

  db = await _initializePowerSyncDatabase(dbPath);

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
        textTheme: TextTheme(
          displayLarge: lightAppTypography.egOnl26R120,
          headlineMedium: lightAppTypography.std20M160,
          titleLarge: lightAppTypography.dsp21B140,
          titleMedium: lightAppTypography.std16B150,
          bodyLarge: lightAppTypography.std16R160,
          bodyMedium: lightAppTypography.std14R160,
          labelLarge: lightAppTypography.std12B160,
          labelMedium: lightAppTypography.std12M160,
          bodySmall: lightAppTypography.std11M160,
        ),
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
        extensions: <ThemeExtension<dynamic>>[
          lightAppColors,
          lightAppTypography,
        ],
      ),
      home: Builder(builder: (context) => const _RootGate()),
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
  bool _didRestorePendingInvite = false;
  final AppLinkHandler _appLinkHandler = AppLinkHandler();
  final DeviceTokensRepository _deviceTokensRepository =
      DeviceTokensRepository();
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<AuthState>? _authStateSub;
  String? _currentTokenOwnerUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didStartAppLinkListener) return;
    _didStartAppLinkListener = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_didRestorePendingInvite) {
        _didRestorePendingInvite = true;
        ref.read(inviteFlowPersistenceProvider).restorePendingInviteId();
      }
      _appLinkHandler.listen(context, ref);
    });

    final firebaseReady = Firebase.apps.isNotEmpty;
    if (_tokenRefreshSub == null && Platform.isIOS && firebaseReady) {
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        debugPrint('FCM token refresh received in root gate: $token');
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null || userId.isEmpty) return;
        unawaited(
          _deviceTokensRepository.upsertCurrentDeviceToken(userId: userId),
        );
      });
    }

    _authStateSub ??= Supabase.instance.client.auth.onAuthStateChange.listen((
      event,
    ) {
      final session = event.session;
      if (session == null) return;
      debugPrint(
        'AuthState change detected in RootGate: event=${event.event} user=${session.user.id}',
      );
      _syncDeviceTokenOnSignedIn(session.user.id);
    });
  }

  void _syncDeviceTokenOnSignedIn(String userId) {
    if (!Platform.isIOS) return;
    if (Firebase.apps.isEmpty) return;
    if (_currentTokenOwnerUserId == userId) return;
    _currentTokenOwnerUserId = userId;
    unawaited(_deviceTokensRepository.upsertCurrentDeviceToken(userId: userId));
  }

  void _cleanupDeviceTokenOnSignedOut() {
    // NOTE:
    // 一時的な未認証状態（起動直後の揺らぎ等）でdevice tokenを消さない。
    // token削除は明示的なログアウト操作時のみ行う方が安全。
    _currentTokenOwnerUserId = null;
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    _authStateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingInviteId = ref.watch(pendingInviteIdProvider);
    final hasPendingInvite =
        pendingInviteId != null && pendingInviteId.isNotEmpty;

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session =
            snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;
        final user = Supabase.instance.client.auth.currentUser;
        final effectiveUser = user ?? session?.user;
        final isSignedIn = effectiveUser != null;

        if (isSignedIn) {
          _syncDeviceTokenOnSignedIn(effectiveUser.id);
          if (!db.connected) {
            db.connect(connector: SupabaseConnector(Supabase.instance.client));
          }

          // ゲストユーザーは通常オンボーディングをスキップ
          // ただし招待導線中は招待向けオンボーディングを通す
          if (effectiveUser.isAnonymous) {
            if (hasPendingInvite) {
              return OnboardingFlow(
                onExitRequested: () async {
                  debugPrint('Sign out triggered from anonymous invite onboarding exit.');
                  await Supabase.instance.client.auth.signOut();
                  await db.disconnectAndClear();
                },
              );
            }
            return const TodoPage();
          }

          // 通常ユーザーはオンボーディング判定
          return const _OnboardingGate();
        } else {
          debugPrint(
            'RootGate unauthenticated branch. session=${session != null} user=${user?.id}',
          );
          _cleanupDeviceTokenOnSignedOut();
          if (db.connected) {
            db.disconnect();
          }
          return const StartPage();
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return profileAsync.when(
      skipLoadingOnReload: true,
      data: (profile) {
        debugPrint(
          'OnboardingGate: profile=$profile, onboardingCompleted=${profile?.onboardingCompleted}',
        );

        // オンボーディング完了済みならホーム画面へ
        if (profile?.onboardingCompleted == true) {
          return const TodoPage();
        }

        // プロフィールがないか、オンボーディング未完了の場合
        return OnboardingFlow(
          onExitRequested: () async {
            debugPrint('Sign out triggered from onboarding exit.');
            await Supabase.instance.client.auth.signOut();
            await db.disconnectAndClear();
          },
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) {
        debugPrint('OnboardingGate error: $e');
        debugPrint('Stack trace: $st');
        return Scaffold(body: Center(child: Text('エラーが発生しました: $e')));
      },
    );
  }
}
