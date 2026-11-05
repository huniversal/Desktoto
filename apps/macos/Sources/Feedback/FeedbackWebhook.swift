import Foundation

// 번들의 Info.plist에 빌드 때 주입된 Discord webhook 주소. 소스에는 주소를 두지 않는다(저장소가 공개라서 Secret에서 주입한다).
// 번들이 잘못 만들어져도 사용자의 글이 엉뚱한 주소로 가지 않도록 Discord webhook 형식만 받는다.
public struct FeedbackWebhook: Equatable, Sendable {
    public static let infoDictionaryKey = "FeedbackWebhookURL"

    private static let host = "discord.com"
    private static let pathPrefix = "/api/webhooks/"

    public let url: URL

    // `https://discord.com/api/webhooks/{id}/{token}` 형식이 아니면 nil이다.
    public init?(_ text: String?) {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty,
              let components = URLComponents(string: text),
              components.scheme == "https",
              components.host == Self.host,
              components.port == nil,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.path.hasPrefix(Self.pathPrefix),
              let url = components.url else {
            return nil
        }
        // `{id}/{token}` 두 조각이 모두 있어야 한다.
        let identifiers = components.path.dropFirst(Self.pathPrefix.count).split(separator: "/", omittingEmptySubsequences: false)
        guard identifiers.count == 2, identifiers.allSatisfy({ !$0.isEmpty }) else { return nil }
        self.url = url
    }

    public init?(infoDictionary: [String: Any]?) {
        self.init(infoDictionary?[Self.infoDictionaryKey] as? String)
    }
}
