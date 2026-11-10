import AppKit

extension IconColor {
    var nsColor: NSColor {
        switch self {
        case .gray(let white, let alpha):
            return NSColor(calibratedWhite: white, alpha: alpha)
        case .calibrated(let red, let green, let blue, let alpha):
            return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
        case .srgb(let red, let green, let blue, let alpha):
            return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
        }
    }
}

/// 사각형 목록을 비트맵 이미지로 칠한다. 그리기 클로저로 만든 NSImage는 화면에 쓰일 때마다 다시 그려져서,
/// 한 번만 그려 비트맵으로 저장한다.
@MainActor
enum IconRenderer {
    /// Retina 기준 화면 픽셀 1개. 모든 그리기를 이 눈금에 맞춘다.
    private static let devicePixelPoints: CGFloat = 0.5

    static func image(frame: IconFrame, appearance: IconAppearance, scale: CGFloat, pointHeight: CGFloat = IconImageSet.defaultPointHeight, topMargin: CGFloat = 0, bottomMargin: CGFloat = 0) -> NSImage {
        let pieces = IconScene.pieces(frame: frame, appearance: appearance)
        let placement = IconScene.imagePlacement(frame: frame, appearance: appearance)
        let backdrop = IconScene.backdrop(frame: frame, appearance: appearance)
        // 그림 캐릭터는 항상 풍경이 깔리므로 모서리를 둥글게 잘라 메뉴바에 어울리게 한다.
        let hasBackdrop = appearance.character != .claude
        return createCanvasImage(pointHeight: pointHeight, topMargin: topMargin, bottomMargin: bottomMargin, scale: scale) { unit in
            if hasBackdrop {
                let canvas = NSRect(x: 0, y: 0, width: CharacterGrid.canvasWidth * unit, height: CharacterGrid.canvasHeight * unit)
                NSBezierPath(roundedRect: canvas, xRadius: 3 * unit, yRadius: 3 * unit).addClip()
            }
            if let backdrop { drawBackdrop(backdrop, unit: unit) }
            fill(pieces, unit: unit)
            if let placement { drawCharacterImage(placement, unit: unit) }
        }
    }

    /// 애니 장면을 캔버스 전체에 깔고, 흘러가는 중이면 들판 띠를 왼쪽으로 밀어 이어 붙인다.
    private static func drawBackdrop(_ backdrop: BackdropPlacement, unit: CGFloat) {
        guard let scene = SceneBackdrop.image(of: backdrop.scene), let context = NSGraphicsContext.current else { return }
        let canvasWidth = CharacterGrid.canvasWidth * unit
        drawArt(scene, in: NSRect(x: 0, y: 0, width: canvasWidth, height: CharacterGrid.canvasHeight * unit), fraction: 1, context: context)
        guard let shift = backdrop.grassShift, let tile = SceneBackdrop.grassTileImage else { return }
        let tileWidth = SceneBackdrop.grassPeriod * unit
        var x = -shift * unit
        while x < canvasWidth {
            drawArt(tile, in: NSRect(x: x, y: SceneBackdrop.grassTop * unit, width: tileWidth, height: SceneBackdrop.grassHeight * unit), fraction: 1, context: context)
            x += tileWidth
        }
    }

    /// 그림 캐릭터를 놓인 자리(칸 단위)에 그린다.
    private static func drawCharacterImage(_ placement: ImagePlacement, unit: CGFloat) {
        guard let art = CharacterArt.image(of: placement.character, pose: placement.pose, frame: placement.frame), let context = NSGraphicsContext.current else { return }
        let height = placement.height * unit
        let width = height * CharacterArt.aspectRatio(of: placement.character, pose: placement.pose)
        let artRect = NSRect(x: placement.centerX * unit - width / 2, y: placement.bottom * unit - height, width: width, height: height)
        drawArt(art, in: artRect, fraction: 1, context: context)
    }

    private static func drawArt(_ art: NSImage, in rect: NSRect, fraction: CGFloat, context: NSGraphicsContext) {
        context.imageInterpolation = .high
        art.draw(in: rect, from: .zero, operation: .sourceOver, fraction: fraction, respectFlipped: true, hints: nil)
    }

    /// 이미 그려진 상태 이미지(서 있는 모습이나 달리는 모습) 뒤에 폭죽 프레임을 합성한다. 폭죽이 재생되는 동안에만 호출한다.
    static func fireworkImage(base: NSImage, frame: Int, scale: CGFloat, pointHeight: CGFloat = IconImageSet.defaultPointHeight, topMargin: CGFloat = 0, bottomMargin: CGFloat = 0) -> NSImage {
        let pieces = IconScene.fireworkPieces(frame: frame)
        return createCanvasImage(pointHeight: pointHeight, topMargin: topMargin, bottomMargin: bottomMargin, scale: scale) { unit in
            fill(pieces, unit: unit)
            base.draw(
                in: NSRect(origin: .zero, size: base.size),
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: nil
            )
        }
    }

    /// topMargin과 bottomMargin은 이미지 위와 아래에 비워 두는 투명한 띠(pt)다. 이미지 높이는 그대로 pointHeight이고, 그림은 그 사이에 맞춰 그린다.
    private static func createCanvasImage(pointHeight: CGFloat, topMargin: CGFloat, bottomMargin: CGFloat, scale: CGFloat, draw: (CGFloat) -> Void) -> NSImage {
        let unit = (pointHeight - topMargin - bottomMargin) / CharacterGrid.canvasHeight
        let size = NSSize(width: unit * CharacterGrid.canvasWidth, height: pointHeight)
        let pixelWidth = Int((size.width * scale).rounded())
        let pixelHeight = Int((size.height * scale).rounded())

        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return NSImage(size: size) }

        // 그리기 좌표는 위쪽이 0인 포인트 단위다. 화면 배율만큼 키우고 위아래를 뒤집어 맞춘다.
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: 0, y: topMargin)

        let previousContext = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        draw(unit)
        NSGraphicsContext.current = previousContext

        guard let cgImage = context.makeImage() else { return NSImage(size: size) }
        let image = NSImage(cgImage: cgImage, size: size)
        image.isTemplate = false
        return image
    }

    private static func fill(_ pieces: [IconPiece], unit: CGFloat) {
        pieces.forEach { piece in
            piece.color.nsColor.setFill()
            fill(piece.rect, unit: unit)
        }
    }

    /// 블록 좌표(소수 가능)를 화면 픽셀 눈금에 맞춰 칠한다. 양 끝을 각각 맞추므로 이웃한 블록 사이에 틈이 생기지 않는다.
    private static func fill(_ rect: UnitRect, unit: CGFloat) {
        let snap = { (value: CGFloat) -> CGFloat in (value / devicePixelPoints).rounded() * devicePixelPoints }
        let left = snap(rect.x * unit)
        let top = snap(rect.y * unit)
        let right = snap((rect.x + rect.width) * unit)
        let bottom = snap((rect.y + rect.height) * unit)
        guard right > left, bottom > top else { return }
        NSRect(x: left, y: top, width: right - left, height: bottom - top).fill()
    }
}
