import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var notificationChannel: FlutterMethodChannel?
  override func application(_ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      notificationChannel = FlutterMethodChannel(name: "br.com.softsistemas.mobile/notifications", binaryMessenger: controller.binaryMessenger)
      notificationChannel?.setMethodCallHandler { call, result in
        switch call.method {
        case "status": Self.notificationStatus(result)
        case "request":
          UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error = error { DispatchQueue.main.async { result(FlutterError(code: "PERMISSION_FAILED", message: error.localizedDescription, details: nil)) }; return }
            Self.notificationStatus(result)
          }
        case "openSettings":
          guard let url = URL(string: UIApplication.openSettingsURLString) else { result(false); return }
          UIApplication.shared.open(url, options: [:]) { success in result(success) }
        default: result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private static func notificationStatus(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let status: String
      switch settings.authorizationStatus {
      case .authorized: status = settings.alertSetting == .enabled ? "granted" : "blocked"
      case .provisional: status = "provisional"
      case .denied: status = "blocked"
      case .notDetermined: status = "not_determined"
      @unknown default: status = "unavailable"
      }
      DispatchQueue.main.async { result(status) }
    }
  }
}
