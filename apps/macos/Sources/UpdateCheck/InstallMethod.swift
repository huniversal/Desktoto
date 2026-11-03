import Boundaries
import Foundation

// 앱을 어떻게 설치했는지. 갱신 방법을 안내하는 문구가 달라진다.
public enum InstallMethod: Equatable, Sendable {
    case homebrew
    case manual

    private static let caskroomPaths = [
        "/opt/homebrew/Caskroom/desktoto",
        "/usr/local/Caskroom/desktoto"
    ]

    // Homebrew cask는 Caskroom에 설치 기록 폴더를 남긴다. 둘 중 한 위치에 있으면 Homebrew로 설치한 것으로 본다.
    public static func detect(fileSystem: any FileSystem) -> InstallMethod {
        let isHomebrew = caskroomPaths.contains { fileSystem.directoryExists(at: URL(fileURLWithPath: $0)) }
        return isHomebrew ? .homebrew : .manual
    }
}
