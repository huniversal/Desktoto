import Boundaries
import Foundation
import Preferences
import UpdateCheck

/// 새 버전 확인을 시작할 때 한 번 하고 그 뒤로 주기적으로 깨워서 결과를 보관한다.
/// 24시간 간격 판단은 UpdateChecker가 하므로 타이머는 더 자주 깨워도 요청이 늘지 않는다(잠자기에서 깬 뒤 늦지 않게 하기 위함이다).
@MainActor
final class UpdateMonitor {
    private static let wakeInterval: TimeInterval = 60 * 60

    private let checker: UpdateChecker?
    private let settings: AppSettings
    private var timer: Timer?
    private(set) var availableUpdate: AvailableUpdate?

    init(settings: AppSettings, fileSystem: any FileSystem, bundle: Bundle = .main) {
        self.settings = settings
        // 앱(.app)이 아니거나 현재 버전을 읽을 수 없으면 비교할 수 없어서 확인하지 않는다.
        if AppBundle.isRunningAsApp,
           let versionText = bundle.infoDictionary?["CFBundleShortVersionString"] as? String,
           let currentVersion = AppVersion(versionText) {
            checker = UpdateChecker(
                currentVersion: currentVersion,
                installMethod: InstallMethod.detect(fileSystem: fileSystem),
                fetcher: GitHubReleaseFetcher()
            )
        } else {
            checker = nil
        }
    }

    func start() {
        guard checker != nil else { return }
        check()
        timer = Timer.scheduledTimer(withTimeInterval: Self.wakeInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
    }

    /// 설정이 꺼져 있으면 요청하지 않는다. 설정을 켠 직후에도 이 함수를 불러 바로 확인한다.
    func check() {
        guard let checker else { return }
        let isEnabled = settings.checksForUpdates
        Task { availableUpdate = await checker.refresh(isEnabled: isEnabled) }
    }

    /// 메뉴에 보여 줄 안내 문구. 설정이 꺼져 있거나 새 버전이 없으면 nil이다.
    var noticeTitle: String? {
        guard settings.checksForUpdates else { return nil }
        return availableUpdate.map(UpdateNoticeText.menuTitle(for:))
    }
}
