import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import '../repositories/push_debug_log_repository.dart';

class PushTokenFetchResult {
  final String? token;
  final String? reason;
  final String permissionStatus;
  final bool firebaseInitialized;
  final bool apnsTokenPresent;

  const PushTokenFetchResult({
    required this.token,
    required this.reason,
    required this.permissionStatus,
    required this.firebaseInitialized,
    required this.apnsTokenPresent,
  });
}

class NotificationService {
  // ① 内部で自分自身のインスタンスを一つだけ作る
  static final NotificationService _instance = NotificationService._();

  // ② 外部からはこの factory を通じてインスタンスを取得する
  factory NotificationService() => _instance;

  // ③ プライベートなコンストラクタ
  NotificationService._();

  // ④ 通知プラグインの本体を定義
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _messaging;
  static const MethodChannel _pushDebugChannel = MethodChannel(
    'kaeta/push_debug',
  );
  final PushDebugLogRepository _pushDebugLogRepository =
      PushDebugLogRepository();
  final List<Map<String, String?>> _pendingNativePushDebugEvents = [];
  static const _prefEnabledKey = 'app_notifications_enabled';
  bool _isPushInitialized = false;
  bool _nativePushDebugHandlerAttached = false;
  Completer<void>? _apnsRegistrationCompleter;
  bool _hasObservedApnsRegistration = false;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  Future<bool> _isAppNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnabledKey) ?? true;
  }

  Future<void> init() async {
    // ① Android用の初期設定
    // @mipmap/ic_launcher はアプリのアイコンを指します
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // ② iOS用の初期設定（オンボーディングで許可を求めるため、init時はfalse）
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // ③ ここで実際に「道具箱（_plugin）」に設定を覚えさせる
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  Future<void> initPushMessaging() async {
    if (_isPushInitialized) return;
    final messaging = _messaging ??= FirebaseMessaging.instance;
    _attachNativePushDebugHandler();

    await messaging.setAutoInitEnabled(true);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    await _requestNativeRemoteNotificationRegistration();

    _onTokenRefreshSub = messaging.onTokenRefresh.listen((token) {
      debugPrint('FCM token (refresh): $token');
    });

    _onMessageSub = FirebaseMessaging.onMessage.listen((message) async {
      final title =
          message.notification?.title ?? message.data['title'] as String?;
      final body =
          message.notification?.body ?? message.data['body'] as String?;

      if (title == null && body == null) return;

      await showNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
        title: title ?? 'お知らせ',
        body: body ?? '',
      );
    });

    _onMessageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      debugPrint('Push opened app. data=${message.data}');
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        'App opened from terminated push. data=${initialMessage.data}',
      );
    }

    _isPushInitialized = true;
  }

  void _attachNativePushDebugHandler() {
    if (_nativePushDebugHandlerAttached) return;
    _nativePushDebugHandlerAttached = true;
    _pushDebugChannel.setMethodCallHandler((call) async {
      if (call.method != 'nativePushDebugEvent') return;
      final args = Map<String, dynamic>.from(
        (call.arguments as Map?)?.cast<dynamic, dynamic>() ?? const {},
      );
      final step = args['step']?.toString();
      if (step == null || step.isEmpty) return;

      final resolvedUserId =
          Supabase.instance.client.auth.currentUser?.id ??
          args['userId']?.toString();
      final event = <String, String?>{
        'step': step,
        'status': args['status']?.toString(),
        'error': args['error']?.toString(),
        'tokenPrefix': args['tokenPrefix']?.toString(),
      };
      if (step == 'native_did_register_for_remote_notifications') {
        _hasObservedApnsRegistration = true;
        _apnsRegistrationCompleter?.complete();
        _apnsRegistrationCompleter = null;
      }
      if (step == 'native_did_fail_to_register_for_remote_notifications') {
        _apnsRegistrationCompleter?.complete();
        _apnsRegistrationCompleter = null;
      }
      if (resolvedUserId == null || resolvedUserId.isEmpty) {
        _pendingNativePushDebugEvents.add(event);
        debugPrint('PushDebug: queued native event without user. step=$step');
        return;
      }

      await _logNativePushDebugEvent(resolvedUserId, event);
      await _flushPendingNativePushDebugEvents(resolvedUserId);
    });
  }

  Future<void> _logNativePushDebugEvent(
    String userId,
    Map<String, String?> event,
  ) async {
    final metadataParts = <String>[
      if ((event['runtime'] ?? '').isNotEmpty) 'runtime=${event['runtime']}',
      if ((event['bundleId'] ?? '').isNotEmpty)
        'bundleId=${event['bundleId']}',
      if ((event['appVersion'] ?? '').isNotEmpty)
        'appVersion=${event['appVersion']}',
      if ((event['buildNumber'] ?? '').isNotEmpty)
        'buildNumber=${event['buildNumber']}',
    ];
    final combinedError = [
      if ((event['error'] ?? '').isNotEmpty) event['error'],
      if (metadataParts.isNotEmpty) metadataParts.join(','),
    ].join(' | ');
    await _pushDebugLogRepository.log(
      userId: userId,
      step: event['step'] ?? 'native_push_debug_event',
      status: event['status'],
      error: combinedError.isEmpty ? null : combinedError,
      tokenPrefix: event['tokenPrefix'],
      source: 'ios_native',
    );
  }

  Future<void> _flushPendingNativePushDebugEvents(String userId) async {
    if (_pendingNativePushDebugEvents.isEmpty) return;
    final events = List<Map<String, String?>>.from(_pendingNativePushDebugEvents);
    _pendingNativePushDebugEvents.clear();
    for (final event in events) {
      await _logNativePushDebugEvent(userId, event);
    }
  }

  // 💡 通知を表示する具体的な命令
  Future<void> showNotification({
    required int id, // 通知ごとに変える識別番号
    required String title, // 通知のタイトル
    required String body, // 通知の本文
  }) async {
    if (!await _isAppNotificationEnabled()) return;

    // 1. Android用の「どう表示するか」の設定
    const androidDetails = AndroidNotificationDetails(
      'channel_id_1', // チャンネルID（システム内部用）
      '通常通知', // ユーザーに見えるチャンネル名
      importance: Importance.max, // 重要度：最大
      priority: Priority.high, // 優先度：高
    );

    // 2. iOS用の「どう表示するか」の設定
    const iosDetails = DarwinNotificationDetails();

    // 3. 設定をまとめて、実際にOSへ「表示して！」とリクエストを送る
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int seconds, // 何秒後に鳴らすか
  }) async {
    if (!await _isAppNotificationEnabled()) return;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds)), // 現在からN秒後
      const NotificationDetails(
        android: AndroidNotificationDetails('channel_id_1', '予約通知'),
        iOS: DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // 閉じても鳴る設定
    );
  }

  // 通知許可をリクエスト（オンボーディング用）
  Future<bool> requestPermission() async {
    final messaging = _messaging ??= FirebaseMessaging.instance;
    final messagingSettings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    final fcmGranted =
        messagingSettings.authorizationStatus ==
            AuthorizationStatus.authorized ||
        messagingSettings.authorizationStatus ==
            AuthorizationStatus.provisional;
    if (Platform.isIOS && fcmGranted) {
      await _requestNativeRemoteNotificationRegistration();
    }

    final iosResult = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    if (iosResult != null) return iosResult;

    final macResult = await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    if (macResult != null) return macResult;

    final androidResult = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    if (androidResult != null) return androidResult || fcmGranted;

    return fcmGranted;
  }

  Future<void> _requestNativeRemoteNotificationRegistration() async {
    if (!Platform.isIOS) return;
    try {
      if (!_hasObservedApnsRegistration &&
          (_apnsRegistrationCompleter == null ||
              _apnsRegistrationCompleter!.isCompleted)) {
        _apnsRegistrationCompleter = Completer<void>();
      }
      await _pushDebugChannel.invokeMethod<void>(
        'registerForRemoteNotifications',
      );
      debugPrint('PushDebug: requested native registerForRemoteNotifications');
    } catch (e) {
      debugPrint(
        'PushDebug: failed to request native registerForRemoteNotifications: $e',
      );
    }
  }

  Future<bool> isPermissionGranted() async {
    final androidEnabled = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.areNotificationsEnabled();
    if (androidEnabled != null) return androidEnabled;

    final iosSettings = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.checkPermissions();
    if (iosSettings != null) {
      return iosSettings.isEnabled;
    }

    final macSettings = await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.checkPermissions();
    if (macSettings != null) {
      return macSettings.isEnabled;
    }

    return false;
  }

  Future<void> setAppNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabledKey, enabled);
  }

  Future<void> disposePushListeners() async {
    await _onMessageSub?.cancel();
    await _onMessageOpenedAppSub?.cancel();
    await _onTokenRefreshSub?.cancel();
    _onMessageSub = null;
    _onMessageOpenedAppSub = null;
    _onTokenRefreshSub = null;
    _isPushInitialized = false;
  }

  Future<String?> getCurrentPushToken() async {
    final result = await getCurrentPushTokenWithDiagnostics();
    return result.token;
  }

  Future<void> _waitForApnsRegistrationIfNeeded() async {
    if (!Platform.isIOS) return;
    if (_hasObservedApnsRegistration) return;
    final completer = _apnsRegistrationCompleter;
    if (completer == null || completer.isCompleted) return;
    try {
      await completer.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      debugPrint('Timed out waiting for native APNs registration event.');
    }
  }

  Future<PushTokenFetchResult> getCurrentPushTokenWithDiagnostics() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId != null && currentUserId.isNotEmpty) {
      await _flushPendingNativePushDebugEvents(currentUserId);
    }

    var firebaseInitialized = Firebase.apps.isNotEmpty;
    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp();
        firebaseInitialized = true;
      } catch (e) {
        debugPrint(
          'FCM token fetch failed: Firebase initialize failed. error=$e',
        );
        return const PushTokenFetchResult(
          token: null,
          reason: 'firebase_initialize_failed',
          permissionStatus: 'unknown',
          firebaseInitialized: false,
          apnsTokenPresent: false,
        );
      }
    }

    final messaging = _messaging ??= FirebaseMessaging.instance;
    final permissionSettings = await messaging.getNotificationSettings();
    final permissionStatus = permissionSettings.authorizationStatus.name;
    if (permissionSettings.authorizationStatus ==
        AuthorizationStatus.notDetermined) {
      return PushTokenFetchResult(
        token: null,
        reason: 'notification_permission_not_determined',
        permissionStatus: permissionStatus,
        firebaseInitialized: firebaseInitialized,
        apnsTokenPresent: false,
      );
    }
    var apnsTokenPresent = !Platform.isIOS;

    if (Platform.isIOS) {
      await _requestNativeRemoteNotificationRegistration();
      await _waitForApnsRegistrationIfNeeded();
      String? apnsToken;
      for (var i = 0; i < 20; i++) {
        apnsToken = await messaging.getAPNSToken();
        if (apnsToken != null && apnsToken.isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (apnsToken == null || apnsToken.isEmpty) {
        debugPrint('APNS token fetch failed after retries.');
        return PushTokenFetchResult(
          token: null,
          reason: 'apns_token_missing',
          permissionStatus: permissionStatus,
          firebaseInitialized: firebaseInitialized,
          apnsTokenPresent: false,
        );
      }
      apnsTokenPresent = true;
    }

    for (var i = 0; i < 6; i++) {
      try {
        final token = await messaging.getToken();
        if (token != null && token.isNotEmpty) {
          return PushTokenFetchResult(
            token: token,
            reason: null,
            permissionStatus: permissionStatus,
            firebaseInitialized: firebaseInitialized,
            apnsTokenPresent: apnsTokenPresent,
          );
        }
      } catch (e) {
        final message = e.toString();
        if (!message.contains('apns-token-not-set')) {
          return PushTokenFetchResult(
            token: null,
            reason: 'get_token_exception:$message',
            permissionStatus: permissionStatus,
            firebaseInitialized: firebaseInitialized,
            apnsTokenPresent: apnsTokenPresent,
          );
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    debugPrint('FCM token fetch failed after retries.');
    return PushTokenFetchResult(
      token: null,
      reason: 'fcm_token_empty_after_retries',
      permissionStatus: permissionStatus,
      firebaseInitialized: firebaseInitialized,
      apnsTokenPresent: apnsTokenPresent,
    );
  }
}
