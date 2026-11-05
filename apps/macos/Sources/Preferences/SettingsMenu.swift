import DesignSystem

// 메뉴 항목을 눌렀을 때 앱이 할 일. NSMenu에 연결하는 조립은 앱(#11)이 맡는다.
public enum SettingsAction: Equatable, Sendable {
    case toggleLoginItem
    case toggleNotifications
    case toggleCodexUsage
    case toggleClaudeIntegration
    case toggleUpdateCheck
    case openUpdatePage
    case showIntegrationGuide
    case toggleUsagePanel
    case toggleContextPanel
    case selectColorMode(ColorMode)
    case selectTheme(Theme)
    case selectGlassStyle(GlassStyle)
    case quit
}

public struct SettingsMenuItem: Equatable, Sendable {
    public let title: String
    public let isOn: Bool
    public let isEnabled: Bool
    public let keyEquivalent: String
    public let action: SettingsAction
}

public enum SettingsMenuEntry: Equatable, Sendable {
    case item(SettingsMenuItem)
    case submenu(title: String, items: [SettingsMenuItem])
    case separator
}

// 메뉴를 만들 때 설정 밖에서 알아야 하는 현재 상태.
public struct SettingsMenuEnvironment: Sendable {
    public let isRunningAsApp: Bool
    public let isLoginItemEnabled: Bool
    public let isClaudeCodeInstalled: Bool
    public let isClaudeConnected: Bool
    // 새 버전이 있을 때만 값이 있다. 문구는 앱이 만들어 넘긴다(Preferences는 업데이트 확인 모듈을 모른다).
    public let updateNoticeTitle: String?

    public init(
        isRunningAsApp: Bool,
        isLoginItemEnabled: Bool,
        isClaudeCodeInstalled: Bool,
        isClaudeConnected: Bool,
        updateNoticeTitle: String? = nil
    ) {
        self.isRunningAsApp = isRunningAsApp
        self.isLoginItemEnabled = isLoginItemEnabled
        self.isClaudeCodeInstalled = isClaudeCodeInstalled
        self.isClaudeConnected = isClaudeConnected
        self.updateNoticeTitle = updateNoticeTitle
    }
}

// 우클릭 설정 메뉴와 종료 메뉴의 구성. 원본 AppDelegate.showSettingsMenu와 같은 순서와 제목을 쓴다.
public enum SettingsMenu {
    @MainActor
    public static func makeEntries(settings: AppSettings, environment: SettingsMenuEnvironment) -> [SettingsMenuEntry] {
        var entries: [SettingsMenuEntry] = []
        // 새 버전이 있을 때만 맨 위에 안내 항목을 보여 준다.
        if let updateNoticeTitle = environment.updateNoticeTitle {
            entries.append(.item(makeItem(updateNoticeTitle, isOn: false, action: .openUpdatePage)))
            entries.append(.separator)
        }
        entries += [
            // 앱으로 실행 중일 때만 로그인 항목을 바꿀 수 있다.
            .item(makeItem("로그인 시 자동 실행", isOn: environment.isLoginItemEnabled, isEnabled: environment.isRunningAsApp, action: .toggleLoginItem)),
            .item(makeItem("알림 보내기", isOn: settings.sendsNotifications, action: .toggleNotifications)),
            .item(makeItem("Codex 연동", isOn: settings.fetchesCodexUsage, action: .toggleCodexUsage))
        ]
        if environment.isClaudeCodeInstalled {
            entries.append(.item(makeItem("Claude 연동", isOn: environment.isClaudeConnected, action: .toggleClaudeIntegration)))
        }
        entries.append(.item(makeItem("업데이트 확인", isOn: settings.checksForUpdates, action: .toggleUpdateCheck)))
        // 도구별로 사용자가 알아야 할 제약과 설정 방법을 보여 준다. 항상 보인다.
        entries.append(.item(makeItem("연동 안내…", isOn: false, action: .showIntegrationGuide)))
        entries.append(.separator)

        // 보여줄 패널은 둘 다, 하나만, 아예 없이도 고를 수 있다.
        entries.append(.submenu(title: "표시할 패널", items: [
            makeItem("사용량", isOn: settings.showsUsage, action: .toggleUsagePanel),
            makeItem("컨텍스트", isOn: settings.showsContext, action: .toggleContextPanel)
        ]))
        entries.append(.submenu(title: "색상", items: [
            makeItem("흰색", isOn: settings.colorMode == .white, action: .selectColorMode(.white)),
            makeItem("컬러", isOn: settings.colorMode == .color, action: .selectColorMode(.color))
        ]))
        entries.append(.submenu(title: "테마", items: Theme.allCases.map { theme in
            makeItem(theme.menuTitle, isOn: settings.theme == theme, action: .selectTheme(theme))
        }))
        entries.append(.submenu(title: "Liquid Glass", items: GlassStyle.allCases.map { style in
            makeItem(style.menuTitle, isOn: settings.glassStyle == style, action: .selectGlassStyle(style))
        }))

        entries.append(.separator)
        entries.append(.item(makeItem("Desktoto 종료", isOn: false, keyEquivalent: "q", action: .quit)))
        return entries
    }

    private static func makeItem(
        _ title: String,
        isOn: Bool,
        isEnabled: Bool = true,
        keyEquivalent: String = "",
        action: SettingsAction
    ) -> SettingsMenuItem {
        SettingsMenuItem(title: title, isOn: isOn, isEnabled: isEnabled, keyEquivalent: keyEquivalent, action: action)
    }
}

private extension GlassStyle {
    var menuTitle: String {
        switch self {
        case .clear: "투명"
        case .slightlyClear: "조금 투명"
        case .regular: "보통"
        case .slightlyTinted: "조금 진하게"
        case .tinted: "틴트"
        }
    }
}

private extension Theme {
    var menuTitle: String {
        switch self {
        case .light: "라이트"
        case .dark: "다크"
        case .system: "시스템 설정에 맞춤"
        }
    }
}
