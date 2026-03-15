import Flutter
import UIKit
import FirebaseMessaging
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
  private let pushDebugChannelName = "kaeta/push_debug"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // 💡 通知プラグインを登録するためのコールバックを設定
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
        GeneratedPluginRegistrant.register(with: registry)
    }

    GeneratedPluginRegistrant.register(with: self)
    Messaging.messaging().delegate = self

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: pushDebugChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "registerForRemoteNotifications":
          DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
            NSLog("[PushDebug] registerForRemoteNotifications requested from Flutter")
            result(nil)
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    NSLog("[PushDebug] didFinishLaunching -> registerForRemoteNotifications")
    application.registerForRemoteNotifications()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    NSLog("[PushDebug] didRegisterForRemoteNotifications token=\(token)")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("[PushDebug] didFailToRegisterForRemoteNotifications error=\(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
