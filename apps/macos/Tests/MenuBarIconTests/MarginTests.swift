import AppKit
import DesignSystem
import Testing
@testable import MenuBarIcon

@MainActor
private func alphaOfRow(_ image: NSImage, row: Int) -> [UInt8] {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    return (0..<rep.pixelsWide).map { column in UInt8((rep.colorAt(x: column, y: row)?.alphaComponent ?? 0) * 255) }
}

@MainActor
@Test func marginsKeepTheImageHeightAndLeaveTheTopAndBottomTransparent() {
    let appearance = IconAppearance(character: .usagi)
    let plain = IconImageSet(appearance: appearance, scale: 2, pointHeight: 38)
    let margined = IconImageSet(appearance: appearance, scale: 2, pointHeight: 38, topMargin: 2, bottomMargin: 2)

    #expect(plain.image(for: .standing).size.height == 38)
    #expect(margined.image(for: .standing).size.height == 38)

    // 2pt는 Retina 픽셀 4줄이다. 맨 아래 줄은 비어 있고, 여백이 없을 때는 맨 아래 줄까지 칠해진다.
    let bottomRow = Int(38 * 2) - 1
    #expect(alphaOfRow(margined.image(for: .standing), row: bottomRow).allSatisfy { $0 == 0 })
    #expect(alphaOfRow(margined.image(for: .standing), row: bottomRow - 3).allSatisfy { $0 == 0 })
    #expect(alphaOfRow(plain.image(for: .standing), row: bottomRow).contains { $0 > 0 })

    // 위쪽도 같다. 맨 윗줄과 4번째 줄까지 비어 있고, 여백이 없을 때는 맨 윗줄이 칠해진다.
    #expect(alphaOfRow(margined.image(for: .standing), row: 0).allSatisfy { $0 == 0 })
    #expect(alphaOfRow(margined.image(for: .standing), row: 3).allSatisfy { $0 == 0 })
    #expect(alphaOfRow(plain.image(for: .standing), row: 0).contains { $0 > 0 })
}
