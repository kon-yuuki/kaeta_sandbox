import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  // ① 内部で自分自身のインスタンスを一つだけ作る
  static final NotificationService _instance = NotificationService._();
  
  // ② 外部からはこの factory を通じてインスタンスを取得する
  factory NotificationService() => _instance;
  
  // ③ プライベートなコンストラクタ
  NotificationService._();

  // ④ 通知プラグインの本体を定義
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
   
    // ① Android用の初期設定
    // @mipmap/ic_launcher はアプリのアイコンを指します
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // ② iOS用の初期設定（通知を出してもいいかユーザーに聞く設定）
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
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
}