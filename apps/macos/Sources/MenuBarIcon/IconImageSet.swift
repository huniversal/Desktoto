import AppKit

/// 서 있기 1장, 달리기 24장, 잠듦 6장을 미리 그려 두는 비트맵 묶음.
/// 이미지를 바꿀 때마다 시스템이 스냅샷을 만들기 때문에, 그리는 비용은 만들 때 한 번만 치르고 이후에는 꺼내 쓰기만 한다.
/// 이미지를 쓰는 곳(메뉴바 갱신)이 메인 액터라서 같은 곳에서 소유한다.
@MainActor
public final class IconImageSet {
    /// 메뉴바 이미지의 기본 높이. 한 칸이 1pt가 되는 높이다.
    public static let defaultPointHeight: CGFloat = 20

    public private(set) var appearance: IconAppearance

    private let scale: CGFloat
    private let pointHeight: CGFloat
    private let makeImage: @MainActor (IconFrame, IconAppearance) -> NSImage
    private var standing: NSImage
    private var running: [NSImage]
    private var sleeping: [NSImage]

    /// scale은 화면 배율이다. 원본처럼 만드는 시점의 값으로 고정되며 이후 화면이 바뀌어도 다시 계산하지 않는다.
    public convenience init(appearance: IconAppearance = IconAppearance(), scale: CGFloat, pointHeight: CGFloat = IconImageSet.defaultPointHeight) {
        self.init(appearance: appearance, scale: scale, pointHeight: pointHeight) { frame, appearance in
            IconRenderer.image(frame: frame, appearance: appearance, scale: scale, pointHeight: pointHeight)
        }
    }

    init(
        appearance: IconAppearance,
        scale: CGFloat,
        pointHeight: CGFloat,
        makeImage: @escaping @MainActor (IconFrame, IconAppearance) -> NSImage
    ) {
        self.appearance = appearance
        self.scale = scale
        self.pointHeight = pointHeight
        self.makeImage = makeImage
        (standing, running, sleeping) = Self.createImages(appearance: appearance, makeImage: makeImage)
    }

    /// 조건이 바뀌었을 때만 모든 이미지를 다시 만든다. 다시 만들었으면 true를 돌려준다.
    @discardableResult
    public func update(appearance newAppearance: IconAppearance) -> Bool {
        guard newAppearance != appearance else { return false }
        appearance = newAppearance
        (standing, running, sleeping) = Self.createImages(appearance: newAppearance, makeImage: makeImage)
        return true
    }

    public func image(for frame: IconFrame) -> NSImage {
        switch frame {
        case .standing:
            return standing
        case .running(let phase):
            return running[wrapFrameIndex(phase, count: running.count)]
        case .sleeping(let sleepFrame):
            return sleeping[wrapFrameIndex(sleepFrame, count: sleeping.count)]
        }
    }

    /// 바탕 모습 뒤에 폭죽을 합성한다. 폭죽은 재생되는 프레임마다 새로 만든다(원본과 같다).
    public func fireworkImage(over base: IconFrame, fireworkFrame: Int) -> NSImage {
        IconRenderer.fireworkImage(base: image(for: base), frame: fireworkFrame, scale: scale, pointHeight: pointHeight)
    }

    private static func createImages(
        appearance: IconAppearance,
        makeImage: @MainActor (IconFrame, IconAppearance) -> NSImage
    ) -> (standing: NSImage, running: [NSImage], sleeping: [NSImage]) {
        (
            makeImage(.standing, appearance),
            (0..<IconTiming.runningFrameCount).map { makeImage(.running(phase: $0), appearance) },
            (0..<IconTiming.sleepFrameCount).map { makeImage(.sleeping(frame: $0), appearance) }
        )
    }
}
