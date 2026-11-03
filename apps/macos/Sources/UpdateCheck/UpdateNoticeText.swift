import Foundation

// 우클릭 메뉴에 보여 줄 새 버전 안내 문구. Homebrew로 설치했으면 갱신 명령을 함께 알려 준다.
public enum UpdateNoticeText {
    public static let homebrewUpgradeCommand = "brew upgrade --cask desktoto"

    public static func menuTitle(for update: AvailableUpdate) -> String {
        let base = "새 버전이 있어요 (v\(update.release.version))"
        switch update.installMethod {
        case .homebrew: return "\(base), \(homebrewUpgradeCommand)"
        case .manual: return base
        }
    }
}
