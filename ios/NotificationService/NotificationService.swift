import CryptoKit
import UserNotifications

/// Rewrites the relay's placeholder alert ("OpenCode") with the real text.
/// The text arrives encrypted (see push/plugin/opencode-push.js); the key was
/// put in the shared keychain by the app when notifications were turned on.
class NotificationService: UNNotificationServiceExtension {
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var content: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
      contentHandler(request.content)
      return
    }
    self.content = content
    let info = request.content.userInfo
    let kind = info["kind"] as? String ?? "completed"
    let sessionID = info["sessionID"] as? String ?? ""
    let payload = PushPayload.open(
      keyId: info["keyId"] as? String,
      kind: kind,
      sessionID: sessionID,
      enc: info["enc"] as? String
    )
    let headline = PushPayload.headline(for: kind)
    let project = payload?.project ?? ""
    content.title = project.isEmpty ? headline : "\(project): \(headline)"
    content.body = payload?.title ?? payload?.detail ?? ""
    if !sessionID.isEmpty { content.threadIdentifier = sessionID }
    contentHandler(content)
  }

  override func serviceExtensionTimeWillExpire() {
    if let contentHandler, let content { contentHandler(content) }
  }
}

struct PushPayload: Decodable {
  let project: String?
  let title: String?
  let detail: String?

  /// Must match the app's PushKeyStore (ios/Runner/AppDelegate.swift).
  static let accessGroup = "group.dev.opencodemobile.opencodeMobile"
  static let service = "opencode-push"

  static func open(keyId: String?, kind: String, sessionID: String, enc: String?) -> PushPayload? {
    guard let keyId, let enc, let key = key(for: keyId), let raw = base64URL(enc), raw.count > 28
    else { return nil }
    do {
      let box = try AES.GCM.SealedBox(
        nonce: AES.GCM.Nonce(data: raw.prefix(12)),
        ciphertext: raw.dropFirst(12).dropLast(16),
        tag: raw.suffix(16)
      )
      let plain = try AES.GCM.open(
        box, using: SymmetricKey(data: key), authenticating: Data("\(kind):\(sessionID)".utf8))
      return try JSONDecoder().decode(PushPayload.self, from: plain)
    } catch {
      return nil
    }
  }

  static func headline(for kind: String) -> String {
    let ja = Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    switch kind {
    case "failed": return ja ? "エラーで停止しました" : "Stopped with an error"
    case "permission": return ja ? "許可を待っています" : "Waiting for permission"
    case "question": return ja ? "質問に回答を待っています" : "Waiting for your answer"
    default: return ja ? "応答が完了しました" : "Reply finished"
    }
  }

  private static func key(for keyId: String) -> Data? {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: keyId,
      kSecAttrAccessGroup: accessGroup,
      kSecReturnData: true,
    ]
    var result: AnyObject?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
    return result as? Data
  }

  private static func base64URL(_ text: String) -> Data? {
    var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
    return Data(base64Encoded: base64)
  }
}
