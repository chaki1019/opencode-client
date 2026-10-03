import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PushKeyStore") {
      PushKeyStore.register(messenger: registrar.messenger())
    }
  }
}

/// Keeps notification decryption keys where the Notification Service
/// Extension can read them: the keychain, shared through the app group.
/// The extension (ios/NotificationService) reads the same items.
enum PushKeyStore {
  static let accessGroup = "group.dev.opencodemobile.opencodeMobile"
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
