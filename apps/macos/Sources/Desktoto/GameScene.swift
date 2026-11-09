import AppKit
import MenuBarIcon
import QuartzCore

/// 게임 장면이 시작할 때 받는 화면 정보. 좌표는 모두 화면 왼쪽 아래를 (0, 0)으로 두는 오버레이 창 기준이다.
struct GameSceneContext {
    /// 게임 요소를 올릴 레이어
    let root: CALayer
    let scale: CGFloat
    let screenSize: CGSize
    /// 메뉴바 아래 가장자리의 y
    let menuBarBottomY: CGFloat
    /// 메뉴바 줄의 가운데 y
    let menuBarCenterY: CGFloat
    /// 쓸 수 있는 왼쪽 끝. 노치가 있으면 노치 오른쪽 가장자리, 없으면 화면 가운데다.
    let usableMinX: CGFloat
    /// 메뉴바에서 비워진 구간
    let clearedMinX: CGFloat
    let clearedMaxX: CGFloat
    /// 메뉴바 캐릭터와 같은 모양의 그림 묶음
    let sprites: IconImageSet
}

/// 오버레이 위에서 벌어지는 게임 하나. 창, ESC 종료, 메뉴바 비우기는 `GameHost`가 맡고, 장면은 규칙과 그림만 맡는다.
@MainActor
protocol GameScene: AnyObject {
    /// 메뉴바가 비워지면 불린다. 레이어를 만들어 `root`에 올리고 게임을 시작한다.
    func begin(context: GameSceneContext)
    /// 한 프레임을 진행한다. mouse는 오버레이 창 좌표다.
    func update(deltaTime: TimeInterval, now: TimeInterval, mouse: CGPoint)
    var isOver: Bool { get }
    /// 게임이 끝난 뒤 Space를 눌렀을 때 불린다.
    func restart()
    /// 끝날 때 불린다. 기록을 저장하고 레이어를 치운다.
    func end()
}

/// 점수 숫자와 안내 문구에 쓰는 글자 레이어 설정
@MainActor
enum GameText {
    static func configure(
        _ layer: CATextLayer,
        scale: CGFloat,
        fontSize: CGFloat,
        weight: NSFont.Weight,
        isMonospaced: Bool,
        alignment: CATextLayerAlignmentMode,
        size: CGSize
    ) {
        layer.bounds = CGRect(origin: .zero, size: size)
        layer.font = isMonospaced ? NSFont.monospacedSystemFont(ofSize: fontSize, weight: weight) : NSFont.systemFont(ofSize: fontSize, weight: weight)
        layer.fontSize = fontSize
        layer.alignmentMode = alignment
        layer.foregroundColor = NSColor.white.cgColor
        layer.contentsScale = scale
        // 어떤 배경에서도 읽히도록 어두운 그림자를 둔다.
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.85
        layer.shadowRadius = 2
        layer.shadowOffset = .zero
    }
}
