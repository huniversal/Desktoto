import AppKit

/// 어떤 애니 장면을 깔지. 들판은 치이카와, 문 앞은 하치와레, 숲속은 우사기가 쓴다.
enum BackdropScene: Equatable, Sendable {
    case field
    case gate
    case forest
}

/// 그림 캐릭터 뒤에 까는 애니 장면 배경을 어떻게 놓을지. grassShift가 있으면 들판 아래쪽 띠가 그만큼 왼쪽으로 밀려 흘러간다(들판 장면만).
struct BackdropPlacement: Equatable, Sendable {
    var scene: BackdropScene = .field
    let grassShift: CGFloat?
}

/// 애니 장면 배경. 장면 그림을 캔버스 전체에 깔고, 들판 장면은 달릴 때 들판 아래쪽 띠만 흘려 보낸다.
/// 장면 그림은 282x134이고 캔버스는 42x20칸이라 가로세로 모두 약 6.7픽셀이 한 칸이다.
enum SceneBackdrop {
    /// 장면 그림에서 들판 띠가 시작하는 행(원본 134픽셀 중 90픽셀째)
    static let grassTop: CGFloat = 90.0 / 134.0 * CharacterGrid.canvasHeight
    /// 들판 띠 한 장의 너비(원본 100픽셀). 좌우를 뒤집어 이어 붙인 그림이라 이 간격으로 끊김 없이 반복된다.
    static let grassPeriod: CGFloat = 100.0 / 282.0 * CharacterGrid.canvasWidth
    static let grassHeight: CGFloat = 44.0 / 134.0 * CharacterGrid.canvasHeight

    /// 달리기 한 바퀴(24칸)에 띠 한 장만큼 흘러가서, 바퀴가 끝날 때 처음과 이어진다.
    static func grassShift(phase: Int) -> CGFloat {
        let count = IconTiming.runningFrameCount
        return grassPeriod * CGFloat(wrapFrameIndex(phase, count: count)) / CGFloat(count)
    }

    @MainActor static let fieldImage = decode(CharacterArtData.chiikawaScene)
    @MainActor static let gateImage = decode(CharacterArtData.hachiwareScene)
    @MainActor static let forestImage = decode(CharacterArtData.usagiScene)

    @MainActor
    static func image(of scene: BackdropScene) -> NSImage? {
        switch scene {
        case .field: fieldImage
        case .gate: gateImage
        case .forest: forestImage
        }
    }

    @MainActor static let grassTileImage = decode(CharacterArtData.chiikawaGrassTile)

    private static func decode(_ encoded: String) -> NSImage? {
        Data(base64Encoded: encoded).flatMap(NSImage.init(data:))
    }
}
