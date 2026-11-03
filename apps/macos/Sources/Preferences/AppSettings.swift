import DesignSystem
import Foundation
import Observation

// 우클릭 메뉴에서 바꾸는 설정. 바뀌는 즉시 저장하고, 패널(SwiftUI)이 값을 지켜보다가 바로 다시 그린다.
// 키 이름은 원본(ai-run)과 같게 유지한다. 저장된 값이 enum과 맞지 않으면 기본값을 쓴다.
@MainActor
@Observable
public final class AppSettings {
    enum Key {
        static let showsUsage = "showsUsagePanel"
        static let showsContext = "showsContextPanel"
        static let colorMode = "colorMode"
        static let sendsNotifications = "sendsNotifications"
        static let glassStyle = "glassStyle"
        static let theme = "theme"
        static let connectsClaudeCode = "connectsClaudeCode"
        static let fetchesCodexUsage = "fetchesCodexUsage"
        static let checksForUpdates = "checksForUpdates"
        static let hasAppliedLoginItemDefault = "hasAppliedLoginItemDefault"
    }

    @ObservationIgnored private let defaults: UserDefaults

    public var showsUsage: Bool {
        didSet { defaults.set(showsUsage, forKey: Key.showsUsage) }
    }
    public var showsContext: Bool {
        didSet { defaults.set(showsContext, forKey: Key.showsContext) }
    }
    public var colorMode: ColorMode {
        didSet { defaults.set(colorMode.rawValue, forKey: Key.colorMode) }
    }
    public var theme: Theme {
        didSet { defaults.set(theme.rawValue, forKey: Key.theme) }
    }
    public var glassStyle: GlassStyle {
        didSet { defaults.set(glassStyle.rawValue, forKey: Key.glassStyle) }
    }
    // Claude Code 설정에 연동을 자동으로 넣을지. 저장된 값이 없으면 true라서 설치 후 처음 실행할 때 연결한다(#23이 #11 D-1을 대체).
    // 사용자가 연동을 해제하면 false가 되어 다시 넣지 않는다.
    public var connectsClaudeCode: Bool {
        didSet { defaults.set(connectsClaudeCode, forKey: Key.connectsClaudeCode) }
    }
    // Codex 사용량을 codex 프로그램에 물어봐서 현재 값으로 보여줄지. 끄면 세션 기록의 값만 쓴다.
    public var fetchesCodexUsage: Bool {
        didSet { defaults.set(fetchesCodexUsage, forKey: Key.fetchesCodexUsage) }
    }
    // 새 버전이 나왔는지 GitHub 릴리스를 확인할지. 보내는 정보는 없고 최신 릴리스를 읽기만 한다. 기본값은 켜짐이다.
    public var checksForUpdates: Bool {
        didSet { defaults.set(checksForUpdates, forKey: Key.checksForUpdates) }
    }
    // macOS 알림(배너) 여부. 소리와 아이콘 표시는 이 설정과 무관하다.
    public var sendsNotifications: Bool {
        didSet { defaults.set(sendsNotifications, forKey: Key.sendsNotifications) }
    }

    // 로그인 항목의 첫 실행 기본값(켜기)을 이미 적용했는지. 적용한 뒤에는 사용자가 끈 값을 다시 켜지 않는다.
    public var hasAppliedLoginItemDefault: Bool {
        didSet { defaults.set(hasAppliedLoginItemDefault, forKey: Key.hasAppliedLoginItemDefault) }
    }

    // 저장된 값이 없으면 두 패널을 모두 보여주고, 흰색, 시스템 테마, 보통 유리를 쓰고, 알림을 보내고, Codex 연동, Claude 연동, 업데이트 확인을 켠다.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showsUsage = Self.readBool(defaults, forKey: Key.showsUsage) ?? true
        showsContext = Self.readBool(defaults, forKey: Key.showsContext) ?? true
        colorMode = defaults.string(forKey: Key.colorMode).flatMap(ColorMode.init(rawValue:)) ?? .white
        theme = defaults.string(forKey: Key.theme).flatMap(Theme.init(rawValue:)) ?? .system
        glassStyle = defaults.string(forKey: Key.glassStyle).flatMap(GlassStyle.init(rawValue:)) ?? .regular
        sendsNotifications = Self.readBool(defaults, forKey: Key.sendsNotifications) ?? true
        connectsClaudeCode = Self.readBool(defaults, forKey: Key.connectsClaudeCode) ?? true
        fetchesCodexUsage = Self.readBool(defaults, forKey: Key.fetchesCodexUsage) ?? true
        checksForUpdates = Self.readBool(defaults, forKey: Key.checksForUpdates) ?? true
        // 표지가 없어도 저장된 설정이 하나라도 있으면 이전 버전 사용자라서 첫 실행으로 보지 않는다.
        hasAppliedLoginItemDefault = Self.readBool(defaults, forKey: Key.hasAppliedLoginItemDefault)
            ?? Self.hasStoredSettings(defaults)
    }

    private static func hasStoredSettings(_ defaults: UserDefaults) -> Bool {
        [
            Key.showsUsage, Key.showsContext, Key.colorMode, Key.sendsNotifications,
            Key.glassStyle, Key.theme, Key.connectsClaudeCode, Key.fetchesCodexUsage, Key.checksForUpdates
        ].contains { defaults.object(forKey: $0) != nil }
    }

    // 숫자 0과 1은 `as? Bool`로 읽히므로, 실제로 Bool로 저장된 값만 받아들인다.
    private static func readBool(_ defaults: UserDefaults, forKey key: String) -> Bool? {
        guard let value = defaults.object(forKey: key) as CFTypeRef?,
              CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
        return defaults.bool(forKey: key)
    }

    // 두 패널이 모두 꺼져 있으면 보여줄 것이 없어서 패널을 열지 않는다.
    public var hasVisiblePanel: Bool {
        showsUsage || showsContext
    }
}
