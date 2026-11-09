import AppKit
import Boundaries
import ClaudeIntegration
import DesignSystem
import Domain
import Feedback
import Foundation
import MenuBarIcon
import Preferences
import SessionMonitoring
import SessionPanel
import TerminalIntegration
import UpdateCheck
import UsageMonitoring

/// Codex 사용량이 갱신되었을 때 앱에 알리는 연결. 사용량 감시기가 앱보다 먼저 만들어지므로 나중에 핸들러를 채운다.
@MainActor
final class UsageUpdateRelay {
    var handler: (@MainActor () -> Void)?

    func handleUpdate() {
        handler?()
    }
}

/// 모듈을 조립하는 앱의 중심. 타이머를 돌려 감시 결과를 받고, 상태를 판정해 아이콘, 패널, 알림, 소리에 전달한다.
/// 판정 로직은 PollTracker 같은 순수 타입에 있고, 이 클래스는 AppKit과 타이머와 비동기 호출을 연결한다.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem: NSStatusItem
    private let settings: AppSettings
    private let timeSource: any TimeSource
    private let sessionMonitor: SessionMonitor
    private let usageMonitor: UsageMonitor
    private let usageRelay: UsageUpdateRelay
    private let sessionOpener: SessionOpener
    private let claudeIntegration: ClaudeIntegration
    private let updateMonitor: UpdateMonitor
    // 빌드에 의견을 보낼 주소가 있을 때만 만든다. 없으면 문의하기 메뉴 항목이 없다.
    private let feedbackWindowController: FeedbackWindowController?
    private let urlOpener = SystemURLOpener()
    private let notifier = NotificationSender()
    private let loginItem = LoginItem()
    private let fileSystem: any FileSystem
    private let menuBuilder = SettingsMenuBuilder()
    private let panelController: PanelController
    private let iconController: MenuBarIconController

    private var pollTracker = PollTracker()
    private var sleepPolicy: SleepPolicy
    private var unseenFinishedIDs: Set<String> = []
    private var runningCount = 0
    private var isWaiting = false
    private var rest: IconRest?

    private var isPanelOpen = false
    // 패널을 여는 중에 닫았다가 다시 열 때, 먼저 시작한 열기가 뒤늦게 창을 띄우지 않게 한다.
    private var openGeneration = 0
    private var isPolling = false
    private var isRefreshingPanel = false
    private var lastUsageRefreshAt = Date.distantPast
    // 늦게 끝난 사용량 조회가 더 최근 조회의 결과를 덮어쓰지 않게 한다.
    private var usageRequestID = 0
    // 닫았다가 다시 열 때 먼저 시작한 세션 조회가 나중에 끝나 새 목록을 덮어쓰지 않게 한다.
    private var sessionRequestID = 0
    // 패널을 열려고 값을 채우는 동안(아직 창이 뜨기 전)이면 true.
    private var isOpenPending = false
    private var pollTimer: Timer?
    private var panelRefreshTimer: Timer?

    override init() {
        let fileSystem = LiveFileSystem()
        let timeSource = SystemTimeSource()
        let processRunner = SystemProcessRunner()
        let usageRelay = UsageUpdateRelay()
        let settings = AppSettings()
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        self.fileSystem = fileSystem
        self.timeSource = timeSource
        self.usageRelay = usageRelay
        self.settings = settings
        self.statusItem = statusItem
        sessionMonitor = SessionMonitor(
            fileSystem: fileSystem,
            timeSource: timeSource,
            terminalSessionChecker: ProcessTerminalSessionChecker(fileSystem: fileSystem, processRunner: processRunner, timeSource: timeSource),
            sessionLinkResolver: ClaudeDesktopSessionLinks(fileSystem: fileSystem, timeSource: timeSource)
        )
        usageMonitor = UsageMonitor(
            fileSystem: fileSystem,
            timeSource: timeSource,
            codexReader: CodexRateLimitReader(fileSystem: fileSystem, timeSource: timeSource, onUpdate: { usageRelay.handleUpdate() })
        )
        sessionOpener = SessionOpener(
            processRunner: processRunner,
            appleScriptRunner: SystemAppleScriptRunner(),
            urlOpener: SystemURLOpener(),
            timeSource: timeSource
        )
        claudeIntegration = ClaudeIntegration(
            fileSystem: LiveSettingsFileSystem(),
            resourceDirectory: Bundle.main.resourceURL ?? Bundle.main.bundleURL
        )
        updateMonitor = UpdateMonitor(settings: settings, fileSystem: fileSystem)
        feedbackWindowController = AppBundle.isRunningAsApp
            ? FeedbackWebhook(infoDictionary: Bundle.main.infoDictionary)
                .map { webhook in
                    FeedbackWindowController(sender: DiscordFeedbackSender(webhook: webhook), themeProvider: { settings.theme })
                }
            : nil
        panelController = PanelController(now: timeSource.now)
        iconController = MenuBarIconController(button: statusItem.button, colorMode: settings.colorMode)
        sleepPolicy = SleepPolicy(
            startedAt: timeSource.now,
            idleSeconds: SleepPolicy.idleSeconds(environment: ProcessInfo.processInfo.environment)
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleStatusItemClick)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        setUpPanel()
        connectClaudeCodeIfAllowed()
        applyLoginItemDefaultOnce()
        setUpUsageMonitoring()
        updateMonitor.start()
        menuBuilder.onAction = { [weak self] action in self?.perform(action) }

        // 알림을 누르면 그 세션으로 이동한다. 앱(.app)으로 실행 중일 때만 정식 알림을 쓴다.
        notifier.setUp { [weak self] sessionID in self?.openSession(id: sessionID) }

        pollTimer = Timer.scheduledTimer(withTimeInterval: RefreshPolicy.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.handlePollTick() }
        }
        handlePollTick()
    }

    // 종료하기 전에 Codex 프로세스를 정리한다. 정리가 끝날 때까지 종료를 미룬다.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task {
            await usageMonitor.stop()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    // MARK: - 설정 연결

    private func setUpPanel() {
        panelController.applyTheme(settings.theme)
        panelController.onDismissRequest = { [weak self] in self?.closePanel() }
        panelController.model.onOpenSession = { [weak self] session in self?.openSession(session) }
        syncPanelModel()
    }

    // 패널 모델은 Preferences를 모르므로 표시 설정을 값으로 넣어 준다.
    private func syncPanelModel() {
        let model = panelController.model
        model.showsUsage = settings.showsUsage
        model.showsContext = settings.showsContext
        model.colorMode = settings.colorMode
        model.glassStyle = settings.glassStyle
    }

    private func setUpUsageMonitoring() {
        usageRelay.handler = { [weak self] in
            guard let self, settings.showsUsage else { return }
            Task { await self.refreshUsages() }
        }
        let isEnabled = settings.fetchesCodexUsage
        Task { await usageMonitor.setCodexLiveEnabled(isEnabled) }
    }

    // 설치 후 처음 실행할 때만 로그인 항목을 켠다. 이후 사용자가 메뉴에서 끈 값은 그대로 둔다.
    private func applyLoginItemDefaultOnce() {
        let hasApplied = loginItem.enableOnFirstLaunch(hasApplied: settings.hasAppliedLoginItemDefault)
        if hasApplied != settings.hasAppliedLoginItemDefault {
            settings.hasAppliedLoginItemDefault = hasApplied
        }
    }

    // MARK: - Claude Code 연동

    // 사용자가 메뉴에서 연동을 켠 적이 있을 때만 시작할 때 연결한다. 꺼져 있으면 설정 파일을 조회하거나 바꾸지 않는다.
    private func connectClaudeCodeIfAllowed() {
        guard settings.connectsClaudeCode else { return }
        Task { logIfFailed(await claudeIntegration.connectOnStartup(ifAllowed: true)) }
    }

    // 연동이 켜져 있으면 해제하고(다시 자동으로 넣지 않는다), 꺼져 있으면 다시 켠다.
    private func toggleClaudeIntegration() {
        Task {
            if await claudeIntegration.connectionState() == .connected {
                settings.connectsClaudeCode = false
                logIfFailed(await claudeIntegration.disconnect())
            } else {
                settings.connectsClaudeCode = true
                logIfFailed(await claudeIntegration.connect())
            }
        }
    }

    private func logIfFailed(_ result: ClaudeIntegration.Result) {
        if case .failed(let failure) = result {
            NSLog("Desktoto: Claude Code 연동을 건너뛰었어요. \(failure)")
        }
    }

    private func toggleCodexUsage() {
        settings.fetchesCodexUsage.toggle()
        let isEnabled = settings.fetchesCodexUsage
        Task {
            await usageMonitor.setCodexLiveEnabled(isEnabled)
            if isEnabled { await usageMonitor.refreshCodexLive(minInterval: 0) }
        }
    }

    // MARK: - 설정 메뉴

    // 우클릭이면 설정과 종료 메뉴를, 좌클릭이면 세션 패널을 연다.
    private func showSettingsMenu() {
        closePanel()
        Task {
            let isClaudeConnected = await claudeIntegration.connectionState() == .connected
            let environment = SettingsMenuEnvironment(
                isRunningAsApp: AppBundle.isRunningAsApp,
                isLoginItemEnabled: loginItem.isEnabled,
                isClaudeCodeInstalled: fileSystem.directoryExists(at: fileSystem.homeDirectory.appendingPathComponent(".claude")),
                isClaudeConnected: isClaudeConnected,
                updateNoticeTitle: updateMonitor.noticeTitle,
                isFeedbackAvailable: feedbackWindowController != nil
            )
            statusItem.menu = menuBuilder.makeMenu(entries: SettingsMenu.makeEntries(settings: settings, environment: environment))
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        }
    }

    private func perform(_ action: SettingsAction) {
        switch action {
        case .toggleLoginItem:
            loginItem.toggle()
        case .toggleNotifications:
            settings.sendsNotifications.toggle()
        case .toggleCodexUsage:
            toggleCodexUsage()
        case .toggleClaudeIntegration:
            toggleClaudeIntegration()
        case .toggleUpdateCheck:
            settings.checksForUpdates.toggle()
            updateMonitor.check()
        case .openUpdatePage:
            if let pageURL = updateMonitor.availableUpdate?.release.pageURL {
                _ = urlOpener.open(pageURL)
            }
        case .showUsageGuide:
            showUsageGuide()
        case .showFeedback:
            feedbackWindowController?.show(buttonWindow: statusItem.button?.window)
        case .toggleUsagePanel:
            settings.showsUsage.toggle()
        case .toggleContextPanel:
            settings.showsContext.toggle()
        case .selectColorMode(let colorMode):
            // 막대 색은 패널이 모델로 바꾸고, 캐릭터는 이미지를 다시 만들어서 바로 바꾼다.
            settings.colorMode = colorMode
            applyIconState()
        case .selectTheme(let theme):
            settings.theme = theme
            panelController.applyTheme(theme)
        case .selectGlassStyle(let style):
            settings.glassStyle = style
        case .quit:
            NSApp.terminate(nil)
        }
        syncPanelModel()
    }

    // 도구별로 사용자가 알아야 할 제약과 설정 방법을 알려 준다. 앱은 다른 앱의 설정을 바꾸지 않는다.
    private func showUsageGuide() {
        let alert = NSAlert()
        alert.messageText = "사용 안내"
        alert.informativeText = """
        [cmux]
        카드를 눌러도 탭으로 이동하지 않습니다.
        cmux 설정 > 자동화에서 "소켓 제어 모드"를 "자동화 모드"로 바꾸면 이동합니다.

        [Antigravity]
        사용량(한도)은 표시되지 않습니다.
        컨텍스트는 추정값이라 ~가 붙습니다.

        [VS Code, Antigravity IDE]
        카드를 누르면 IDE 앱이 앞으로 옵니다.
        터미널 탭은 직접 찾아야 합니다.
        """
        alert.addButton(withTitle: "확인")
        NSApp.activate()
        alert.runModal()
    }

    // MARK: - 패널

    @objc private func handleStatusItemClick() {
        // 캐릭터를 누르면 졸거나 낚시하던 것을 멈추고 2분을 처음부터 다시 센다.
        sleepPolicy.noteClick(now: timeSource.now)
        if rest != nil {
            rest = nil
            applyIconState()
        }
        if NSApp.currentEvent?.type == .rightMouseUp {
            showSettingsMenu()
            return
        }
        if panelController.isVisible || isPanelOpen {
            closePanel()
        } else if settings.hasVisiblePanel {
            // 두 패널을 모두 끈 경우에는 열 것이 없다.
            openPanel()
        }
    }

    private func openPanel() {
        isPanelOpen = true
        openGeneration += 1
        let generation = openGeneration

        // 패널을 여는 순간 확인하지 않은 완료를 줄 표시로 넘기고, 아이콘의 완료 점을 지운다.
        let model = panelController.model
        model.finishedIDs = unseenFinishedIDs
        model.hoveredID = nil
        unseenFinishedIDs.removeAll()
        applyIconState()
        isOpenPending = true

        // 처음 열 때 패널 높이가 바로 맞도록 값을 채운 뒤에 보여 준다.
        Task {
            await refreshPanel()
            guard generation == openGeneration, isPanelOpen else { return }
            isOpenPending = false
            if settings.showsUsage { requestCodexRefresh(minInterval: 0) }
            panelController.show(buttonWindow: statusItem.button?.window)
            startPanelRefreshTimer()
        }
    }

    private func closePanel() {
        // 창이 뜨기 전에 닫으면 사용자는 완료를 본 적이 없으니 확인하지 않은 완료로 되돌린다.
        if isOpenPending {
            isOpenPending = false
            let model = panelController.model
            unseenFinishedIDs.formUnion(model.finishedIDs)
            model.finishedIDs.removeAll()
            applyIconState()
        }
        isPanelOpen = false
        openGeneration += 1
        panelRefreshTimer?.invalidate()
        panelRefreshTimer = nil
        panelController.hide()
    }

    // 열려 있는 동안 값을 갱신하고, 줄 수가 바뀌면 패널 크기도 맞춘다.
    private func startPanelRefreshTimer() {
        panelRefreshTimer?.invalidate()
        panelRefreshTimer = Timer.scheduledTimer(withTimeInterval: RefreshPolicy.panelRefreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.handlePanelRefreshTick() }
        }
    }

    private func handlePanelRefreshTick() {
        guard !isRefreshingPanel else { return }
        isRefreshingPanel = true
        Task {
            await refreshPanel()
            if settings.showsUsage, isPanelOpen {
                requestCodexRefresh(minInterval: RefreshPolicy.codexLiveMinInterval(isPanelOpen: true))
            }
            // 값이 화면에 반영된 뒤의 크기로 맞춘다.
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self.updatePanelFrame() }
            }
            isRefreshingPanel = false
        }
    }

    private func updatePanelFrame() {
        guard isPanelOpen else { return }
        panelController.updateFrame(buttonWindow: statusItem.button?.window)
    }

    // 승인 대기 세션을 맨 위로, 그다음 진행 중인 세션, 방금 끝난 세션, 나머지는 최근 활동순으로 보여준다.
    private func refreshPanel() async {
        syncPanelModel()
        sessionRequestID += 1
        let requestID = sessionRequestID
        await refreshUsages()
        let sessions = await sessionMonitor.activeSessions()
        guard requestID == sessionRequestID else { return }
        let model = panelController.model
        model.sessions = PanelSessionSorter.sorted(sessions, finishedIDs: model.finishedIDs)
        model.now = timeSource.now
    }

    private func refreshUsages() async {
        guard settings.showsUsage else { return }
        usageRequestID += 1
        let requestID = usageRequestID
        let usages = await usageMonitor.getUsages()
        guard requestID == usageRequestID else { return }
        panelController.model.usages = usages
        lastUsageRefreshAt = timeSource.now
    }

    // Codex 조회는 응답을 기다리느라 오래 걸릴 수 있어서 감시 틱을 막지 않게 따로 요청한다.
    private func requestCodexRefresh(minInterval: TimeInterval) {
        Task { await usageMonitor.refreshCodexLive(minInterval: minInterval) }
    }

    // MARK: - 세션 열기

    // 줄이나 알림을 누르면 그 세션이 있는 곳을 열고 패널을 닫는다.
    // 터미널 탭 이동은 AppleScript를 쓰므로 메인 스레드에서 호출한다.
    private func openSession(_ session: SessionInfo) {
        closePanel()
        _ = sessionOpener.open(session: session)
    }

    private func openSession(id: String) {
        Task {
            guard let session = await sessionMonitor.sessionInfo(id: id) else { return }
            openSession(session)
        }
    }

    // MARK: - 상태 감시

    // 이전 틱이 끝나기 전에는 다음 틱을 건너뛴다. 늦게 끝난 오래된 결과가 새 상태를 덮어쓰지 않게 한다.
    private func handlePollTick() {
        guard !isPolling else { return }
        isPolling = true
        Task {
            await runPollTick()
            isPolling = false
        }
    }

    private func runPollTick() async {
        if RefreshPolicy.shouldPreloadUsage(now: timeSource.now, lastRefreshAt: lastUsageRefreshAt, isPanelOpen: isPanelOpen) {
            await refreshUsages()
        }
        if !isPanelOpen, settings.showsUsage {
            requestCodexRefresh(minInterval: RefreshPolicy.codexLiveMinInterval(isPanelOpen: false))
        }
        // 사용량 조회가 길어져도 이번 틱에서 완료를 놓치지 않게 두 상태를 같은 시점에 읽는다.
        let states = await sessionMonitor.sessionStates()
        let waitingKinds = await sessionMonitor.waitingKinds()

        let result = pollTracker.advance(states: states, waitingKinds: waitingKinds)
        runningCount = result.runningCount
        isWaiting = result.isWaiting
        rest = sleepPolicy.rest(
            now: timeSource.now,
            isBusy: runningCount > 0 || isWaiting,
            hasFinished: !result.finishedIDs.isEmpty,
            hasFirework: iconController.hasFirework,
            random: { Double.random(in: 0..<1) }
        )

        if !result.finishedIDs.isEmpty { handleSessionsFinished(ids: result.finishedIDs) }
        if !result.newWaitingKinds.isEmpty { NSSound(named: "Ping")?.play() }
        applyIconState()

        let finishedNotices = result.finishedIDs.map { (sessionID: $0, body: NotificationText.finishedBody) }
        let waitingNotices = result.newWaitingKinds.map { (sessionID: $0.key, body: NotificationText.waitingBody(for: $0.value)) }
        await sendNotifications(finishedNotices + waitingNotices)
    }

    // 소리는 한 번만 낸다. 패널을 보고 있으면 점 대신 카드를 바로 강조한다.
    private func handleSessionsFinished(ids: [String]) {
        NSSound(named: "Glass")?.play()
        iconController.startFirework()
        ids.forEach { id in
            if isPanelOpen {
                panelController.model.finishedIDs.insert(id)
            } else {
                unseenFinishedIDs.insert(id)
            }
        }
    }

    // 알림 설정이 꺼져 있으면 배너를 보내지 않는다. 소리와 아이콘 표시는 호출하는 쪽에서 따로 한다.
    private func sendNotifications(_ notices: [(sessionID: String, body: String)]) async {
        guard settings.sendsNotifications else { return }
        for notice in notices {
            let session = await sessionMonitor.sessionInfo(id: notice.sessionID)
            notifier.send(title: NotificationText.title(for: session), body: notice.body, sessionID: notice.sessionID)
        }
    }

    private func applyIconState() {
        iconController.apply(IconState(
            runningCount: runningCount,
            isWaiting: isWaiting,
            rest: rest,
            hasUnseenDone: !unseenFinishedIDs.isEmpty,
            colorMode: settings.colorMode
        ))
    }
}
