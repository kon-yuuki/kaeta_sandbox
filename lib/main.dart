import 'dart:io';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:powersync/powersync.dart';
import 'pages/home/home_screen.dart';
import 'pages/invite/view/invite_start_screen.dart';
import 'pages/onboarding/onboarding_flow.dart';
import 'pages/start/view/start_screen.dart';
import 'data/model/schema.dart' as ps_schema;
import 'data/model/powersync_connector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'data/services/notification_service.dart';
import 'data/repositories/device_tokens_repository.dart';
import 'data/providers/notifications_provider.dart';
import 'data/providers/items_provider.dart';
import 'data/providers/billing_provider.dart';
import 'data/services/family_owner_billing_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'core/app_config.dart';
import 'core/auth/secure_auth_storage.dart';
import 'data/providers/profiles_provider.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_typography.dart';
import 'core/app_link_handler.dart';
import 'data/services/billing_service.dart';
import 'pages/invite/providers/invite_flow_provider.dart';

late final PowerSyncDatabase db;
const bool _previewInviteStartPage = bool.fromEnvironment(
  'KAETA_PREVIEW_INVITE_START',
);

String _supabasePersistSessionKey(String supabaseUrl) {
  final projectRef = Uri.parse(supabaseUrl).host.split('.').first;
  return 'sb-$projectRef-auth-token';
}

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
  debugPrint('Startup: WidgetsFlutterBinding initialized');
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
  debugPrint('Startup: timezone initialized');

  await NotificationService().init();
  debugPrint('Startup: local notifications initialized');
  if (Platform.isIOS) {
    try {
      debugPrint('Startup: Firebase.initializeApp() begin');
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      debugPrint('Startup: Firebase.initializeApp() complete');
    } catch (e, st) {
      debugPrint('Firebase init failed on iOS: $e');
      debugPrint('$st');
    }
  }

  final dir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(dir.path, 'powersync.db');
  debugPrint('Startup: application documents resolved path=$dbPath');

  // ② Supabaseを初期化（手動同期ボタンのために残します）
  debugPrint('Startup: Supabase.initialize() begin');
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
      localStorage: SecureAuthStorage(
        persistSessionKey: _supabasePersistSessionKey(AppConfig.supabaseUrl),
      ),
    ),
  );
  debugPrint('Startup: Supabase.initialize() complete');

  await BillingService.configure(
    appUserId: Supabase.instance.client.auth.currentUser?.id,
  );
  debugPrint('Startup: RevenueCat configure complete');

  if (Platform.isIOS) {
    try {
      debugPrint('Startup: initPushMessaging() begin');
      await NotificationService().initPushMessaging();
      debugPrint('Startup: initPushMessaging() complete');
    } catch (e, st) {
      debugPrint('Push messaging init failed on iOS: $e');
      debugPrint('$st');
    }
  }

  debugPrint('Startup: PowerSync initialize begin');
  db = await _initializePowerSyncDatabase(dbPath);
  debugPrint('Startup: PowerSync initialize complete');

  debugPrint('Startup: runApp()');
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
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightAppColors.surfaceHighOnInverse,
          labelStyle: TextStyle(color: lightAppColors.textMedium),
          hintStyle: TextStyle(color: lightAppColors.textLow),
          errorStyle: TextStyle(
            color: lightAppColors.alert,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: lightAppColors.borderMedium),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: lightAppColors.borderMedium),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: lightAppColors.accentPrimary,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: lightAppColors.alert, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: lightAppColors.alert, width: 1.5),
          ),
          errorMaxLines: 3,
        ),
        bottomSheetTheme: BottomSheetThemeData(
          dragHandleColor: const Color(0xFFCCCCCC),
        ),
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

class _RootGateState extends ConsumerState<_RootGate>
    with WidgetsBindingObserver {
  bool _didStartAppLinkListener = false;
  bool _didRestorePendingInvite = false;
  bool _authBootstrapResolved = false;
  final AppLinkHandler _appLinkHandler = AppLinkHandler();
  final DeviceTokensRepository _deviceTokensRepository =
      DeviceTokensRepository();
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<AuthState>? _authStateSub;
  Timer? _authBootstrapTimeout;
  String? _currentTokenOwnerUserId;
  String? _currentProfileEnsuredUserId;
  String? _currentBillingUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didStartAppLinkListener) return;
    _didStartAppLinkListener = true;
    WidgetsBinding.instance.addObserver(this);
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
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
        token,
      ) {
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
      if (mounted) {
        setState(() {});
      }
      if (!_authBootstrapResolved && mounted) {
        setState(() => _authBootstrapResolved = true);
      }
      final session = event.session;
      if (session == null) return;
      debugPrint(
        'AuthState change detected in RootGate: event=${event.event} user=${session.user.id}',
      );
      _syncDeviceTokenOnSignedIn(session.user.id);
      _syncBillingOnSignedIn(session.user.id);
      unawaited(
        ref.read(notificationsRepositoryProvider).flushQueuedNotifications(),
      );
      unawaited(ref.read(itemsRepositoryProvider).processPendingReadings());
    });

    _authBootstrapTimeout ??= Timer(const Duration(seconds: 2), () {
      if (!mounted || _authBootstrapResolved) return;
      setState(() => _authBootstrapResolved = true);
    });
  }

  void _syncDeviceTokenOnSignedIn(String userId) {
    if (_currentProfileEnsuredUserId != userId) {
      _currentProfileEnsuredUserId = userId;
      unawaited(ref.read(profileRepositoryProvider).ensureProfile());
    }
    if (!Platform.isIOS) return;
    if (_currentTokenOwnerUserId == userId) return;
    _currentTokenOwnerUserId = userId;
    unawaited(_deviceTokensRepository.upsertCurrentDeviceToken(userId: userId));
  }

  void _cleanupDeviceTokenOnSignedOut() {
    // NOTE:
    // 一時的な未認証状態（起動直後の揺らぎ等）でdevice tokenを消さない。
    // token削除は明示的なログアウト操作時のみ行う方が安全。
    _currentTokenOwnerUserId = null;
    _currentProfileEnsuredUserId = null;
  }

  void _syncBillingOnSignedIn(String userId) {
    if (_currentBillingUserId == userId) return;
    _currentBillingUserId = userId;
    unawaited(
      ref.read(billingControllerProvider.notifier).handleSignedIn(userId),
    );
  }

  void _cleanupBillingOnSignedOut() {
    _currentBillingUserId = null;
    unawaited(ref.read(billingControllerProvider.notifier).handleSignedOut());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tokenRefreshSub?.cancel();
    _authStateSub?.cancel();
    _authBootstrapTimeout?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    unawaited(
      ref.read(notificationsRepositoryProvider).flushQueuedNotifications(),
    );
    unawaited(ref.read(itemsRepositoryProvider).processPendingReadings());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<FamilyOwnerBillingSnapshot?>>(
      familyOwnerBillingSyncProvider,
      (_, next) {
        next.whenData((snapshot) {
          final controller = ref.read(billingControllerProvider.notifier);
          if (snapshot == null) {
            controller.clearFamilyOwnerSnapshot();
            return;
          }
          controller.setFamilyOwnerSnapshot(snapshot);
        });
      },
    );

    if (kDebugMode && _previewInviteStartPage) {
      return const InviteStartPage(
        inviteId: 'debug-preview',
        previewData: InviteStartPreviewData(
          familyName: '●●ファミリー',
          inviterName: 'みさきさん',
        ),
      );
    }

    final pendingInviteId = ref.watch(pendingInviteIdProvider);
    final hasPendingInvite =
        pendingInviteId != null && pendingInviteId.isNotEmpty;

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session =
            snapshot.data?.session ??
            Supabase.instance.client.auth.currentSession;
        final user = Supabase.instance.client.auth.currentUser;
        final effectiveUser = user ?? session?.user;
        if ((session != null || user != null) && !_authBootstrapResolved) {
          _authBootstrapResolved = true;
        }

        if (!_authBootstrapResolved) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final isSignedIn = effectiveUser != null;

        if (isSignedIn) {
          _syncDeviceTokenOnSignedIn(effectiveUser.id);
          _syncBillingOnSignedIn(effectiveUser.id);
          unawaited(
            ref
                .read(notificationsRepositoryProvider)
                .flushQueuedNotifications(),
          );
          unawaited(ref.read(itemsRepositoryProvider).processPendingReadings());
          if (!db.connected) {
            db.connect(connector: SupabaseConnector(Supabase.instance.client));
          }

          // ゲストユーザーは通常オンボーディングをスキップ
          // ただし招待導線中は招待向けオンボーディングを通す
          if (effectiveUser.isAnonymous) {
            if (hasPendingInvite) {
              return OnboardingFlow(
                onExitRequested: () async {
                  debugPrint(
                    'Sign out triggered from anonymous invite onboarding exit.',
                  );
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
          _cleanupBillingOnSignedOut();
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
