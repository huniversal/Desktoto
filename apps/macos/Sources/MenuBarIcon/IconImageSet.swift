import AppKit

/// 서 있기 1장, 시선 45장(Claude만), 달리기 24장, 잠듦 6장, 대기 클립(그림 캐릭터만)을 미리 그려 두는 비트맵 묶음.
/// 이미지를 바꿀 때마다 시스템이 스냅샷을 만들기 때문에, 그리는 비용은 만들 때 한 번만 치르고 이후에는 꺼내 쓰기만 한다.
/// 이미지를 쓰는 곳(메뉴바 갱신)이 메인 액터라서 같은 곳에서 소유한다.
@MainActor
public final class IconImageSet {
    /// 메뉴바 이미지의 기본 높이. 한 칸이 1pt가 되는 높이다.
    public static let defaultPointHeight: CGFloat = 22

    public private(set) var appearance: IconAppearance

    private let scale: CGFloat
    private let pointHeight: CGFloat
    private let topMargin: CGFloat
    private let bottomMargin: CGFloat
    private let makeImage: @MainActor (IconFrame, IconAppearance) -> NSImage
    private var standing: NSImage
    private var gazing: [NSImage]
    /// 표정 이미지는 자주 쓰이지 않는 조합이 많아서 처음 필요할 때 한 번만 그려 둔다.
    private var expressions: [ExpressionKey: NSImage] = [:]
    /// 낚시 모습도 조합이 많아서 처음 필요할 때 한 번만 그려 둔다.
    private var fishing: [FishingFrame: NSImage] = [:]
    private var restFrames: [RestFrame: NSImage] = [:]
    private var running: [NSImage]
    private var sleeping: [NSImage]
    /// 대기 클립별로 미리 그린 GIF 프레임. 대기 중에 움직이지 않는 캐릭터는 비어 있다.
    private var idle: [[NSImage]]
    /// 대기 클립별로 50ms 칸마다 보여 줄 프레임 번호
    private var idleSequences: [[Int]]

    /// 대기 중에도 움직이는 캐릭터인지. 앱은 이 값이 true일 때만 대기 타이머를 돌린다.
    public var hasIdleAnimation: Bool {
        !idle.isEmpty
    }

    /// 대기 클립 수
    public var idleClipCount: Int {
        idle.count
    }

    /// 대기 클립 한 바퀴의 칸 수(IconTiming.idleFrameInterval 단위). 클립이 없으면 0이다.
    public func idleStepCount(clip: Int) -> Int {
        guard !idleSequences.isEmpty else { return 0 }
        return idleSequences[wrapFrameIndex(clip, count: idleSequences.count)].count
    }

    /// 대기 클립의 step번째 칸에 보여 줄 이미지. 클립이 없으면 서 있는 모습이다.
    public func idleImage(clip: Int, step: Int) -> NSImage {
        guard !idleSequences.isEmpty else { return standing }
        let clipIndex = wrapFrameIndex(clip, count: idleSequences.count)
        let sequence = idleSequences[clipIndex]
        return image(for: .idle(clip: clipIndex, frame: sequence[wrapFrameIndex(step, count: sequence.count)]))
    }

    /// scale은 화면 배율이다. 원본처럼 만드는 시점의 값으로 고정되며 이후 화면이 바뀌어도 다시 계산하지 않는다.
    /// topMargin과 bottomMargin은 이미지 위와 아래에 비워 두는 투명한 띠(pt)다. 이미지 높이는 pointHeight 그대로다.
    public convenience init(
        appearance: IconAppearance = IconAppearance(),
        scale: CGFloat,
        pointHeight: CGFloat = IconImageSet.defaultPointHeight,
        topMargin: CGFloat = 0,
        bottomMargin: CGFloat = 0
    ) {
        self.init(appearance: appearance, scale: scale, pointHeight: pointHeight, topMargin: topMargin, bottomMargin: bottomMargin) { frame, appearance in
            IconRenderer.image(frame: frame, appearance: appearance, scale: scale, pointHeight: pointHeight, topMargin: topMargin, bottomMargin: bottomMargin)
        }
    }

    init(
        appearance: IconAppearance,
        scale: CGFloat,
        pointHeight: CGFloat,
        topMargin: CGFloat = 0,
        bottomMargin: CGFloat = 0,
        makeImage: @escaping @MainActor (IconFrame, IconAppearance) -> NSImage
    ) {
        self.appearance = appearance
        self.scale = scale
        self.pointHeight = pointHeight
        self.topMargin = topMargin
        self.bottomMargin = bottomMargin
        self.makeImage = makeImage
        (standing, gazing, running, sleeping, idle) = Self.createImages(appearance: appearance, makeImage: makeImage)
        idleSequences = CharacterArt.idleClips(of: appearance.character).map(\.sequence)
    }

    /// 조건이 바뀌었을 때만 모든 이미지를 다시 만든다. 다시 만들었으면 true를 돌려준다.
    @discardableResult
    public func update(appearance newAppearance: IconAppearance) -> Bool {
        guard newAppearance != appearance else { return false }
        appearance = newAppearance
        expressions = [:]
        fishing = [:]
        restFrames = [:]
        (standing, gazing, running, sleeping, idle) = Self.createImages(appearance: newAppearance, makeImage: makeImage)
        idleSequences = CharacterArt.idleClips(of: newAppearance.character).map(\.sequence)
        return true
    }

    public func image(for frame: IconFrame) -> NSImage {
        switch frame {
        case .expression(let expression, let direction):
            guard expression != .open else { return image(for: .gazing(direction)) }
            let key = ExpressionKey(expression: expression, direction: direction)
            if let cached = expressions[key] { return cached }
            let created = makeImage(frame, appearance)
            expressions[key] = created
            return created
        case .fishing(let fishingFrame):
            if let cached = fishing[fishingFrame] { return cached }
            let created = makeImage(frame, appearance)
            fishing[fishingFrame] = created
            return created
        case .rest(let restFrame):
            if let cached = restFrames[restFrame] { return cached }
            let created = makeImage(frame, appearance)
            restFrames[restFrame] = created
            return created
        case .standing:
            return standing
        case .gazing(let direction):
            // 그림 캐릭터는 시선 그림이 없어서 서 있는 모습이다.
            return direction == .center || gazing.isEmpty ? standing : gazing[direction.index]
        case .idle(let clip, let frame):
            guard !idle.isEmpty else { return standing }
            let frames = idle[wrapFrameIndex(clip, count: idle.count)]
            return frames[wrapFrameIndex(frame, count: frames.count)]
        case .running(let phase):
            return running[wrapFrameIndex(phase, count: running.count)]
        case .sleeping(let sleepFrame):
            return sleeping[wrapFrameIndex(sleepFrame, count: sleeping.count)]
        }
    }

    /// 바탕 모습 뒤에 폭죽을 합성한다. 폭죽은 재생되는 프레임마다 새로 만든다(원본과 같다).
    public func fireworkImage(over base: IconFrame, fireworkFrame: Int) -> NSImage {
        IconRenderer.fireworkImage(base: image(for: base), frame: fireworkFrame, scale: scale, pointHeight: pointHeight, topMargin: topMargin, bottomMargin: bottomMargin)
    }

    private struct ExpressionKey: Hashable {
        let expression: EyeExpression
        let direction: GazeDirection
    }

    private static func createImages(
        appearance: IconAppearance,
        makeImage: @MainActor (IconFrame, IconAppearance) -> NSImage
    ) -> (standing: NSImage, gazing: [NSImage], running: [NSImage], sleeping: [NSImage], idle: [[NSImage]]) {
        let clips = CharacterArt.idleClips(of: appearance.character)
        let isPicture = appearance.character != .claude
        return (
            makeImage(.standing, appearance),
            isPicture ? [] : (0..<GazeDirection.count).map { makeImage(.gazing(GazeDirection(index: $0)), appearance) },
            (0..<IconTiming.runningFrameCount).map { makeImage(.running(phase: $0), appearance) },
            (0..<IconTiming.sleepFrameCount).map { makeImage(.sleeping(frame: $0), appearance) },
            clips.indices.map { clip in
                (0..<clips[clip].encodedFrames.count).map { makeImage(.idle(clip: clip, frame: $0), appearance) }
            }
        )
    }
}
