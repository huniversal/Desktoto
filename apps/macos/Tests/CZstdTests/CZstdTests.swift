import CZstd
import Testing

// zstd 명령으로 "hello"를 해독해 확인한 합성 프레임: 매직, 단일 세그먼트 헤더(원문 크기 5), 원본 블록(마지막 블록, 크기 5), 본문.
private let helloFrame: [UInt8] = [0x28, 0xB5, 0x2F, 0xFD, 0x20, 0x05, 0x29, 0x00, 0x00, 0x68, 0x65, 0x6C, 0x6C, 0x6F]

// 앞으로 사용량 읽기가 쓸 스트리밍 해독 함수들(ZSTD_createDStream 등)로 풀어 본다. 오류이면 nil이다.
private func decompress(_ source: [UInt8]) -> [UInt8]? {
    guard let stream = ZSTD_createDStream() else { return nil }
    defer { ZSTD_freeDStream(stream) }
    if ZSTD_isError(ZSTD_initDStream(stream)) != 0 { return nil }

    var output: [UInt8] = []
    var chunk = [UInt8](repeating: 0, count: ZSTD_DStreamOutSize())
    return source.withUnsafeBufferPointer { raw in
        var input = ZSTD_inBuffer(src: raw.baseAddress, size: raw.count, pos: 0)
        while true {
            var produced = 0
            let code = chunk.withUnsafeMutableBufferPointer { destination in
                var buffer = ZSTD_outBuffer(dst: destination.baseAddress, size: destination.count, pos: 0)
                let code = ZSTD_decompressStream(stream, &buffer, &input)
                produced = buffer.pos
                return code
            }
            if ZSTD_isError(code) != 0 { return nil }
            output.append(contentsOf: chunk[0..<produced])
            // 0이면 프레임을 끝까지 풀었다. 입력을 다 쓰고도 끝나지 않으면 잘린 프레임이다.
            if code == 0 { return output }
            if input.pos >= input.size && produced == 0 { return nil }
        }
    }
}

@Test func decompressesSyntheticFrame() {
    let decoded = decompress(helloFrame)
    #expect(decoded.map { String(decoding: $0, as: UTF8.self) } == "hello")
}

@Test func rejectsFrameWithWrongMagic() {
    var broken = helloFrame
    broken[0] = 0x00
    #expect(decompress(broken) == nil)
}

@Test func rejectsTruncatedFrame() {
    #expect(decompress(Array(helloFrame.prefix(helloFrame.count - 2))) == nil)
}
