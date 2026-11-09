import CoreGraphics

/// 시간 순서로 되풀이되는 쉬는 일의 그림 목록을 고른다.
enum RestScenes {
    static func pieces(frame: RestFrame, bodyColor: IconColor) -> [IconPiece] {
        switch frame.activity {
        case .sparkler: return SparklerPieces.pieces(step: frame.step, bodyColor: bodyColor)
        case .music: return MusicPieces.pieces(step: frame.step, bodyColor: bodyColor)
        case .drink: return DrinkPieces.pieces(step: frame.step, bodyColor: bodyColor)
        case .stargazing: return StargazingPieces.pieces(step: frame.step, bodyColor: bodyColor)
        case .rain: return RainPieces.pieces(step: frame.step, bodyColor: bodyColor)
        case .bubbles: return BubblePieces.pieces(step: frame.step, bodyColor: bodyColor)
        // 졸음과 낚시는 각자의 프레임으로 그린다.
        case .sleeping, .fishing: return RestArt.character(bodyColor: bodyColor, originY: CGFloat(CharacterGrid.maxBobHeight))
        }
    }
}
