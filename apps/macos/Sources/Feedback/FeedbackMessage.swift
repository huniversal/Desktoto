import Foundation

// Discord에 보낼 의견 한 건. 본문을 다듬고 길이를 제한하며, 앱 버전과 macOS 버전을 푸터로 붙인다.
public struct FeedbackMessage: Equatable, Sendable {
    // Discord `content`는 2000자까지다. 글자 수를 세는 기준이 확실하지 않아서 UTF-16 코드 단위로 보수적으로 센다.
    // 이모지처럼 코드 단위가 둘인 글자는 그만큼 한도를 더 쓰지만, 한도를 넘겨 거절당하는 일은 없다.
    public static let maximumTextLength = 1500
    public static let maximumContentLength = 2000

    public let text: String
    public let appVersion: String
    public let osVersion: String

    // 앞뒤 공백을 지운 본문이 비어 있거나 제한을 넘으면 nil이다. 버전까지 붙인 전체 길이가 한도를 넘어도 nil이다.
    public init?(text: String, appVersion: String, osVersion: String) {
        let trimmedText = Self.trim(text)
        guard !trimmedText.isEmpty, trimmedText.utf16.count <= Self.maximumTextLength else { return nil }
        self.text = trimmedText
        self.appVersion = appVersion
        self.osVersion = osVersion
        guard content.utf16.count <= Self.maximumContentLength else { return nil }
    }

    // 입력 창의 글자 수. 보낼 때 다듬는 것과 같은 기준(앞뒤 공백 제외)으로 센다.
    public static func textLength(of text: String) -> Int {
        trim(text).utf16.count
    }

    private static func trim(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Discord가 작은 글씨로 보여 주는 `-#` 줄에 버전을 적는다.
    var content: String {
        "\(text)\n\n-# Desktoto \(appVersion), macOS \(osVersion)"
    }

    private struct Payload: Encodable {
        struct AllowedMentions: Encodable {
            let parse: [String]
        }

        let content: String
        let allowedMentions: AllowedMentions

        enum CodingKeys: String, CodingKey {
            case content
            case allowedMentions = "allowed_mentions"
        }
    }

    // `parse`를 빈 배열로 보내서 본문에 @everyone 같은 멘션이 있어도 채널에서 알림이 울리지 않게 한다.
    func makeRequestBody() throws -> Data {
        // 키 순서를 고정해서 같은 입력이 항상 같은 바이트가 되게 한다.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Payload(content: content, allowedMentions: .init(parse: [])))
    }
}

// 전송에 붙이는 버전 문자열. 값을 만드는 부분만 순수 함수로 분리한다.
public enum FeedbackVersionText {
    public static let unknownAppVersion = "unknown"

    public static func appVersion(from infoDictionary: [String: Any]?) -> String {
        guard let version = infoDictionary?["CFBundleShortVersionString"] as? String, !version.isEmpty else {
            return unknownAppVersion
        }
        return version
    }

    public static func osVersion(_ version: OperatingSystemVersion) -> String {
        "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}
