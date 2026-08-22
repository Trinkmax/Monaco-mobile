import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // flutter_local_notifications: el AppDelegate tiene que ser el delegate del
    // centro de notificaciones para que las notificaciones locales se muestren
    // con la app en primer plano y los taps lleguen al plugin. FlutterAppDelegate
    // ya implementa UNUserNotificationCenterDelegate y reparte los callbacks a
    // los plugins registrados (firebase_messaging incluido).
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
