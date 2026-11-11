import AppKit
import DesignSystem

/// 그림 캐릭터가 어떤 그림을 쓸지. 멈춰 있을 때는 쉬는 그림, 달릴 때는 달리는 그림, 대기 중에는 대기 클립의 그림이다.
enum ArtPose: Equatable, Hashable, Sendable {
    case resting
    case running
    case idle(clip: Int)
}

/// 대기 중에 돌리는 GIF 클립 하나. sequence는 IconTiming.idleFrameInterval(50ms) 한 칸마다 보여 줄 프레임 번호다.
struct IdleClip: Sendable {
    let encodedFrames: [String]
    /// 가로 대 세로 비율
    let aspectRatio: CGFloat
    let sequence: [Int]

    /// 프레임마다 원본 GIF에서 머무는 칸 수(50ms 단위)를 받아 순서를 만든다.
    init(encodedFrames: [String], width: CGFloat, height: CGFloat, stepsPerFrame: [Int]) {
        self.encodedFrames = encodedFrames
        aspectRatio = width / height
        sequence = stepsPerFrame.enumerated().flatMap { frame, steps in Array(repeating: frame, count: steps) }
    }
}

/// 그림으로 그리는 캐릭터(치이카와, 하치와레, 우사기)의 그림과 비율. Claude는 사각형으로 그려서 그림이 없다.
/// 한 자세가 여러 장(GIF에서 뽑은 프레임)이면 프레임 번호로 고른다. 같은 자세의 프레임은 크기가 모두 같다.
enum CharacterArt {
    private struct CacheKey: Hashable {
        let character: IconCharacter
        let pose: ArtPose
        let frame: Int
    }

    /// 치이카와 대기 클립. 앞에서부터 흔들흔들, 과자 냠냠, 꽃 들기, 신나서 춤, 볼 빨개짐, 도라야키, 분홍 장난감, 간식 들기다. 원본 GIF의 프레임 시간을 50ms 칸으로 옮겼다.
    private static let chiikawaIdleClips: [IdleClip] = [
        IdleClip(encodedFrames: CharacterArtData.chiikawaIdleSway, width: 109, height: 96, stepsPerFrame: [2, 2, 8, 2, 2, 2, 2, 2]),
        IdleClip(encodedFrames: CharacterArtData.chiikawaIdleSnack, width: 114, height: 96, stepsPerFrame: Array(repeating: 2, count: 19)),
        IdleClip(encodedFrames: CharacterArtData.chiikawaIdleFlower, width: 105, height: 96, stepsPerFrame: Array(repeating: 2, count: 28)),
        IdleClip(encodedFrames: CharacterArtData.chiikawaIdleDance, width: 98, height: 96, stepsPerFrame: Array(repeating: 2, count: 33) + [1]),
        IdleClip(encodedFrames: CharacterArtData.chiikawaIdleBlush, width: 108, height: 96, stepsPerFrame: [4] + Array(repeating: 2, count: 28)),
        IdleClip(encodedFrames: CharacterArtData.chiikawaIdleDorayaki, width: 101, height: 96, stepsPerFrame: [7, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2]),
        IdleClip(encodedFrames: CharacterArtData.chiikawaIdleToy, width: 99, height: 96, stepsPerFrame: Array(repeating: 2, count: 18)),
        IdleClip(encodedFrames: CharacterArtData.chiikawaIdleTreat, width: 121, height: 96, stepsPerFrame: [4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2])
    ]

    /// 우사기 대기 클립. 앞에서부터 막대 들기, 엉덩이 흔들기, 냠냠, 막대 깨물기, 라멘 먹기다. 원본 GIF는 모두 100ms 간격이다.
    private static let usagiIdleClips: [IdleClip] = [
        IdleClip(encodedFrames: CharacterArtData.usagiIdleStick, width: 97, height: 96, stepsPerFrame: Array(repeating: 2, count: 15)),
        IdleClip(encodedFrames: CharacterArtData.usagiIdleWiggle, width: 82, height: 96, stepsPerFrame: Array(repeating: 2, count: 37)),
        IdleClip(encodedFrames: CharacterArtData.usagiIdleMunch, width: 89, height: 96, stepsPerFrame: Array(repeating: 2, count: 15)),
        IdleClip(encodedFrames: CharacterArtData.usagiIdleBite, width: 97, height: 96, stepsPerFrame: Array(repeating: 2, count: 11)),
        IdleClip(encodedFrames: CharacterArtData.usagiIdleNoodle, width: 86, height: 96, stepsPerFrame: Array(repeating: 2, count: 42))
    ]

    /// 하치와레 대기 클립. 앞에서부터 볼 빨개짐, 꽃 들기, 악기 연주다. 원본 GIF는 모두 100ms 간격이다. 신나서 춤은 작업 중에 쓴다.
    private static let hachiwareIdleClips: [IdleClip] = [
        IdleClip(encodedFrames: CharacterArtData.hachiwareIdleBlush, width: 99, height: 96, stepsPerFrame: Array(repeating: 2, count: 6)),
        IdleClip(encodedFrames: CharacterArtData.hachiwareIdleFlower, width: 92, height: 96, stepsPerFrame: Array(repeating: 2, count: 19)),
        IdleClip(encodedFrames: CharacterArtData.hachiwareIdleGuitar, width: 118, height: 96, stepsPerFrame: Array(repeating: 2, count: 32))
    ]

    /// 대기 중에 돌리는 클립 목록. 비어 있으면 대기 중에 움직이지 않는다.
    static func idleClips(of character: IconCharacter) -> [IdleClip] {
        switch character {
        case .chiikawa: chiikawaIdleClips
        case .hachiware: hachiwareIdleClips
        case .usagi: usagiIdleClips
        case .claude: []
        }
    }

    /// 대기 클립 하나를 고른다. 클립이 없으면 nil이다.
    private static func idleClip(of character: IconCharacter, clip: Int) -> IdleClip? {
        let clips = idleClips(of: character)
        guard !clips.isEmpty else { return nil }
        return clips[wrapFrameIndex(clip, count: clips.count)]
    }

    /// 작업 중 그림에서 캔버스에 보여 줄 세로 범위(그림 높이에 대한 위, 아래 비율). 작업 중에는 이 범위가 캔버스 높이를 꽉 채우도록 확대하고, 범위 밖은 잘린다.
    /// 우사기는 귀가 길어서 귀 끝을 조금 자르고 얼굴부터 가슴까지 보인다.
    static func runningVisibleRange(of character: IconCharacter) -> ClosedRange<CGFloat> {
        switch character {
        case .chiikawa: 0...0.72
        case .hachiware: 0...0.8
        case .usagi: 0.12...0.85
        case .claude: 0...1
        }
    }

    /// 타이머 없이 멈춰 있을 때(서 있기, 잠듦)는 첫 대기 클립의 이 프레임을 쓴다.
    static let stillIdleFrame = 3

    private static func frames(of character: IconCharacter, pose: ArtPose) -> [String] {
        switch (character, pose) {
        case (.claude, _): []
        case (.usagi, .running): CharacterArtData.usagiDance
        case (.chiikawa, .running): CharacterArtData.chiikawaRunFrames
        case (.hachiware, .running): CharacterArtData.hachiwareDance
        // 멈춰 있을 때는 첫 대기 클립의 그림을 쓴다.
        case (_, .resting): idleClip(of: character, clip: 0)?.encodedFrames ?? []
        case (_, .idle(let clip)): idleClip(of: character, clip: clip)?.encodedFrames ?? []
        }
    }

    static func frameCount(of character: IconCharacter, pose: ArtPose) -> Int {
        frames(of: character, pose: pose).count
    }

    static func aspectRatio(of character: IconCharacter, pose: ArtPose) -> CGFloat {
        switch (character, pose) {
        case (.claude, _): 1
        case (.usagi, .running): 60.0 / 96.0
        case (.chiikawa, .running): 111.0 / 120.0
        case (.hachiware, .running): 98.0 / 96.0
        case (_, .resting): idleClip(of: character, clip: 0)?.aspectRatio ?? 1
        case (_, .idle(let clip)): idleClip(of: character, clip: clip)?.aspectRatio ?? 1
        }
    }

    @MainActor
    static func image(of character: IconCharacter, pose: ArtPose, frame: Int = 0) -> NSImage? {
        let encodedFrames = frames(of: character, pose: pose)
        guard !encodedFrames.isEmpty else { return nil }
        let index = wrapFrameIndex(frame, count: encodedFrames.count)
        let key = CacheKey(character: character, pose: pose, frame: index)
        if let cached = cache[key] { return cached }
        guard let data = Data(base64Encoded: encodedFrames[index]), let image = NSImage(data: data) else { return nil }
        cache[key] = image
        return image
    }

    @MainActor private static var cache: [CacheKey: NSImage] = [:]
}

/// 대기 클립을 무작위로 고른다. 같은 클립이 연달아 나오지 않는다.
public enum IdleClipPicker {
    public static func nextClip(after current: Int, count: Int, using generator: inout some RandomNumberGenerator) -> Int {
        guard count > 1 else { return 0 }
        // 지금 클립을 뺀 나머지 중에서 고른다.
        let offset = Int.random(in: 1..<count, using: &generator)
        return (current + offset) % count
    }
}

/// 대기 클립 재생 위치. 한 클립을 최소 재생 시간 이상 돌린 뒤, 클립 한 바퀴가 끝나는 순간에만 다른 클립으로 넘어가서 중간에 끊기지 않는다.
public struct IdlePlayback: Equatable, Sendable {
    public private(set) var clip: Int
    public private(set) var step = 0
    /// 지금 클립을 몇 칸째 돌리고 있는지
    private var elapsedSteps = 0

    public init(clip: Int = 0) {
        self.clip = clip
    }

    /// 한 칸 넘긴다. stepCount는 지금 클립 한 바퀴의 칸 수, clipCount는 클립 수다.
    public mutating func advance(stepCount: Int, clipCount: Int, using generator: inout some RandomNumberGenerator) {
        guard stepCount > 0 else { return }
        step += 1
        elapsedSteps += 1
        guard step >= stepCount else { return }
        step = 0
        if elapsedSteps >= IconTiming.idleMinimumClipSteps && clipCount > 1 {
            clip = IdleClipPicker.nextClip(after: clip, count: clipCount, using: &generator)
            elapsedSteps = 0
        }
    }
}
