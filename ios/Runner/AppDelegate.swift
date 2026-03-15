import Flutter
import UIKit
import FirebaseMessaging
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
  private let pushDebugChannelName = "kaeta/push_debug"
  private var pushDebugChannel: FlutterMethodChannel?

  private func pushRuntimeInfo() -> [String: Any] {
    #if targetEnvironment(simulator)
    let runtime = "ios_simulator"
    #else
    let runtime = "ios_device"
    #endif
    let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
    let version =
      (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "unknown"
    let build =
      (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "unknown"
    return [
      "runtime": runtime,
      "bundleId": bundleId,
      "appVersion": version,
      "buildNumber": build
    ]
  }

  private func emitApsEnvironmentDebugEvent(status: String = "info") {
    let apsEnvironment =
      (Bundle.main.object(forInfoDictionaryKey: "APS_ENVIRONMENT") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedValue =
      (apsEnvironment?.isEmpty == false) ? apsEnvironment! : "unavailable_from_bundle"
    NSLog("[PushDebug] aps-environment(build-setting)=\(resolvedValue)")
    pushDebugChannel?.invokeMethod(
      "nativePushDebugEvent",
      arguments: [
        "step": "native_entitlement_aps_environment",
        "status": status,
        "error": "aps-environment(build-setting)=\(resolvedValue)"
      ].merging(pushRuntimeInfo()) { current, _ in current }
    )
  }

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
      pushDebugChannel = channel
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "registerForRemoteNotifications":
          DispatchQueue.main.async {
            self?.emitApsEnvironmentDebugEvent()
            UIApplication.shared.registerForRemoteNotifications()
            NSLog("[PushDebug] registerForRemoteNotifications requested from Flutter")
            self?.pushDebugChannel?.invokeMethod(
              "nativePushDebugEvent",
              arguments: [
                "step": "native_register_for_remote_notifications_requested",
                "status": "started"
              ].merging(self?.pushRuntimeInfo() ?? [:]) { current, _ in current }
            )
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
    emitApsEnvironmentDebugEvent()
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
    pushDebugChannel?.invokeMethod(
      "nativePushDebugEvent",
      arguments: [
        "step": "native_did_register_for_remote_notifications",
        "status": "ok",
        "tokenPrefix": String(token.prefix(16))
      ].merging(pushRuntimeInfo()) { current, _ in current }
    )
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("[PushDebug] didFailToRegisterForRemoteNotifications error=\(error.localizedDescription)")
    pushDebugChannel?.invokeMethod(
      "nativePushDebugEvent",
      arguments: [
        "step": "native_did_fail_to_register_for_remote_notifications",
        "status": "error",
        "error": error.localizedDescription
      ].merging(pushRuntimeInfo()) { current, _ in current }
    )
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
