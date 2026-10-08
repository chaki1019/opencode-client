import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // A resolution from the relay is a silent push: handled here, natively,
  // so it works even when iOS wakes the app in the background just for it.
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    guard PushNotifications.isResolution(userInfo) else {
      super.application(
        application, didReceiveRemoteNotification: userInfo,
        fetchCompletionHandler: completionHandler)
      return
    }
    PushNotifications.resolve(userInfo) { completionHandler(.newData) }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PushKeyStore") {
      PushKeyStore.register(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PushNotifications") {
      PushNotifications.register(messenger: registrar.messenger())
    }
  }
}

/// Removes delivered notifications that no longer need the user, and keeps
/// the app badge. The badge is the app's "needs you" count: the app sets it
/// while it runs; while it is away, the Notification Service Extension adds
/// one per notification and a resolution takes off the ones it removed.
/// The count lives in the app group so both processes see it.
enum PushNotifications {
  static let badgeKey = "badge"
  static var shared: UserDefaults? { UserDefaults(suiteName: PushKeyStore.accessGroup) }

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "opencode/push_notifications", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "clearSession":
        guard let sessionID = args?["sessionId"] as? String else {
          result(FlutterError(code: "bad_args", message: nil, details: nil))
          return
        }
        // The app sets the badge itself from what it knows.
        remove(where: { $0["sessionID"] as? String == sessionID }) { _ in result(nil) }
      case "setBadge":
        guard let count = args?["count"] as? Int else {
          result(FlutterError(code: "bad_args", message: nil, details: nil))
          return
        }
        setBadge(count) { result(nil) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// A relay message saying notifications were dealt with elsewhere
  /// (see push/relay/src/index.js).
  static func isResolution(_ userInfo: [AnyHashable: Any]) -> Bool {
    userInfo["type"] as? String == "resolved"
  }

  static func resolve(_ userInfo: [AnyHashable: Any], done: @escaping () -> Void) {
    guard let keyId = userInfo["keyId"] as? String, let session = userInfo["session"] as? String,
      let kinds = (userInfo["kinds"] as? String)?.split(separator: ",").map(String.init)
    else {
      done()
      return
    }
    remove(
      where: {
        $0["keyId"] as? String == keyId && $0["sessionID"] as? String == session
          && kinds.contains($0["kind"] as? String ?? "completed")
      }
    ) { removed in
      guard removed > 0 else {
        done()
        return
      }
      setBadge(max(0, (shared?.integer(forKey: badgeKey) ?? 0) - removed), done: done)
    }
  }

  static func setBadge(_ count: Int, done: @escaping () -> Void) {
    shared?.set(count, forKey: badgeKey)
    UNUserNotificationCenter.current().setBadgeCount(count) { _ in
      DispatchQueue.main.async(execute: done)
    }
  }

  /// Removes the delivered notifications whose payload matches and passes
  /// on how many there were.
  static func remove(where matches: @escaping ([AnyHashable: Any]) -> Bool, done: @escaping (Int) -> Void) {
    let center = UNUserNotificationCenter.current()
    center.getDeliveredNotifications { delivered in
      let gone = delivered.filter { matches($0.request.content.userInfo) }
      center.removeDeliveredNotifications(withIdentifiers: gone.map(\.request.identifier))
      DispatchQueue.main.async { done(gone.count) }
    }
  }
}

/// Keeps notification decryption keys where the Notification Service
/// Extension can read them: the keychain, shared through the app group.
/// The extension (ios/NotificationService) reads the same items.
enum PushKeyStore {
  static let accessGroup = "group.app.opencodemobile"
  static let service = "opencode-push"

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "opencode/push_keys", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard let args = call.arguments as? [String: Any],
        let keyId = args["keyId"] as? String
      else {
        result(FlutterError(code: "bad_args", message: nil, details: nil))
        return
      }
      switch call.method {
      case "set":
        guard let base64 = args["key"] as? String, let key = Data(base64Encoded: base64) else {
          result(FlutterError(code: "bad_args", message: nil, details: nil))
          return
        }
        let status = set(key, for: keyId)
        result(status == errSecSuccess ? nil : FlutterError(code: "keychain", message: "\(status)", details: nil))
      case "remove":
        SecItemDelete(query(keyId) as CFDictionary)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  static func query(_ keyId: String) -> [CFString: Any] {
    [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: keyId,
      kSecAttrAccessGroup: accessGroup,
    ]
  }

  static func set(_ key: Data, for keyId: String) -> OSStatus {
    SecItemDelete(query(keyId) as CFDictionary)
    var item = query(keyId)
    item[kSecValueData] = key
    // The extension runs while the phone may be locked.
    item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    return SecItemAdd(item as CFDictionary, nil)
  }
}
