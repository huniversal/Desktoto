import AppKit
import DesignSystem
import MenuBarIcon

/// 아이콘에 반영할 상태. 판정은 앱이 하고, 이 컨트롤러는 이 값에 맞춰 이미지와 타이머만 다룬다.
struct IconState: Equatable {
    var runningCount = 0
    var isWaiting = false
    var isSleeping = false
    var hasUnseenDone = false
    var colorMode: ColorMode = .white
}

/// 메뉴바 아이콘의 이미지와 애니메이션 타이머를 소유한다.
@MainActor
final class MenuBarIconController {
    private let button: NSStatusBarButton?
    private let images: IconImageSet
    private var animation = IconAnimation()
    private var state: IconState
    private var animationTimer: Timer?
    private var sleepTimer: Timer?

    init(button: NSStatusBarButton?, colorMode: ColorMode) {
        self.button = button
        state = IconState(colorMode: colorMode)
        images = IconImageSet(
            appearance: IconAppearance(colorMode: colorMode),
            scale: NSScreen.main?.backingScaleFactor ?? 2
        )
        button?.image = images.image(for: .standing)
    }

    var hasFirework: Bool {
        animation.hasFirework
    }

    func startFirework() {
        animation.startFirework()
    }

    /// 확인하지 않은 완료나 승인 대기 여부가 바뀌면 이미지를 다시 만들고, 상태에 맞게 애니메이션을 켜고 끈다.
    func apply(_ newState: IconState) {
        state = newState
        images.update(appearance: IconAppearance(
            colorMode: state.colorMode,
            hasUnseenDone: state.hasUnseenDone,
            isWaiting: state.isWaiting
        ))

        switch IconSchedule(isRunning: state.runningCount > 0, hasFirework: animation.hasFirework, isSleeping: state.isSleeping) {
        case .running:
            stopSleepAnimation()
            if animationTimer == nil { startAnimation() }
        case .sleeping:
            if animationTimer != nil { stopAnimation() }
            startSleepAnimation()
        case .still:
            if animationTimer != nil { stopAnimation() }
            stopSleepAnimation()
            button?.image = images.image(for: .standing)
        }
    }

    // 잠든 동안에는 z가 천천히 떠오르도록 느린 타이머만 돌린다. 깨면 stopSleepAnimation이 서 있는 모습으로 되돌린다.
    private func startSleepAnimation() {
        guard sleepTimer == nil else { return }
        button?.image = images.image(for: animation.currentSleepingFrame)
        sleepTimer = Timer.scheduledTimer(withTimeInterval: IconTiming.sleepFrameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickSleeping() }
        }
    }

    private func tickSleeping() {
        button?.image = images.image(for: animation.tickSleeping())
    }

    private func stopSleepAnimation() {
        guard sleepTimer != nil else { return }
        sleepTimer?.invalidate()
        sleepTimer = nil
        animation.resetSleeping()
        button?.image = images.image(for: .standing)
    }

    private func startAnimation() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: IconTiming.runningFrameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickRunning() }
        }
    }

    // 폭죽은 캐릭터 뒤에 합성한다. 끝까지 재생되고 달리는 세션도 없으면 타이머를 멈춘다.
    private func tickRunning() {
        let tick = animation.tickRunning(isRunning: state.runningCount > 0)
        if let fireworkFrame = tick.fireworkFrame {
            button?.image = images.fireworkImage(over: tick.frame, fireworkFrame: fireworkFrame)
        } else {
            button?.image = images.image(for: tick.frame)
        }
        if tick.shouldStop { stopAnimation() }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        button?.image = images.image(for: .standing)
    }
}
