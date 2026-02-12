import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  // ① 内部で自分自身のインスタンスを一つだけ作る
  static final NotificationService _instance = NotificationService._();
  
  // ② 外部からはこの factory を通じてインスタンスを取得する
  factory NotificationService() => _instance;
  
  // ③ プライベートなコンストラクタ
  NotificationService._();

  // ④ 通知プラグインの本体を定義
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const _prefEnabledKey = 'app_notifications_enabled';

  Future<bool> _isAppNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnabledKey) ?? true;
  }

  Future<void> init() async {
   
    // ① Android用の初期設定
    // @mipmap/ic_launcher はアプリのアイコンを指します
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

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

  // 💡 通知を表示する具体的な命令
  Future<void> showNotification({
    required int id,        // 通知ごとに変える識別番号
    required String title,  // 通知のタイトル
    required String body,   // 通知の本文
  }) async {
    if (!await _isAppNotificationEnabled()) return;

    // 1. Android用の「どう表示するか」の設定
    const androidDetails = AndroidNotificationDetails(
      'channel_id_1',     // チャンネルID（システム内部用）
      '通常通知',          // ユーザーに見えるチャンネル名
      importance: Importance.max, // 重要度：最大
      priority: Priority.high,    // 優先度：高
    );

    // 2. iOS用の「どう表示するか」の設定
    const iosDetails = DarwinNotificationDetails();

    // 3. 設定をまとめて、実際にOSへ「表示して！」とリクエストを送る
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
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
    final iosResult = await _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    if (iosResult != null) return iosResult;

    final macResult = await _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    if (macResult != null) return macResult;

    final androidResult = await _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    if (androidResult != null) return androidResult;

    return false;
  }

  Future<bool> isPermissionGranted() async {
    final androidEnabled = await _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.areNotificationsEnabled();
    if (androidEnabled != null) return androidEnabled;

    final iosSettings = await _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()?.checkPermissions();
    if (iosSettings != null) {
      return iosSettings.isEnabled;
    }

    final macSettings = await _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>()?.checkPermissions();
    if (macSettings != null) {
      return macSettings.isEnabled;
    }

    return false;
  }

  Future<void> setAppNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabledKey, enabled);
  }
}
