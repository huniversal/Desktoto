import Testing
@testable import UpdateCheck

struct UpdateNoticeTextTests {
    private func makeUpdate(_ installMethod: InstallMethod) -> AvailableUpdate {
        AvailableUpdate(release: LatestRelease(tagName: "v1.2.3")!, installMethod: installMethod)
    }

    // AC-5
    @Test func manualInstallShowsOnlyVersion() {
        #expect(UpdateNoticeText.menuTitle(for: makeUpdate(.manual)) == "새 버전이 있어요 (v1.2.3)")
    }

    // AC-5
    @Test func homebrewInstallAlsoShowsUpgradeCommand() {
        #expect(UpdateNoticeText.menuTitle(for: makeUpdate(.homebrew)) == "새 버전이 있어요 (v1.2.3), brew upgrade --cask desktoto")
    }
}
