import AppKit
import DesignSystem
import Testing
@testable import MenuBarIcon

/// 이미지를 읽은 비트맵. 화면이 없는 환경(CI)에서는 화면 배율 1로 읽혀 픽셀 수가 달라질 수 있어서, 줄 번호는 이 비트맵의 높이로 계산한다.
@MainActor
private func createBitmap(_ image: NSImage) -> NSBitmapImageRep? {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    return NSBitmapImageRep(cgImage: cgImage)
}

private func alphaOfRow(_ bitmap: NSBitmapImageRep, row: Int) -> [UInt8] {
    (0..<bitmap.pixelsWide).map { column in UInt8((bitmap.colorAt(x: column, y: row)?.alphaComponent ?? 0) * 255) }
}

@MainActor
@Test func marginsKeepTheImageHeightAndLeaveTheTopAndBottomTransparent() throws {
    let appearance = IconAppearance(character: .usagi)
    let plain = IconImageSet(appearance: appearance, scale: 2, pointHeight: 38)
    let margined = IconImageSet(appearance: appearance, scale: 2, pointHeight: 38, topMargin: 2, bottomMargin: 2)

    #expect(plain.image(for: .standing).size.height == 38)
    #expect(margined.image(for: .standing).size.height == 38)

    let plainBitmap = try #require(createBitmap(plain.image(for: .standing)))
    let marginedBitmap = try #require(createBitmap(margined.image(for: .standing)))
    // 2pt가 읽은 비트맵에서 몇 줄인지(Retina면 4줄, 배율 1이면 2줄)
    let marginRows = marginedBitmap.pixelsHigh * 2 / 38
    let bottomRow = marginedBitmap.pixelsHigh - 1
    #expect(marginRows >= 2)

    // 맨 아래 줄과 여백 안쪽 끝 줄은 비어 있고, 여백이 없을 때는 맨 아래 줄까지 칠해진다.
    #expect(alphaOfRow(marginedBitmap, row: bottomRow).allSatisfy { $0 == 0 })
    #expect(alphaOfRow(marginedBitmap, row: bottomRow - (marginRows - 1)).allSatisfy { $0 == 0 })
    #expect(alphaOfRow(plainBitmap, row: plainBitmap.pixelsHigh - 1).contains { $0 > 0 })

    // 위쪽도 같다.
    #expect(alphaOfRow(marginedBitmap, row: 0).allSatisfy { $0 == 0 })
    #expect(alphaOfRow(marginedBitmap, row: marginRows - 1).allSatisfy { $0 == 0 })
    #expect(alphaOfRow(plainBitmap, row: 0).contains { $0 > 0 })
}
