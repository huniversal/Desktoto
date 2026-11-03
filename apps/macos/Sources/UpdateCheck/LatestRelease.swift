import Foundation

// 최신 정식 릴리스. 응답은 미검증 입력이라 태그가 `v숫자.숫자.숫자`일 때만 만든다.
public struct LatestRelease: Equatable, Sendable {
    public let version: AppVersion
    // 응답의 URL을 쓰지 않고 검증한 태그로 앱이 직접 만든 릴리스 페이지 주소다.
    public let pageURL: URL

    public init?(tagName: String) {
        guard tagName.hasPrefix("v"),
              let version = AppVersion(tagName),
              let pageURL = URL(string: "https://github.com/huniversal/Desktoto/releases/tag/\(tagName)") else { return nil }
        self.version = version
        self.pageURL = pageURL
    }
}
