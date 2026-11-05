import DesignSystem
import Foundation
import Testing
@testable import Preferences

@MainActor
struct SettingsMenuTests {
    private func makeSettings() -> (AppSettings, UserDefaults, String) {
        let suiteName = "DesktotoPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (AppSettings(defaults: defaults), defaults, suiteName)
    }

    private func makeEnvironment(
        isRunningAsApp: Bool = true,
        isLoginItemEnabled: Bool = false,
        isClaudeCodeInstalled: Bool = true,
        isClaudeConnected: Bool = false,
        updateNoticeTitle: String? = nil
    ) -> SettingsMenuEnvironment {
        SettingsMenuEnvironment(
            isRunningAsApp: isRunningAsApp,
            isLoginItemEnabled: isLoginItemEnabled,
            isClaudeCodeInstalled: isClaudeCodeInstalled,
            isClaudeConnected: isClaudeConnected,
            updateNoticeTitle: updateNoticeTitle
        )
    }

    private func titles(of entries: [SettingsMenuEntry]) -> [String] {
        entries.map { entry in
            switch entry {
            case .item(let item): item.title
            case .submenu(let title, _): title
            case .separator: "-"
            }
        }
    }

    private func submenuItems(_ title: String, in entries: [SettingsMenuEntry]) -> [SettingsMenuItem] {
        for case .submenu(let submenuTitle, let items) in entries where submenuTitle == title {
            return items
        }
        return []
    }

    // AC-5, AC-6
    @Test func buildsOriginalOrderAndTitlesPlusUpdateCheck() {
        let (settings, defaults, suiteName) = makeSettings()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let entries = SettingsMenu.makeEntries(settings: settings, environment: makeEnvironment())

        #expect(titles(of: entries) == [
            "로그인 시 자동 실행", "알림 보내기", "Codex 연동", "Claude 연동", "업데이트 확인", "연동 안내…", "-",
            "표시할 패널", "색상", "테마", "Liquid Glass", "-", "Desktoto 종료"
        ])
        #expect(submenuItems("표시할 패널", in: entries).map(\.title) == ["사용량", "컨텍스트"])
        #expect(submenuItems("색상", in: entries).map(\.title) == ["흰색", "컬러"])
        #expect(submenuItems("테마", in: entries).map(\.title) == ["라이트", "다크", "시스템 설정에 맞춤"])
        #expect(submenuItems("Liquid Glass", in: entries).map(\.title) == ["투명", "조금 투명", "보통", "조금 진하게", "틴트"])
    }

    // AC-5
    @Test func marksCurrentSettingsAsOn() {
        let (settings, defaults, suiteName) = makeSettings()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        settings.showsContext = false
        settings.colorMode = .color
        settings.theme = .dark
        settings.glassStyle = .tinted
        settings.sendsNotifications = false
        let entries = SettingsMenu.makeEntries(
            settings: settings,
            environment: makeEnvironment(isLoginItemEnabled: true, isClaudeConnected: true)
        )

        #expect(submenuItems("표시할 패널", in: entries).map(\.isOn) == [true, false])
        #expect(submenuItems("색상", in: entries).map(\.isOn) == [false, true])
        #expect(submenuItems("테마", in: entries).map(\.isOn) == [false, true, false])
        #expect(submenuItems("Liquid Glass", in: entries).map(\.isOn) == [false, false, false, false, true])
        guard case .item(let loginItem) = entries[0], case .item(let notifications) = entries[1],
              case .item(let claude) = entries[3] else {
            Issue.record("항목 구성이 예상과 다르다")
            return
        }
        #expect(loginItem.isOn)
        #expect(!notifications.isOn)
        #expect(claude.isOn)
    }

    // AC-5
    @Test func disablesLoginItemOutsideAppBundle() {
        let (settings, defaults, suiteName) = makeSettings()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let entries = SettingsMenu.makeEntries(settings: settings, environment: makeEnvironment(isRunningAsApp: false))

        guard case .item(let loginItem) = entries[0] else {
            Issue.record("첫 항목이 로그인 항목이 아니다")
            return
        }
        #expect(!loginItem.isEnabled)
        #expect(loginItem.action == .toggleLoginItem)
    }

    // AC-5
    @Test func omitsClaudeIntegrationWhenClaudeCodeIsNotInstalled() {
        let (settings, defaults, suiteName) = makeSettings()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let entries = SettingsMenu.makeEntries(settings: settings, environment: makeEnvironment(isClaudeCodeInstalled: false))

        #expect(!titles(of: entries).contains("Claude 연동"))
    }

    // AC-5
    @Test func mapsItemsToActionsAndQuitShortcut() {
        let (settings, defaults, suiteName) = makeSettings()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let entries = SettingsMenu.makeEntries(settings: settings, environment: makeEnvironment())

        #expect(submenuItems("테마", in: entries).map(\.action) == [.selectTheme(.light), .selectTheme(.dark), .selectTheme(.system)])
        #expect(submenuItems("색상", in: entries).map(\.action) == [.selectColorMode(.white), .selectColorMode(.color)])
        #expect(submenuItems("표시할 패널", in: entries).map(\.action) == [.toggleUsagePanel, .toggleContextPanel])
        guard case .item(let quit) = entries.last else {
            Issue.record("마지막 항목이 종료가 아니다")
            return
        }
        #expect(quit.action == .quit)
        #expect(quit.keyEquivalent == "q")
    }
    // #53 AC-8: 환경과 관계없이 항상 보이고 누를 수 있다.
    @Test func alwaysShowsIntegrationGuide() {
        let (settings, defaults, suiteName) = makeSettings()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let environments = [
            makeEnvironment(),
            makeEnvironment(isRunningAsApp: false, isClaudeCodeInstalled: false),
            makeEnvironment(updateNoticeTitle: "새 버전이 있어요 (v1.2.3)")
        ]
        environments.forEach { environment in
            let entries = SettingsMenu.makeEntries(settings: settings, environment: environment)
            let guides = entries.compactMap { entry -> SettingsMenuItem? in
                guard case .item(let item) = entry, item.action == .showIntegrationGuide else { return nil }
                return item
            }
            #expect(guides.map(\.title) == ["연동 안내…"])
            #expect(guides.allSatisfy { $0.isEnabled && !$0.isOn })
        }
    }

    // #24 AC-5
    @Test func showsUpdateNoticeAtTopOnlyWhenTitleIsGiven() {
        let (settings, defaults, suiteName) = makeSettings()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let without = SettingsMenu.makeEntries(settings: settings, environment: makeEnvironment())
        let with = SettingsMenu.makeEntries(settings: settings, environment: makeEnvironment(updateNoticeTitle: "새 버전이 있어요 (v1.2.3)"))

        #expect(titles(of: without).first == "로그인 시 자동 실행")
        #expect(titles(of: with).prefix(3) == ["새 버전이 있어요 (v1.2.3)", "-", "로그인 시 자동 실행"])
        guard case .item(let notice) = with[0] else {
            Issue.record("첫 항목이 안내 항목이 아니다")
            return
        }
        #expect(notice.action == .openUpdatePage)
    }

    // #24 AC-6
    @Test func updateCheckToggleReflectsSetting() {
        let (settings, defaults, suiteName) = makeSettings()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        func toggle() -> SettingsMenuItem? {
            for case .item(let item) in SettingsMenu.makeEntries(settings: settings, environment: makeEnvironment()) where item.action == .toggleUpdateCheck {
                return item
            }
            return nil
        }

        #expect(toggle()?.title == "업데이트 확인")
        #expect(toggle()?.isOn == true)
        settings.checksForUpdates = false
        #expect(toggle()?.isOn == false)
    }
}
