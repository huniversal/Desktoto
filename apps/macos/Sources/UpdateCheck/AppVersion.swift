import Foundation

// `1.2.3` 형태의 앱 버전. 프리릴리스 접미사는 다루지 않는다(정식 릴리스만 알린다).
public struct AppVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    // `1.2.3`과 `v1.2.3`만 받는다. 자리 수가 다르거나 숫자가 아닌 글자가 있으면 nil이다.
    public init?(_ text: String) {
        let body = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let parts = body.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        let numbers = parts.compactMap { part -> Int? in
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            return Int(part)
        }
        guard numbers.count == 3 else { return nil }
        self.init(major: numbers[0], minor: numbers[1], patch: numbers[2])
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}
